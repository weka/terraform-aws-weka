echo "$(date -u): before weka agent installation"

INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH
cd $INSTALLATION_PATH

# if alb_dns_name if not empty string, then use alb_dns_name as ips
if [ -z "${alb_dns_name}" ]; then
  # Function to get the private IPs of instances in Auto Scaling Group
  get_private_ips() {
    instance_ids=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "${backends_asg_name}" --query "AutoScalingGroups[].Instances[].InstanceId" --output text --region ${region})
    cluster_min_size=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "${backends_asg_name}" --query "AutoScalingGroups[].MinSize" --output text --region ${region})
    private_ips=$(aws ec2 describe-instances --instance-ids $instance_ids --query "Reservations[].Instances[].PrivateIpAddress" --output text --region ${region})
    private_ips_array=($private_ips)
  }

  # Retry until the length of the array is not the same as the cluster min size
  while true; do
    get_private_ips
    length=$${#private_ips_array[@]}
    expected_length=$${cluster_min_size}
    # if the length >= expected_length , break out of the loop
    if [ $length -ge $expected_length ]; then
      break
    fi
    # sleep for a while (optional) and retry
    echo "Waiting for all backend instances to be up... $length/$expected_length"
    sleep 5
  done

  ips=("$${private_ips_array[@]}")
else
  ips=(${alb_dns_name})
fi

backend_ip="$${ips[RANDOM % $${#ips[@]}]}"
# install weka using random backend ip from ips list
function retry_weka_install {
  retry_max=60
  retry_sleep=30
  count=$retry_max

  while [ $count -gt 0 ]; do
      curl --fail --insecure -o install_script.sh ${protocol}://$backend_ip:14000/dist/v1/install && break
      count=$(($count - 1))
      backend_ip="$${ips[RANDOM % $${#ips[@]}]}"
      echo "Retrying weka install from $backend_ip in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "weka install failed after $retry_max attempts"
      echo "$(date -u): weka install failed"
      return 1
  }
  chmod +x install_script.sh && ./install_script.sh
  return 0
}

retry_weka_install

echo "$(date -u): weka agent installation complete"

FILESYSTEM_NAME=default # replace with a different filesystem at need
MOUNT_POINT=/mnt/weka # replace with a different mount point at need
mkdir -p $MOUNT_POINT

weka local stop && weka local rm -f --all

FRONTEND_CONTAINER_CORES_NUM="${frontend_container_cores_num}"
first_interface_name=$(ls /sys/class/net | grep -vE 'docker|veth|lo' | sort --version-sort | head -n 1)
first_interface_ip=$(ip addr show "$first_interface_name" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

function retry {
  local retry_max=$1
  local retry_sleep=$2
  shift 2
  local count=$retry_max
  while [ $count -gt 0 ]; do
      "$@" && break
      count=$(($count - 1))
      echo "Retrying $* in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "Retry failed [$retry_max]: $*"
      echo "$(date -u): retry failed"
      return 1
  }
  return 0
}

echo "$(date -u): Retry mount client"
mount_command="mount -t wekafs -o net=udp $backend_ip/$FILESYSTEM_NAME $MOUNT_POINT"
if [[ ${clients_use_dpdk} == true ]]; then
    mount_command="mount -t wekafs -o num_cores=$FRONTEND_CONTAINER_CORES_NUM -o mgmt_ip=$first_interface_ip $backend_ip/$FILESYSTEM_NAME $MOUNT_POINT"
fi

retry 60 45 $mount_command
echo "$(date -u): wekafs mount complete"


rm -rf $INSTALLATION_PATH
echo "$(date -u): client setup complete"
