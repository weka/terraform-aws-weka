#!/bin/bash

# Usage:
# upload_to_bucket.sh <local_zip_file> <bucket_name> <object_name>

set -ex

local_zip_file="$1"
bucket_name="$2"
object_name="$3"

echo "Uploading $bucket_name/$object_name"

# Upload the zip file to the specified container
aws s3 cp \
    "$local_zip_file" \
    "s3://$bucket_name/$object_name" --acl public-read

echo "Upload complete."
