#!/bin/bash

# Usage:
# upload_to_regions.sh <regions_file_dir> <dist> <os_name> <function_code_path> <function_zip_dir>

regions_file_dir="$1"
dist="$2"
os_name="$3"
function_code_path="$4"
function_zip_dir="$5"

regions_file="$regions_file_dir/${dist}.txt"
current_script_dir=$(dirname ${BASH_SOURCE[0]})
function_app_code_hash="$($current_script_dir/get_lambdas_hash.sh ${os_name} ${function_code_path})"

local_zip_file="$function_zip_dir/${function_app_code_hash}.zip"
object_name="${DIST}/${function_app_code_hash}.zip"

while read region; do 
    echo "Uploading to region: $region"
    bucket_name="tf-lambdas-${region}"
    ./lambdas_distribution/upload_to_bucket.sh "$local_zip_file" "$bucket_name" "$object_name"
done < $regions_file
