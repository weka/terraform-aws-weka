echo "$(date -u): running S3 script"

not_ready_hosts=$(weka s3 cluster status | grep 'Not Ready' | wc -l)
all_hosts=$(weka s3 cluster status | grep 'Host' | wc -l)

function check_cluster_status() {
  echo "almog enter check_cluster_status "
  if (( all_hosts > 0 && not_ready_hosts == 0 && all_hosts == cluster_size )); then
          echo "almog enter if "
          echo "$(date -u): s3 cluster is already created"
          weka s3 cluster status
          exit 0
  fi
  echo "almog exit check_cluster_status "
}

# get all protocol gateways frontend container ids separated by comma
all_container_ids_str=$(echo "$all_container_ids" | tr '\n' ',' | sed 's/,$//')

function retry_create_s3_cluster {
  echo "almog enter retry_create_s3_cluster"
  retry_max=60
  retry_sleep=30
  count=$retry_max
  check_cluster_status
  echo "almog after check_cluster_status "
  while [ $count -gt 0 ]; do
      echo "almog about to run create command with containers $all_container_ids_str"
      weka fs
      weka s3 cluster status
      weka s3 cluster create $filesystem_name .config_fs --container $all_container_ids_str --port 9000 && break
      count=$(($count - 1))
      echo "Retrying create S3 cluster in $retry_sleep seconds..."
      sleep $retry_sleep
      check_cluster_status && break
  done
  [ $count -eq 0 ] && {
      echo "create S3 cluster command failed after $retry_max attempts"
      echo "$(date -u): create S3 cluster failed"
      return 1
  }
  return 0
}

if [[ $(weka s3 cluster status |grep -v 'IP') ]]; then
        echo "almog before check_cluster_status 1 "
        check_cluster_status
        echo "almog after check_cluster_status 1 "
        if (( all_hosts > 0 && not_ready_hosts == 0 && all_hosts < cluster_size )); then
              echo "$(date -u): S3 cluster already exists, adding current container to it"
              weka s3 cluster containers add $container_id
              sleep 10s
              weka s3 cluster status
              exit 0
        fi
else
  echo "$(date -u): weka S3 cluster does not exist, creating it"
  echo "almog before retry_create_s3_cluster 1 "
  retry_create_s3_cluster
  echo "almog after retry_create_s3_cluster 1 "
  echo "$(date -u): Successfully create S3 cluster..."
  weka s3 cluster status
  weka s3 cluster containers list
  echo "$(date -u): S3 cluster was created successfully"
fi

sleep 10s
echo "this is really s3 status"
weka s3 cluster status

echo "$(date -u): done running S3 script successfully"
