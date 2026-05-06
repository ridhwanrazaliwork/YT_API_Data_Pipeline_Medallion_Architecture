# add_raw_statistics_partitions.py
import boto3

AWS_REGION = "ap-southeast-1"
DATABASE = "yt_pipeline_bronze_dev-v2"
TABLE = "raw_statistics"
BUCKET = "rid-yt-pipeline-bronze-ap-southeast-1-dev-v2"
BASE_PREFIX = "youtube/raw_statistics"

REGIONS = ["de", "ca", "fr", "gb", "in", "jp", "kr", "mx", "ru", "us"]

glue = boto3.client("glue", region_name=AWS_REGION)

# Read table once so we reuse the same storage descriptor shape/serde/input/output format
table_obj = glue.get_table(DatabaseName=DATABASE, Name=TABLE)["Table"]
base_sd = table_obj["StorageDescriptor"]

allowed_sd_keys = {
    "Columns",
    "Location",
    "AdditionalLocations",
    "InputFormat",
    "OutputFormat",
    "Compressed",
    "NumberOfBuckets",
    "SerdeInfo",
    "BucketColumns",
    "SortColumns",
    "Parameters",
    "SkewedInfo",
    "StoredAsSubDirectories",
    "SchemaReference",
}

def build_storage_descriptor(location: str):
    sd = {k: v for k, v in base_sd.items() if k in allowed_sd_keys}
    sd["Location"] = location
    return sd

partition_inputs = []
for region in REGIONS:
    loc = f"s3://{BUCKET}/{BASE_PREFIX}/region={region}/"
    partition_inputs.append(
        {
            "Values": [region],
            "StorageDescriptor": build_storage_descriptor(loc),
            "Parameters": {},
        }
    )

# Batch add (up to 100 per call)
resp = glue.batch_create_partition(
    DatabaseName=DATABASE,
    TableName=TABLE,
    PartitionInputList=partition_inputs,
)

errors = resp.get("Errors", [])
if not errors:
    print("All partitions added successfully.")
else:
    print("Some partitions had errors:")
    for e in errors:
        vals = e.get("PartitionValues", [])
        detail = e.get("ErrorDetail", {})
        print(f"  {vals}: {detail.get('ErrorCode')} - {detail.get('ErrorMessage')}")

# Quick verify
parts = glue.get_partitions(DatabaseName=DATABASE, TableName=TABLE, MaxResults=100).get("Partitions", [])
print(f"Registered partitions now: {len(parts)}")
print("Examples:", [p["Values"] for p in parts[:10]])