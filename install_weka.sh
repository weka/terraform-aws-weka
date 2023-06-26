#!/bin/bash

set -ex

WEKA_INSTALL_URL=https://${token}@get.prod.weka.io/dist/v1/install/${weka_version}/${weka_version} | sh


FAILURE_DOMAIN=$(printf $(hostname -I) | sha256sum | tr -d '-' | cut -c1-16)
COMPUTE_MEMORY=${memory}
NUM_COMPUTE_CONTAINERS=${compute_num}
NUM_FRONTEND_CONTAINERS=${frontend_num}
NUM_DRIVE_CONTAINERS=${drive_num}
NICS_NUM=${nics_num}
INSTALL_DPDK=${install_dpdk}
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

# weka containers setup
get_core_ids $NUM_DRIVE_CONTAINERS drive_core_ids
get_core_ids $NUM_COMPUTE_CONTAINERS compute_core_ids
get_core_ids $NUM_FRONTEND_CONTAINERS frontend_core_ids

if [[ $INSTALL_DPDK == true ]]; then
  getNetStrForDpdk 1 $(($NUM_DRIVE_CONTAINERS+1)) "$GATEWAYS" "$SUBNETS"
  sudo weka local setup container --name drives0 --base-port 14000 --cores $NUM_DRIVE_CONTAINERS --no-frontends --drives-dedicated-cores $NUM_DRIVE_CONTAINERS --failure-domain $FAILURE_DOMAIN --core-ids $drive_core_ids $net --dedicate
  getNetStrForDpdk $((1+$NUM_DRIVE_CONTAINERS)) $((1+$NUM_DRIVE_CONTAINERS+$NUM_COMPUTE_CONTAINERS )) "$GATEWAYS" "$SUBNETS"
  sudo weka local setup container --name compute0 --base-port 15000 --cores $NUM_COMPUTE_CONTAINERS --no-frontends --compute-dedicated-cores $NUM_COMPUTE_CONTAINERS  --memory $COMPUTE_MEMORY --failure-domain $FAILURE_DOMAIN --core-ids $compute_core_ids $net --dedicate
  getNetStrForDpdk $(($NICS_NUM-1)) $(($NICS_NUM)) "$GATEWAYS" "$SUBNETS"
  sudo weka local setup container --name frontend0 --base-port 16000 --cores $NUM_FRONTEND_CONTAINERS --frontend-dedicated-cores $NUM_FRONTEND_CONTAINERS --allow-protocols true --failure-domain $FAILURE_DOMAIN --core-ids $frontend_core_ids $net --dedicate
else
  sudo weka local setup container --name drives0 --base-port 14000 --cores $NUM_DRIVE_CONTAINERS --no-frontends --drives-dedicated-cores $NUM_DRIVE_CONTAINERS --failure-domain $FAILURE_DOMAIN --core-ids $drive_core_ids  --dedicate
  sudo weka local setup container --name compute0 --base-port 15000 --cores $NUM_COMPUTE_CONTAINERS --no-frontends --compute-dedicated-cores $NUM_COMPUTE_CONTAINERS  --memory $COMPUTE_MEMORY --failure-domain $FAILURE_DOMAIN --core-ids $compute_core_ids  --dedicate
  sudo weka local setup container --name frontend0 --base-port 16000 --cores $NUM_FRONTEND_CONTAINERS --frontend-dedicated-cores $NUM_FRONTEND_CONTAINERS --allow-protocols true --failure-domain $FAILURE_DOMAIN --core-ids $frontend_core_ids  --dedicate
fi


# should not call 'clusterize' untill all 3 containers are up
ready_containers=0
while [ $ready_containers -ne 3 ];
do
  sleep 10
  ready_containers=$( weka local ps | grep -i 'running' | wc -l )
  echo "Running containers: $ready_containers"
done

rm -rf $INSTALLATION_PATH
echo "$(date -u): containers are up"



