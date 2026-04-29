"""
groq_healer.py — Groq LLM Integration for Data Quality Healing

Purpose:
  When data quality checks fail, this module calls the Groq API
  to intelligently fix data issues.

Usage:
  from groq_healer import GroqHealer
  
  healer = GroqHealer(
      api_key="sk-...",
      model="mixtral-8x7b-32768",
      timeout=5
  )
  
  healed_record = healer.heal_record(
      record={"views": -100, "title": None},
      issue_type="value_range"
  )

Integration with data_quality Lambda:
  - Called when quality check FAILS
  - Attempts to fix the record
  - If healing succeeds: pass record to Gold
  - If healing fails: return record to source (Step Functions retries)
"""

import json
import logging
import time
from typing import Optional, Dict, Any
from abc import ABC

logger = logging.getLogger(__name__)

# Try to import Groq SDK (pip install groq)
try:
    from groq import Groq, RateLimitError, APITimeoutError
    GROQ_AVAILABLE = True
except ImportError:
    GROQ_AVAILABLE = False
    logger.warning("Groq SDK not available. Install with: pip install groq")


class GroqHealer:
    """
    Heals data quality issues using Groq LLM API.
    
    Features:
    - Exponential backoff for retries (1s, 2s, 4s)
    - Timeout protection (5s per call)
    - Rate limit handling (429 responses)
    - Structured prompts for consistent healing
    """
    
    def __init__(
        self,
        api_key: str,
        model: str = "mixtral-8x7b-32768",
        timeout: int = 5,
        max_retries: int = 3,
    ):
        """
        Initialize Groq healer.
        
        Args:
            api_key: Groq API key
            model: Model to use (default: mixtral)
            timeout: Timeout per API call in seconds
            max_retries: Maximum retry attempts with backoff
        """
        self.api_key = api_key
        self.model = model
        self.timeout = timeout
        self.max_retries = max_retries
        
        if not GROQ_AVAILABLE:
            raise ImportError(
                "Groq SDK not installed. Install with: pip install groq"
            )
        
        self.client = Groq(api_key=api_key)
        logger.info(
            f"GroqHealer initialized: model={model}, timeout={timeout}s, "
            f"retries={max_retries}"
        )
    
    def heal_record(
        self,
        record: Dict[str, Any],
        issue_type: str,
        issue_details: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Attempt to heal a data quality issue.
        
        Args:
            record: Data record with issue
            issue_type: Type of issue (value_range, null_percent, schema, freshness)
            issue_details: Additional context about the issue
        
        Returns:
            Healed record dict, or None if healing failed
        
        Examples:
            # Negative view count
            healed = healer.heal_record(
                record={"video_id": "abc", "views": -100},
                issue_type="value_range",
                issue_details="views cannot be negative"
            )
            
            # Null title
            healed = healer.heal_record(
                record={"video_id": "abc", "title": None},
                issue_type="null_percent",
                issue_details="title is required"
            )
        """
        logger.info(
            f"Healing record with issue_type={issue_type}: {record}"
        )
        
        # Build prompt
        prompt = self._build_healing_prompt(record, issue_type, issue_details)
        
        # Retry with exponential backoff
        for attempt in range(self.max_retries):
            try:
                response = self._call_groq_api(prompt)
                healed_record = self._parse_response(response, record)
                
                if healed_record:
                    logger.info(
                        f"✅ Healing succeeded on attempt {attempt + 1}: "
                        f"{healed_record}"
                    )
                    return healed_record
                else:
                    logger.warning(
                        f"Healing returned no changes on attempt {attempt + 1}"
                    )
            
            except RateLimitError as e:
                logger.warning(
                    f"⚠️  Rate limit exceeded on attempt {attempt + 1}: {e}"
                )
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** attempt  # Exponential backoff
                    logger.info(f"Retrying after {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    logger.error("Max retries exceeded due to rate limit")
                    return None
            
            except APITimeoutError as e:
                logger.warning(
                    f"⚠️  API timeout on attempt {attempt + 1}: {e}"
                )
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** attempt
                    logger.info(f"Retrying after {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    logger.error("Max retries exceeded due to timeout")
                    return None
            
            except Exception as e:
                logger.error(f"❌ Healing failed on attempt {attempt + 1}: {e}")
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** attempt
                    logger.info(f"Retrying after {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    logger.error("Max retries exceeded")
                    return None
        
        logger.error("❌ Healing failed after all retry attempts")
        return None
    
    def _build_healing_prompt(
        self,
        record: Dict[str, Any],
        issue_type: str,
        issue_details: Optional[str] = None,
    ) -> str:
        """Build the Groq API prompt for healing."""
        
        issue_descriptions = {
            "value_range": "Fix numeric values that are out of range (negative, extreme high)",
            "null_percent": "Fill in missing required fields with reasonable values",
            "schema": "Ensure all required columns exist and have correct types",
            "freshness": "Update outdated timestamps to current time",
        }
        
        issue_desc = issue_descriptions.get(
            issue_type,
            f"Fix issue of type: {issue_type}"
        )
        
        if issue_details:
            issue_desc += f" ({issue_details})"
        
        record_json = json.dumps(record, indent=2, default=str)
        
        prompt = f"""You are a data quality expert. Fix this data quality issue:

Issue Type: {issue_type}
Issue: {issue_desc}

Record:
{record_json}

Instructions:
1. Identify the specific quality issue
2. Apply a reasonable fix based on the context
3. Return ONLY valid JSON (no markdown, no explanation)
4. Keep original values where possible
5. Use NULL for values you cannot fix

Output JSON (no other text):"""
        
        return prompt
    
    def _call_groq_api(self, prompt: str) -> str:
        """Call Groq API with timeout and error handling."""
        logger.debug(f"Calling Groq API with model={self.model}, timeout={self.timeout}s")
        
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": prompt,
                    }
                ],
                temperature=0.1,  # Low temperature for deterministic output
                max_tokens=500,
                timeout=self.timeout,  # seconds
            )
            
            result = response.choices[0].message.content
            logger.debug(f"Groq response: {result}")
            return result
        
        except Exception as e:
            logger.error(f"Groq API call failed: {e}")
            raise
    
    def _parse_response(
        self,
        response: str,
        original_record: Dict[str, Any],
    ) -> Optional[Dict[str, Any]]:
        """Parse Groq response and return healed record."""
        
        # Try to extract JSON from response
        response = response.strip()
        
        # If response contains markdown code block, extract it
        if "```json" in response:
            response = response.split("```json")[1].split("```")[0].strip()
        elif "```" in response:
            response = response.split("```")[1].split("```")[0].strip()
        
        try:
            healed = json.loads(response)
            
            if not isinstance(healed, dict):
                logger.warning(f"Response is not a dict: {type(healed)}")
                return None
            
            # Merge with original record (in case Groq only fixed some fields)
            merged = original_record.copy()
            merged.update(healed)
            
            logger.debug(f"Parsed healed record: {merged}")
            return merged
        
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Groq response as JSON: {e}")
            logger.error(f"Response was: {response[:200]}")
            return None
    
    def get_healing_metrics(self) -> Dict[str, Any]:
        """Return metrics about healing performance (for monitoring)."""
        return {
            "model": self.model,
            "timeout_seconds": self.timeout,
            "max_retries": self.max_retries,
        }


# For testing without Groq API
class MockGroqHealer:
    """Mock healer for testing (no API calls)."""
    
    def __init__(self, **kwargs):
        logger.info("Using MockGroqHealer (testing mode)")
    
    def heal_record(
        self,
        record: Dict[str, Any],
        issue_type: str,
        issue_details: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        """Mock healing: return cleaned record."""
        logger.info(f"MockHealer: healing {issue_type}")
        
        healed = record.copy()
        
        # Simple mock logic
        if issue_type == "value_range":
            if "views" in healed and healed["views"] < 0:
                healed["views"] = 0
        
        elif issue_type == "null_percent":
            for key, value in healed.items():
                if value is None:
                    healed[key] = f"[AUTO-FILLED: {key}]"
        
        return healed
