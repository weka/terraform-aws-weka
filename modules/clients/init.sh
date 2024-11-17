#!/bin/bash
set -ex

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
instance_id=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)

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
    https_proxy="${proxy}"
EOF
}

# From http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/EC2NewInstanceCWL.html
function setup_aws_logs_agent() {
    echo "---------------------------"
    echo " Setting up AWS logs agent "
    echo "---------------------------"

    no_proxy=".amazonaws.com" https_proxy="${proxy}" yum install -y amazon-cloudwatch-agent || no_proxy=".amazonaws.com" https_proxy="${proxy}" apt install -y amazon-cloudwatch-agent || return 1
    configure_aws_logs_agent || return 1
    service amazon-cloudwatch-agent restart || return 1
}

setup_aws_logs_agent || echo "Failed to setup AWS logs agent"

yum -y install pip || true
apt update && apt install -y net-tools && apt install -y python3-pip || true
pip install --upgrade awscli || true

region=${region}
subnet_id=${subnet_id}
additional_nics_num=${additional_nics_num}

instance_type=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-type)
max_network_cards=$(aws ec2 describe-instance-types --region $region --instance-types $instance_type --query "InstanceTypes[0].NetworkInfo.MaximumNetworkCards" --output text)

counter=0
interface_index=1
for (( card_index=0; card_index<$max_network_cards ; card_index++)); do
  max_device=$(aws ec2 describe-instance-types --region $region --instance-types $instance_type --query "InstanceTypes[0].NetworkInfo.NetworkCards[$card_index].MaximumNetworkInterfaces")
  if [[ $card_index -gt 0 ]];then
    interface_index=0
  fi
  for (( interface_index=$interface_index; interface_index<$max_device; interface_index++ )); do
      if [[  $counter -eq $additional_nics_num ]]; then
          break
      fi
      eni=$(aws ec2 create-network-interface --ipv6-address-count ${ipv6_address_count} --region "$region" --subnet-id "$subnet_id" --groups ${groups}) # groups should not be in quotes it needs to be a list
      network_interface_id=$(echo "$eni" | python3 -c "import sys, json; print(json.load(sys.stdin)['NetworkInterface']['NetworkInterfaceId'])")
      attachment=$(aws ec2 attach-network-interface --region "$region" --network-card-index "$card_index" --device-index "$interface_index" --instance-id "$instance_id" --network-interface-id "$network_interface_id")
      attachment_id=$(echo "$attachment" | python3 -c "import sys, json; print(json.load(sys.stdin)['AttachmentId'])")
      aws ec2 modify-network-interface-attribute --region "$region" --attachment AttachmentId="$attachment_id",DeleteOnTermination=true --network-interface-id "$network_interface_id"
      counter=$(($counter+1))
  done
done
