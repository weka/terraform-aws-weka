#!/bin/bash
set -ex

token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
instance_id=$(curl -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/meta-data/instance-id)

#--------------------------------------#
# AWS Logs Agent                       #
#--------------------------------------#

function configure_aws_logs_agent() {
  cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
    {
      "agent": {
        "metrics_collection_interval": 10,
        "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/messages",
                "log_group_name": "${weka_log_group_name}",
                "log_stream_name": "$instance_id-syslog",
                "retention_in_days": 30,
                "timezone": "LOCAL",
                "timestamp_format": "%b %d %H:%M:%S"
              }
            ]
          }
        },
        "log_stream_name": "$instance_id-syslog",
        "force_flush_interval" : 15
      }
    }
EOF

  cat > /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml <<EOF
    [proxy]
    https_proxy="${proxy_url}"
EOF
}

# From http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/EC2NewInstanceCWL.html
function setup_aws_logs_agent() {
    echo "---------------------------"
    echo " Setting up AWS logs agent "
    echo "---------------------------"

    no_proxy=".amazonaws.com" https_proxy="${proxy_url}" yum install -y amazon-cloudwatch-agent.x86_64 || return 1
    configure_aws_logs_agent || return 1
    service amazon-cloudwatch-agent restart || return 1
}

setup_aws_logs_agent || echo "Failed to setup AWS logs agent"

region=${region}
subnet_id=${subnet_id}
nics_num=${nics_num}

for (( i=1; i<nics_num; i++ ))
do
  eni=$(aws ec2 create-network-interface --region "$region" --subnet-id "$subnet_id" --groups "${groups}" --secondary-private-ip-address-count "${secondary_ips_per_nic}") # groups should not be in quotes it needs to be a list
  network_interface_id=$(echo "$eni" | python3 -c "import sys, json; print(json.load(sys.stdin)['NetworkInterface']['NetworkInterfaceId'])")
  attachment=$(aws ec2 attach-network-interface --region "$region" --device-index "$i" --instance-id "$instance_id" --network-interface-id "$network_interface_id")
  attachment_id=$(echo "$attachment" | python3 -c "import sys, json; print(json.load(sys.stdin)['AttachmentId'])")
  aws ec2 modify-network-interface-attribute --region "$region" --attachment AttachmentId="$attachment_id",DeleteOnTermination=true --network-interface-id "$network_interface_id"
done


# install weka
INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH
cd $INSTALLATION_PATH

echo "$(date -u): before weka agent installation"
yum -y update
yum -y install jq
# get token for secret manager (get-weka-io-token)
max_retries=12 # 12 * 10 = 2 minutes
for ((i=0; i<max_retries; i++)); do
  TOKEN=$(aws secretsmanager get-secret-value --region "$region" --secret-id ${weka_token_id} --query SecretString --output text)
  if [ "$TOKEN" != "null" ]; then
    break
  fi
  sleep 10
  echo "$(date -u): waiting for token secret to be available"
done

# https://gist.github.com/fungusakafungus/1026804
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

# install weka
if [[ "${install_weka_url}" == *.tar ]]; then
    wget -P $INSTALLATION_PATH "${install_weka_url}"
    IFS='/' read -ra tar_str <<< "\"${install_weka_url}\""
    pkg_name=$(cut -d'/' -f"$${#tar_str[@]}" <<< "${install_weka_url}")
    cd $INSTALLATION_PATH
    tar -xvf $pkg_name
    tar_folder=$(echo $pkg_name | sed 's/.tar//')
    cd $INSTALLATION_PATH/$tar_folder
    ./install.sh
  else
    retry 300 2 curl --fail --proxy "${proxy_url}" --max-time 10 "${install_weka_url}" | sh
fi

echo "$(date -u): weka agent installation complete"
