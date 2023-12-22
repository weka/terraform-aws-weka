echo "$(date -u): running smb script"
weka local ps

current_mngmnt_ip=$(weka local resources | grep 'Management IPs' | awk '{print $NF}')
cluster_size="${gateways_number}"
secondary_ips_num="${secondary_ips_number}"

function wait_for_weka_fs(){
  filesystem_name="default"
  max_retries=30 # 30 * 10 = 5 minutes
  for (( i=0; i < max_retries; i++ )); do
    if [ "$(weka fs | grep -c $filesystem_name)" -ge 1 ]; then
      echo "$(date -u): weka filesystem $filesystem_name is up"
      break
    fi
    echo "$(date -u): waiting for weka filesystem $filesystem_name to be up"
    sleep 10
  done
  if (( i > max_retries )); then
      echo "$(date -u): timeout: weka filesystem $filesystem_name is not up after $max_retries attempts."
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

# getting smb gw instance ips
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
    all_container_ids=$(weka cluster container | grep frontend0 | grep $gw_ips | grep UP | awk '{print $1}')
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

# wait for weka smb cluster to be ready in case it was created by another host
weka smb cluster wait

not_ready_hosts=$(weka smb cluster status | grep 'Not Ready' | wc -l)
all_hosts=$(weka smb cluster status | grep 'Host' | wc -l)

if (( all_hosts > 0 && not_ready_hosts == 0 && all_hosts == cluster_size )); then
    echo "$(date -u): SMB cluster is already created"
    weka smb cluster status
    exit 0
fi

if (( all_hosts > 0 && not_ready_hosts == 0 && all_hosts < cluster_size )); then
    echo "$(date -u): SMB cluster already exists, you can add new container manually"

    weka smb cluster status
    exit 0
fi

echo "$(date -u): weka SMB cluster does not exist, creating it"
# get all protocol gateways fromtend container ids separated by comma
all_container_ids_str=$(echo "$all_container_ids" | tr '\n' ',' | sed 's/,$//')

# all secondary ips of all GW hosts
all_secondary_ips=($(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${gateways_name}" "Name=tag:weka_hostgroup_type,Values=gateways-protocol" \
  --query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[?Primary==`false`].PrivateIpAddress' \
  --region ${region} \
  --output json | jq -r 'flatten[]'))
# if number of all_secondary_ips < cluster_size * secondary_ips_num, do nothing
# length of all_secondary_ips array should be cluster_size * secondary_ips_num
all_secondary_ips_number=$${#all_secondary_ips[@]}
if (( all_secondary_ips_number < cluster_size * secondary_ips_num )); then
    echo "$(date -u): not all secondary ips are in the list - do nothing"
    exit 1
else
    echo "$(date -u): all containers are ready"
fi

# get all secondary ips separated by comma
secondary_ips_str=$(IFS=,; printf "%s" "$${all_secondary_ips[*]}")

# if smbw_enabled is true, enable SMBW by adding --smbw flag
smbw_cmd_extention=""
if [[ ${smbw_enabled} == true ]]; then
    smbw_cmd_extention="--smbw --config-fs-name .config_fs"
fi

weka smb cluster create ${cluster_name} ${domain_name} $smbw_cmd_extention --container-ids $all_container_ids_str --smb-ips-pool $secondary_ips_str
weka smb cluster wait

# add an SMB share if share_name is not empty
# 'default' is the fs-name of weka file system created during clusterization
if [ -n "${share_name}" ]; then
    wait_for_weka_fs || return 1
    weka smb share add ${share_name} default || true
fi

weka smb cluster status

echo "$(date -u): SMB cluster is created successfully"
