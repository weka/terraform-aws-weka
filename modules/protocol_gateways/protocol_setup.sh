echo "$(date -u): running init protocol gateway script"

weka local ps

config_filesystem_name=".config_fs"
function wait_for_config_fs(){
  max_retries=30 # 30 * 10 = 5 minutes
  for (( i=0; i < max_retries; i++ )); do
    if [ "$(weka fs | grep -c $config_filesystem_name)" -ge 1 ]; then
      echo "$(date -u): weka filesystem $config_filesystem_name is up"
      break
    fi
    echo "$(date -u): waiting for weka filesystem $config_filesystem_name to be up"
    sleep 10
  done
  if (( i > max_retries )); then
      echo "$(date -u): timeout: weka filesystem $config_filesystem_name is not up after $max_retries attempts."
      return 1
  fi
}

# make sure weka cluster is already up
max_retries=60
for (( i=0; i < max_retries; i++ )); do
  if [ $(weka status | grep 'status: OK' | wc -l) -ge 1 ]; then
    echo "$(date -u): weka cluster is up"
    break
  fi
  echo "$(date -u): waiting for weka cluster to be up"
  sleep 30
done
if (( i > max_retries )); then
    echo "$(date -u): timeout: weka cluster is not up after $max_retries attempts."
    exit 1
fi

cluster_size="${gateways_number}"

current_mngmnt_ip=$(weka local resources | grep 'Management IPs' | awk '{print $NF}')
# get container id
for ((i=0; i<20; i++)); do
  container_id=$(weka cluster container | grep frontend0 | grep $HOSTNAME | grep $current_mngmnt_ip | grep UP | awk '{print $1}')
  if [ -n "$container_id" ]; then
      echo "$(date -u): frontend0 container id: $container_id"
      break
  fi
  echo "$(date -u): waiting for frontend0 container to be up"
  sleep 5
done

if [ -z "$container_id" ]; then
  echo "$(date -u): Failed to get the frontend0 container ID."
  exit 1
fi

# getting gw instance ips
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
    if (( all_container_ids_number <  cluster_size )); then
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

if [[ ( ${smbw_enabled} == true && "${protocol}" == "SMB" ) || "${protocol}" == "S3" ]]; then
    wait_for_config_fs || exit 1
fi

sleep 30s

echo "$(date -u): Done running validation"
