echo "$(date -u): before weka agent installation"

INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH
cd $INSTALLATION_PATH

# if alb_dns_name if not empty string, then use alb_dns_name as ips
if [ -z "${alb_dns_name}" ]; then
  # Function to get the private IPs of instances in Auto Scaling Group
  get_private_ips() {
    instance_ids=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "${backends_asg_name}" --query "AutoScalingGroups[].Instances[].InstanceId" --output text --region ${region})
    private_ips=$(aws ec2 describe-instances --instance-ids $instance_ids --query "Reservations[].Instances[].PrivateIpAddress" --output text --region ${region})
    private_ips_array=($private_ips)
  }

  # Retry until the length of the array is not 'weka_cluster_size'
  while true; do
    get_private_ips
    length=$${#private_ips_array[@]}
    # if the length == weka_cluster_size , break out of the loop
    if [ $length -eq ${weka_cluster_size} ]; then
      break
    fi
    # sleep for a while (optional) and retry
    echo "Waiting for all backend instances to be up... $length/$${weka_cluster_size}"
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
      curl --fail -o install_script.sh $backend_ip:14000/dist/v1/install && break
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

gateways="${all_gateways}"
NICS_NUM="${nics_num}"
eth0=$(ifconfig | grep eth0 -C2 | grep 'inet ' | awk '{print $2}')

function getNetStrForDpdk() {
	i=$1
	j=$2
	gateways=$3
	gateways=($gateways) #azure and gcp

	net="-o net="
	for ((i; i<$j; i++)); do
		eth=eth$i
		subnet_inet=$(ifconfig $eth | grep 'inet ' | awk '{print $2}')
		if [ -z $subnet_inet ] || [ $${#gateways[@]} -eq 0 ];then
			net="$net$eth" #aws
			continue
		fi
		enp=$(ls -l /sys/class/net/$eth/ | grep lower | awk -F"_" '{print $2}' | awk '{print $1}') #for azure
		if [ -z $enp ];then
			enp=$(ethtool -i $eth | grep bus-info | awk '{print $2}') #pci for gcp
		fi
		bits=$(ip -o -f inet addr show $eth | awk '{print $4}')
		IFS='/' read -ra netmask <<< "$bits"

		gateway=$${gateways[$i]}
    net="$net$enp/$subnet_inet/$${netmask[1]}/$gateway"
	done
}

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
if [[ ${mount_clients_dpdk} == true ]]; then
    getNetStrForDpdk $(($NICS_NUM-1)) $(($NICS_NUM)) "$gateways"
    mount_command="mount -t wekafs $net -o num_cores=1 -o mgmt_ip=$eth0 $backend_ip/$FILESYSTEM_NAME $MOUNT_POINT"
fi

retry 60 45 $mount_command
echo "$(date -u): wekafs mount complete"


rm -rf $INSTALLATION_PATH
echo "$(date -u): client setup complete"
