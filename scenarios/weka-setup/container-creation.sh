#!/bin/bash

# Read the private-backends.txt file and construct the joinips variable
joinips=$(paste -sd, /tmp/private-backends.txt)

# This function returns NIC info in format dev/ip/mask/gw
# For example: "eth1/172.31.89.79/20/172.31.80.1"
# If there is more than one NIC passed, it returns a comma-separated list
function func_nicnet() {
    local nics=$@
    for nic in ${nics}; do
        local ipmask=$(sudo ip -4 addr show dev ${nic} | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
        local gw=$(ip -4 route list dev ${nic} default | awk '{print $3}')
        echo "${nic}/${ipmask}/${gw}"
    done | paste -s -d","
}

# Set the management IP (usually eth0)
mgmtip=$(echo $(func_nicnet eth0) | awk -F/ '{print $2}')

# Define the role of each NIC on the instance
# One NIC per DRIVE core
drivnet=$(func_nicnet eth1)
# One NIC per COMPUTE core
compnet=$(func_nicnet eth2 eth3)

# Configure local drives0 container
sudo weka local setup container --failure-domain $(hostname -s) --name drives0 --only-drives-cores \
--base-port 14000 --net $drivnet --management-ips ${mgmtip} --join-ips ${joinips} \
--cores 1 --core-ids 1 --memory 4GB

# Configure local compute0 container
sudo weka local setup container --failure-domain $(hostname -s) --name compute0 --only-compute-cores \
--base-port 15000 --net $compnet --management-ips ${mgmtip} --join-ips ${joinips} \
--cores 2 --core-ids 2,3 --memory 8GB

