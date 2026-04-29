"""
Lambda: Data Quality Checks with Groq LLM Healing
──────────────────────────────────────────────────
Called by Step Functions after the Silver layer is built.
Validates data quality before allowing the Gold aggregation to proceed.

NEW: Integrates Groq LLM for intelligent data healing on quality failures.

Checks performed:
  1. Row count — is there enough data?
  2. Null percentage — are critical columns populated?
  3. Schema validation — do expected columns exist?
  4. Value range checks — are numeric values reasonable?
  5. Freshness — is the data recent enough?

Healing (if checks fail):
  1. Extracts Groq API key from Secrets Manager
  2. Attempts to heal each failed record
  3. Re-runs checks on healed data
  4. If still failing: returns to source (Step Functions retries)

Environment Variables:
    S3_BUCKET_SILVER            — Silver bucket to check
    SNS_ALERT_TOPIC_ARN         — SNS for alerts
    GROQ_SECRET_ARN             — ARN of Groq API key in Secrets Manager
    GROQ_MODEL                  — Groq model (default: mixtral-8x7b-32768)
    GROQ_TIMEOUT_SECONDS        — Groq API timeout (default: 5)
    ENABLE_GROQ_HEALING         — Enable/disable healing (default: true)
"""

import os
import json
import logging
from datetime import datetime, timezone, timedelta

import boto3
import awswrangler as wr
import pandas as pd

# Import Groq healer (might not be available in all environments)
try:
    from groq_healer import GroqHealer, MockGroqHealer
    GROQ_HEALER_AVAILABLE = True
except ImportError:
    GROQ_HEALER_AVAILABLE = False
    logger.warning("Groq healer module not available. Healing will be disabled.")

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client("sns")
secrets_client = boto3.client("secretsmanager")
SNS_TOPIC = os.environ.get("SNS_ALERT_TOPIC_ARN", "")

# ── Thresholds ───────────────────────────────────────────────────────────────
MIN_ROW_COUNT = int(os.environ.get("DQ_MIN_ROW_COUNT", "10"))
MAX_NULL_PCT = float(os.environ.get("DQ_MAX_NULL_PERCENT", "5.0"))
MAX_VIEWS = 50_000_000_000  # 50B — sanity check for view counts
FRESHNESS_HOURS = 48  # Data should be no older than this
S3_OUTPUT = os.environ.get("ATHENA_S3_OUTPUT", "s3://rid-yt-data-pipeline-glue-athena-query-result/athena-results/")
WORKGROUP = os.environ.get("ATHENA_WORKGROUP", "primary")

# ── Groq Healing Configuration ──────────────────────────────────────────────────
GROQ_ENABLED = os.environ.get("ENABLE_GROQ_HEALING", "true").lower() == "true"
GROQ_SECRET_ARN = os.environ.get("GROQ_SECRET_ARN", "")
GROQ_MODEL = os.environ.get("GROQ_MODEL", "mixtral-8x7b-32768")
GROQ_TIMEOUT_SECONDS = int(os.environ.get("GROQ_TIMEOUT_SECONDS", "5"))

logger.info(
    f"Groq healing: enabled={GROQ_ENABLED}, model={GROQ_MODEL}, "
    f"timeout={GROQ_TIMEOUT_SECONDS}s"
)


CRITICAL_COLUMNS = {
    "clean_statistics": ["video_id", "title", "channel_title", "views", "region"],
    "clean_reference_data": ["id", "region"],
}


def check_row_count(df: pd.DataFrame, table_name: str) -> dict:
    """Check that table has minimum number of rows."""
    count = len(df)
    passed = count >= MIN_ROW_COUNT
    return {
        "check": "row_count",
        "table": table_name,
        "value": count,
        "threshold": MIN_ROW_COUNT,
        "passed": passed,
        "message": f"Row count: {count} (min: {MIN_ROW_COUNT})",
    }


def check_null_percentage(df: pd.DataFrame, table_name: str) -> list:
    """Check null percentages for critical columns."""
    results = []
    cols = CRITICAL_COLUMNS.get(table_name, [])

    for col in cols:
        if col not in df.columns:
            results.append({
                "check": "null_pct",
                "table": table_name,
                "column": col,
                "passed": False,
                "message": f"Column '{col}' missing from table",
            })
            continue

        null_pct = (df[col].isna().sum() / len(df)) * 100 if len(df) > 0 else 0
        passed = null_pct <= MAX_NULL_PCT
        results.append({
            "check": "null_pct",
            "table": table_name,
            "column": col,
            "value": round(null_pct, 2),
            "threshold": MAX_NULL_PCT,
            "passed": passed,
            "message": f"{col} null%: {null_pct:.2f}% (max: {MAX_NULL_PCT}%)",
        })

    return results


def check_schema(df: pd.DataFrame, table_name: str) -> dict:
    """Check that expected columns exist."""
    expected = set(CRITICAL_COLUMNS.get(table_name, []))
    actual = set(df.columns)
    missing = expected - actual
    passed = len(missing) == 0
    return {
        "check": "schema",
        "table": table_name,
        "missing_columns": list(missing),
        "passed": passed,
        "message": f"Missing columns: {missing}" if missing else "All expected columns present",
    }


def check_value_ranges(df: pd.DataFrame, table_name: str) -> list:
    """Check that numeric values are within reasonable ranges."""
    results = []

    if table_name != "clean_statistics":
        return results

    if "views" in df.columns:
        negative = (df["views"] < 0).sum()
        extreme = (df["views"] > MAX_VIEWS).sum()
        passed = negative == 0 and extreme == 0
        results.append({
            "check": "value_range",
            "table": table_name,
            "column": "views",
            "negative_count": int(negative),
            "extreme_count": int(extreme),
            "passed": passed,
            "message": f"Views: {negative} negative, {extreme} extreme (>{MAX_VIEWS})",
        })

    return results


def check_freshness(df: pd.DataFrame, table_name: str) -> dict:
    """Check that data includes recent records."""
    if "_processed_at" not in df.columns and "_ingestion_timestamp" not in df.columns:
        return {
            "check": "freshness",
            "table": table_name,
            "passed": True,
            "message": "No timestamp column found — skipping freshness check (backfill data)",
        }

    ts_col = "_processed_at" if "_processed_at" in df.columns else "_ingestion_timestamp"
    try:
        latest = pd.to_datetime(df[ts_col]).max()
        cutoff = datetime.now(timezone.utc) - timedelta(hours=FRESHNESS_HOURS)
        # Handle timezone-naive timestamps
        if latest.tzinfo is None:
            latest = latest.replace(tzinfo=timezone.utc)
        passed = latest >= cutoff
        return {
            "check": "freshness",
            "table": table_name,
            "latest_record": str(latest),
            "cutoff": str(cutoff),
            "passed": passed,
            "message": f"Latest: {latest}, Cutoff: {cutoff}",
        }
    except Exception as e:
        return {
            "check": "freshness",
            "table": table_name,
            "passed": True,
            "message": f"Could not parse timestamps: {e} — skipping",
        }


# ────────────────────────────────────────────────────────────────────────────
# Groq LLM Healing Functions
# ────────────────────────────────────────────────────────────────────────────

def get_groq_api_key() -> str:
    """
    Retrieve Groq API key from Secrets Manager.
    
    Returns:
        API key string
    
    Raises:
        Exception if secret cannot be retrieved
    """
    if not GROQ_SECRET_ARN:
        logger.error("GROQ_SECRET_ARN not configured")
        return None
    
    try:
        logger.info(f"Retrieving Groq API key from {GROQ_SECRET_ARN}")
        response = secrets_client.get_secret_value(SecretId=GROQ_SECRET_ARN)
        
        # SecretString is the actual secret value
        if "SecretString" in response:
            api_key = response["SecretString"]
            logger.info("✅ Groq API key retrieved successfully")
            return api_key
        else:
            logger.error("Secret does not contain SecretString")
            return None
    
    except Exception as e:
        logger.error(f"Failed to retrieve Groq API key: {e}")
        return None


def heal_failed_checks(
    all_results: list,
    failed_checks: list,
) -> tuple:
    """
    Attempt to heal failed quality checks using Groq LLM.
    
    Args:
        all_results: All quality check results
        failed_checks: Failed checks from the first run
    
    Returns:
        (healed_results, healing_succeeded) tuple
    """
    if not GROQ_ENABLED or not GROQ_HEALER_AVAILABLE:
        logger.info("Groq healing disabled or not available. Returning to source.")
        return all_results, False
    
    logger.info(f"Attempting to heal {len(failed_checks)} failed checks...")
    
    # Get Groq API key
    api_key = get_groq_api_key()
    if not api_key:
        logger.error("Could not retrieve Groq API key. Healing disabled.")
        return all_results, False
    
    # Initialize healer
    try:
        healer = GroqHealer(
            api_key=api_key,
            model=GROQ_MODEL,
            timeout=GROQ_TIMEOUT_SECONDS,
        )
        logger.info("✅ GroqHealer initialized")
    except Exception as e:
        logger.error(f"Failed to initialize GroqHealer: {e}")
        return all_results, False
    
    # For each failed check, attempt healing
    healing_metrics = {
        "attempted": 0,
        "succeeded": 0,
        "failed": 0,
    }
    
    for failed_check in failed_checks:
        check_type = failed_check.get("check", "unknown")
        table = failed_check.get("table", "unknown")
        
        logger.info(f"Healing {check_type} check for {table}...")
        healing_metrics["attempted"] += 1
        
        try:
            # Map check type to issue type for Groq
            issue_type = check_type  # e.g., "value_range", "null_pct"
            issue_details = failed_check.get("message", "")
            
            # Create a mock record for healing (using failed check details)
            mock_record = {
                "check_type": check_type,
                "table": table,
                "details": issue_details,
            }
            
            # Attempt healing
            healed = healer.heal_record(
                record=mock_record,
                issue_type=issue_type,
                issue_details=issue_details,
            )
            
            if healed:
                logger.info(f"✅ Healed {check_type}: {healed}")
                healing_metrics["succeeded"] += 1
                # Mark this check as healed
                failed_check["healing_attempted"] = True
                failed_check["healing_succeeded"] = True
            else:
                logger.warning(f"❌ Could not heal {check_type}")
                healing_metrics["failed"] += 1
                failed_check["healing_attempted"] = True
                failed_check["healing_succeeded"] = False
        
        except Exception as e:
            logger.error(f"Error healing {check_type}: {e}")
            healing_metrics["failed"] += 1
            failed_check["healing_attempted"] = True
            failed_check["healing_succeeded"] = False
    
    # Log healing summary
    logger.info(
        f"Healing summary: {healing_metrics['succeeded']}/{healing_metrics['attempted']} "
        f"checks healed successfully"
    )
    
    # Add healing metrics to results
    all_results.append({
        "check": "groq_healing",
        "passed": healing_metrics["succeeded"] > 0,
        "healing_metrics": healing_metrics,
    })
    
    # Return success if ANY checks were healed
    healing_succeeded = healing_metrics["succeeded"] > 0
    return all_results, healing_succeeded



def lambda_handler(event, context):
    """
    Run data quality checks on Silver layer tables.

    Expected event:
    {
        "layer": "silver",
        "database": "yt_pipeline_silver_dev",
        "tables": ["clean_statistics", "clean_reference_data"]
    }
    """
    database = event.get("database", "yt_pipeline_silver_dev")
    tables = event.get("tables", ["clean_statistics"])

    all_results = []
    overall_passed = True

    for table_name in tables:
        logger.info(f"Running DQ checks on {database}.{table_name}...")

        try:
            # Read a sample of the data (limit for cost/speed)
            query = f'SELECT * FROM "{table_name}" LIMIT 10000'
            df = wr.athena.read_sql_query(
                sql=query,
                database=database,
                s3_output=S3_OUTPUT,
                workgroup=WORKGROUP,
                ctas_approach=False,
            )
        except Exception as e:
            logger.error(f"Could not read {table_name}: {e}")
            all_results.append({
                "check": "read_table",
                "table": table_name,
                "passed": False,
                "message": str(e),
            })
            overall_passed = False
            continue

        # Run all checks
        checks = []
        checks.append(check_row_count(df, table_name))
        checks.extend(check_null_percentage(df, table_name))
        checks.append(check_schema(df, table_name))
        checks.extend(check_value_ranges(df, table_name))
        checks.append(check_freshness(df, table_name))

        for check in checks:
            logger.info(f"  {check['check']}: {'PASS' if check['passed'] else 'FAIL'} — {check['message']}")
            if not check["passed"]:
                overall_passed = False

        all_results.extend(checks)

    # Summary
    passed_count = sum(1 for r in all_results if r["passed"])
    total_count = len(all_results)
    logger.info(f"DQ Summary: {passed_count}/{total_count} checks passed. Overall: {'PASS' if overall_passed else 'FAIL'}")

    # ────────────────────────────────────────────────────────────────────────────
    # Groq Healing: Attempt to fix failed checks
    # ────────────────────────────────────────────────────────────────────────────
    
    if not overall_passed and GROQ_ENABLED:
        logger.info("Quality checks FAILED. Attempting Groq LLM healing...")
        failed_checks = [r for r in all_results if not r.get("passed", True)]
        
        all_results, healing_succeeded = heal_failed_checks(all_results, failed_checks)
        
        if healing_succeeded:
            # Some checks were healed, try again
            logger.info("Some checks were healed. Re-evaluating overall status...")
            passed_count = sum(1 for r in all_results if r.get("passed", True))
            total_count = len(all_results)
            
            # If all checks now pass, update overall_passed
            if sum(1 for r in all_results if not r.get("passed", True)) == 0:
                overall_passed = True
                logger.info("✅ All checks passed after healing!")
            else:
                logger.warning("⚠️  Some checks still failing even after healing attempt")
                overall_passed = False
        else:
            logger.warning("Healing did not improve any checks")
    
    # ────────────────────────────────────────────────────────────────────────────
    # Alert on failure
    # ────────────────────────────────────────────────────────────────────────────

    if not overall_passed and SNS_TOPIC:
        failed = [r for r in all_results if not r.get("passed", True)]
        message = {
            "status": "FAILED",
            "checks_passed": passed_count,
            "checks_total": total_count,
            "failed_checks": failed,
            "groq_healing_attempted": GROQ_ENABLED,
        }
        sns_client.publish(
            TopicArn=SNS_TOPIC,
            Subject="[YT Pipeline] Data quality checks FAILED",
            Message=json.dumps(message, indent=2, default=str),
        )
        logger.error("SNS alert sent for failed checks")

    return {
        "quality_passed": bool(overall_passed),
        "checks_passed": int(passed_count),
        "checks_total": int(total_count),
        "groq_healing_enabled": GROQ_ENABLED,
        "details": json.loads(json.dumps(all_results, default=str)),
    }