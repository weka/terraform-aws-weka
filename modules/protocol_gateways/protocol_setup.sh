# getting gw instance ips
cluster_size="${gateways_number}"
gw_ips_list=()
instance_list=$(weka cluster container -J  | jq '.[] | "\(.host_ip) \(.cloud.instance_id)"' |uniq |tr '\n' ',')
IFS="," read -ra ids <<< "$instance_list"
for instance in "$${ids[@]}"; do
  id=$(echo $instance | cut -d' ' -f2 | tr -d '"')
  echo "$(date -u): get tags for instance $id"
  if [[ -n `aws ec2 describe-tags --filters Name=resource-id,Values="$id" --region ${region} --output text | cut -f5 | grep ${gateways_name}` ]]; then
	  ip=$(echo $instance | cut -d' ' -f1 | tr -d '"')
    gw_ips_list+=($ip)
  fi
done

gw_ips=""
for ip in $${gw_ips_list[@]}; do
  gw_ips+="-e $ip "
done

max_retries=60
for (( retry=1; retry<=max_retries; retry++ )); do
    # get all UP gateway container ids
    all_container_ids=$(weka cluster container | grep frontend0 | grep -w -F $gw_ips | grep UP | awk '{print $1}')
    # if number of all_container_ids < cluster_size, do nothing
    all_container_ids_number=$(echo "$all_container_ids" | wc -l)
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
