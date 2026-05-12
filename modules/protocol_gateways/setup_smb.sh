echo "$(date -u): running smb script"

# Replace resolv.conf symlink with a real file, preserving its current content.
# The SMB container cannot follow the symlink to /run/systemd/resolve/resolv.conf,
# so it needs a real file. Disable systemd-resolved to prevent it from recreating
# the symlink on reboot.
if [ -L /etc/resolv.conf ]; then
    resolved_content=$(cat /etc/resolv.conf)
    systemctl disable --now systemd-resolved
    rm -f /etc/resolv.conf
    printf '%s\n' "$resolved_content" > /etc/resolv.conf
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
    echo "$(date -u): SMB cluster already exists, adding current container to it"

    weka smb cluster containers add --container-ids $container_id
    weka smb cluster wait
    weka smb cluster status
    exit 0
fi

echo "$(date -u): weka SMB cluster does not exist, creating it"
# get all protocol gateways fromtend container ids separated by comma
all_container_ids_str=$(echo "$all_container_ids" | tr '\n' ',' | sed 's/,$//')

function retry_create_smb_cluster {
  retry_max=60
  retry_sleep=30
  count=$retry_max

  while [ $count -gt 0 ]; do
      weka smb cluster create ${cluster_name} ${domain_name} .config_fs --container-ids $all_container_ids_str && break
      count=$(($count - 1))
      echo "Retrying create SMB cluster in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "create SMB cluster command failed after $retry_max attempts"
      echo "$(date -u): create SMB cluster failed"
      return 1
  }
  return 0
}

echo "$(date -u): Retrying create SMB cluster..."

retry_create_smb_cluster

echo "$(date -u): Successfully create SMB cluster..."

weka smb cluster wait

weka smb cluster status

echo "$(date -u): SMB cluster was created successfully"
