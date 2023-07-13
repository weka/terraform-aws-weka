#!/bin/bash

# Usage:
# create_lambdas_zip.sh <os_name> <function_code_path> <function_zip_dir>

set -e

os_name="$1"
function_code_path="$2"
function_zip_dir="$3"

current_script_dir=$(dirname ${BASH_SOURCE[0]})

lambdas_code_hash="$($current_script_dir/get_lambdas_hash.sh ${os_name} ${function_code_path})"
echo "lambdas_code_hash: $lambdas_code_hash"

function_zip_path="${function_zip_dir}/${lambdas_code_hash}.zip"

echo "Building function code..."

echo "function_zip_path: $function_zip_path"
func_zip_dir="$(dirname $function_zip_path)"
echo "Creating dir $func_zip_dir"
mkdir -p $func_zip_dir

# Go to the function code directory
cd $function_code_path

# Build the function app
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o lambdas
echo "Function code built."

echo "Creating zip archive..."
zip $function_zip_path lambdas
rm lambdas
echo "Zip archive created: $function_zip_path"
