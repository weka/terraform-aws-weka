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

yum install -y jq

region=${region}
subnet_id=${subnet_id}
nics_num=${nics_num}

while true; do
  network_interface_id=$(aws ec2 describe-network-interfaces --region "$region" --filters "Name=attachment.instance-id,Values=$instance_id" --query "NetworkInterfaces[0].NetworkInterfaceId" --output text || true)
  if [ $? -eq 0 ] && [ -n "$network_interface_id" ]; then
    break
  fi
  echo "Didn't manage to describe network interfaces, retrying..."
  sleep 1
done
if [ "${secondary_ips_per_nic}" -gt 0 ]; then
  aws ec2 assign-private-ip-addresses --region "$region" --network-interface-id "$network_interface_id" --secondary-private-ip-address-count "${secondary_ips_per_nic}"
fi

for (( i=1; i<nics_num; i++ ))
do
  eni=$(aws ec2 create-network-interface --region "$region" --subnet-id "$subnet_id" --groups ${groups}) # groups should not be in quotes it needs to be a list
  network_interface_id=$(echo "$eni" | python3 -c "import sys, json; print(json.load(sys.stdin)['NetworkInterface']['NetworkInterfaceId'])")
  attachment=$(aws ec2 attach-network-interface --region "$region" --device-index "$i" --instance-id "$instance_id" --network-interface-id "$network_interface_id")
  attachment_id=$(echo "$attachment" | python3 -c "import sys, json; print(json.load(sys.stdin)['AttachmentId'])")
  aws ec2 modify-network-interface-attribute --region "$region" --attachment AttachmentId="$attachment_id",DeleteOnTermination=true --network-interface-id "$network_interface_id"
done

aws_version=$(aws --version)
cli_binary_format=""
if [[ "$aws_version" == aws-cli/2* ]]; then
  cli_binary_format="--cli-binary-format raw-in-base64-out"
fi

aws lambda invoke --region "$region" --function-name "${deploy_lambda_name}" $cli_binary_format --payload "{\"name\": \"$instance_id\", \"protocol\": \"${protocol}\"}" output
printf "%b" "$(cat output | sed 's/^"//' | sed 's/"$//' | sed 's/\\\"/"/g')" > /tmp/deploy.sh
chmod +x /tmp/deploy.sh
/tmp/deploy.sh 2>&1 | tee /tmp/weka_deploy.log
