FAILURE_DOMAIN=$(printf $(hostname -I) | sha256sum | tr -d '-' | cut -c1-16)
NUM_FRONTEND_CONTAINERS=${frontend_num}
NICS_NUM=${nics_num}
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
get_core_ids $NUM_FRONTEND_CONTAINERS frontend_core_ids

getNetStrForDpdk $(($NICS_NUM-1)) $(($NICS_NUM)) "$GATEWAYS" "$SUBNETS"

echo "$(date -u): setting up weka frontend"
# changed standart frontend port to 14000 as it should be used locally for protocol setup:
# weka@ev-test-NFS-0:~$ weka nfs interface-group add test NFS
# error: Error: Failed connecting to http://127.0.0.1:14000/api/v1. Make sure weka is running on this host by running
# 	 weka local status | start
sudo weka local setup container --name frontend0 --base-port 14000 --cores $NUM_FRONTEND_CONTAINERS --frontend-dedicated-cores $NUM_FRONTEND_CONTAINERS --allow-protocols true --failure-domain $FAILURE_DOMAIN --core-ids $frontend_core_ids $net --dedicate --join-ips ${backend_lb_ip}


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
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
weka_password=$(aws secretsmanager get-secret-value --region "$region" --secret-id ${weka_password_id} --query SecretString --output text)

weka user login admin $weka_password

rm -rf $INSTALLATION_PATH
