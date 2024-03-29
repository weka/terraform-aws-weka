FAILURE_DOMAIN=$(printf $(hostname -I) | sha256sum | tr -d '-' | cut -c1-16)
FRONTEND_CONTAINER_CORES_NUM=${frontend_container_cores_num}
SUBNET_PREFIXES=( "${subnet_prefixes}" )
GATEWAYS=""
for subnet in $${SUBNET_PREFIXES[@]}
do
	gateway=$(python3 -c "import ipaddress;import sys;n = ipaddress.IPv4Network(sys.argv[1]);sys.stdout.write(n[1].compressed)" "$subnet")
	GATEWAYS="$GATEWAYS $gateway"
done
GATEWAYS=$(echo "$GATEWAYS" | sed 's/ //')

# get_core_ids bash function definition

core_ids=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -d "-" -f 1 |  cut -d "," -f 1 | sort -u | tr '\n' ' ')
core_ids="$${core_ids[@]/0}"
IFS=', ' read -r -a core_ids <<< "$core_ids"
core_idx_begin=0
get_core_ids() {
	core_idx_end=$(($core_idx_begin + $1))
	res=$${core_ids["$core_idx_begin"]}
	for (( i=$(($core_idx_begin + 1)); i<$core_idx_end; i++ ))
	do
		res=$res,$${core_ids[i]}
	done
	core_idx_begin=$core_idx_end
	eval "$2=$res"
}

weka local stop
weka local rm default --force

getNetStrForDpdk() {
	i=$1
	j=$2
	gateways=$3

	net=""
  for ((i; i<$j; i++)); do
		eth=eth$i
		subnet_inet=$(ifconfig $eth | grep 'inet ' | awk '{print $2}')
		if [ -z $subnet_inet ] || [ $${#gateways[@]} -eq 0 ];then
			net="$net --net $eth" #aws
			continue
		fi
		enp=$(ls -l /sys/class/net/$eth/ | grep lower | awk -F"_" '{print $2}' | awk '{print $1}') #for azure
		if [ -z $enp ];then
			enp=$(ethtool -i $eth | grep bus-info | awk '{print $2}') #pci for gcp
		fi
		bits=$(ip -o -f inet addr show $eth | awk '{print $4}')
		IFS='/' read -ra netmask <<< "$bits"

		net="$net --net $enp/$subnet_inet/$${netmask[1]}/$gateway"
  done
}

# weka containers setup
get_core_ids $FRONTEND_CONTAINER_CORES_NUM frontend_core_ids

getNetStrForDpdk 1 $(($FRONTEND_CONTAINER_CORES_NUM + 1)) "$GATEWAYS"

echo "$(date -u): setting up weka frontend"
# changed standart frontend port to 14000 as it should be used locally for protocol setup:
# weka@ev-test-NFS-0:~$ weka nfs interface-group add test NFS
# error: Error: Failed connecting to http://127.0.0.1:14000/api/v1. Make sure weka is running on this host by running
# 	 weka local status | start
# if alb_dns_name if not empty string, then use alb_dns_name as ips
if [ -z "${lb_arn_suffix}" ]; then
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

  ips=$private_ips_array
else

  lb_ips=$(aws ec2 describe-network-interfaces --filters Name=description,Values="ELB ${lb_arn_suffix}" --query 'NetworkInterfaces[*].PrivateIpAddresses[*].PrivateIpAddress' --region ${region} --output text)
  ips_list=$(echo $lb_ips |tr -d '\n')
  IFS=' ' read -r -a ips <<< "$ips_list"

fi

backend_ip="$${ips[RANDOM % $${#ips[@]}]}"

# install weka using random backend ip from ips list
function retry_command {
  retry_max=60
  retry_sleep=30
  count=$retry_max
  command=$1
  msg=$2


  while [ $count -gt 0 ]; do
      $command && break
      count=$(($count - 1))
      backend_ip="$${ips[RANDOM % $${#ips[@]}]}"
      echo "Retrying $msg in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "$msg failed after $retry_max attempts"
      echo "$(date -u): $msg installation failed"
      return 1
  }
  return 0
}

run_container_cmd="sudo weka local setup container --name frontend0 --base-port 14000 --cores $FRONTEND_CONTAINER_CORES_NUM --frontend-dedicated-cores $FRONTEND_CONTAINER_CORES_NUM --allow-protocols true --failure-domain $FAILURE_DOMAIN --core-ids $frontend_core_ids $net --dedicate --join-ips $backend_ip"
retry_command "$run_container_cmd"  "install frontend0 container"

# check that frontend container is up
ready_containers=0
while [ $ready_containers -ne 1 ];
do
  sleep 10
  ready_containers=$( weka local ps | grep -i 'running' | wc -l )
  echo "Running containers: $ready_containers"
done

echo "$(date -u): frontend is up"

# login to weka
echo "$(date -u): try to run weka login command"
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
weka_password=$(aws secretsmanager get-secret-value --region "$region" --secret-id ${weka_password_id} --query SecretString --output text)

retry_command "weka user login admin $weka_password" "login to weka cluster"
echo "$(date -u): success to run weka login command"

rm -rf $INSTALLATION_PATH
