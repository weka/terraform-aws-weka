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

    no_proxy=".amazonaws.com" https_proxy="${proxy}" yum install -y amazon-cloudwatch-agent.x86_64 || return 1
    configure_aws_logs_agent || return 1
    service amazon-cloudwatch-agent restart || return 1
}

setup_aws_logs_agent || echo "Failed to setup AWS logs agent"

yum install -y jq

${custom_data}

region=${region}
subnet_id=${subnet_id}
nics_num=${nics_num}

# AWS retry settings (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-retries.html)
export AWS_MAX_ATTEMPTS=150
export AWS_RETRY_MODE=standard

for (( i=1; i<nics_num; i++ ))
do
  eni=$(aws ec2 create-network-interface --region "$region" --subnet-id "$subnet_id" --groups ${groups}) # groups should not be in quotes it needs to be a list
  network_interface_id=$(echo "$eni" | python3 -c "import sys, json; print(json.load(sys.stdin)['NetworkInterface']['NetworkInterfaceId'])")
  attachment=$(aws ec2 attach-network-interface --region "$region" --device-index "$i" --instance-id "$instance_id" --network-interface-id "$network_interface_id")
  attachment_id=$(echo "$attachment" | python3 -c "import sys, json; print(json.load(sys.stdin)['AttachmentId'])")
  aws ec2 modify-network-interface-attribute --region "$region" --attachment AttachmentId="$attachment_id",DeleteOnTermination=true --network-interface-id "$network_interface_id"
done

aws lambda invoke --region "$region" --function-name "${deploy_lambda_name}" --payload "{\"name\": \"$instance_id\"}" output
printf "%b" "$(cat output | sed 's/^"//' | sed 's/"$//' | sed 's/\\\"/"/g')" > /tmp/deploy.sh
chmod +x /tmp/deploy.sh
/tmp/deploy.sh 2>&1 | tee /tmp/weka_deploy.log
