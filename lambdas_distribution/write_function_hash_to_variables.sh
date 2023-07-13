#!/bin/bash

# Usage:
# write_function_hash_to_variables.sh <os_name> <function_code_path>

os_name="$1"
function_code_path="$2"

new_lambdas_zip_version=$(./lambdas_distribution/get_lambdas_hash.sh ${os_name} ${function_code_path})
old_lambdas_zip_version=$(awk '/Lambdas code version/{getline;print $NF;}' variables.tf | tr -d \")

echo "Replacing '$old_lambdas_zip_version' lambdas_version to '$new_lambdas_zip_version'"
if [ $os_name == "darwin" ]; then
    sed -i '' "s/$old_lambdas_zip_version/$new_lambdas_zip_version/" variables.tf
else
    sed -i "s/$old_lambdas_zip_version/$new_lambdas_zip_version/" variables.tf
fi
