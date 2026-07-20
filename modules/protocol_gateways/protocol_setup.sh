# wait until all protocol-gateway frontend containers are UP
cluster_size="${gateways_number}"

# gateway instance IDs (single AWS call, matched by the Name tag the module assigns)
gw_instance_ids=($(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${gateways_name}" \
  --region ${region} \
  --query 'Reservations[].Instances[].InstanceId' --output text))

max_retries=60
for (( retry=1; retry<=max_retries; retry++ )); do
    # UP frontend containers running on the gateway instances
    all_container_ids=$(weka cluster container -J | jq -r '
        .[]
        | select(.name == "frontend0" and .status == "UP"
                 and (.cloud.instance_id | IN($ARGS.positional[])))
        | .id' --args "$${gw_instance_ids[@]}")

    all_container_ids_number=$(echo "$all_container_ids" | grep -c .)
    if (( all_container_ids_number < cluster_size )); then
        echo "$(date -u): not all containers are ready - do retry $retry of $max_retries"
        sleep 20
    else
        echo "$(date -u): all containers are ready"
        break
    fi
done

if (( retry > max_retries )); then
    echo "$(date -u): timeout: not all containers are ready after $max_retries attempts."
    exit 1
fi

echo "$(date -u): Done running validation for protocol"
