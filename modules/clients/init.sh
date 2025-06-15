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
    https_proxy="${proxy_url}"
EOF
}

# From http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/EC2NewInstanceCWL.html
function setup_aws_logs_agent() {
    echo "---------------------------"
    echo " Setting up AWS logs agent "
    echo "---------------------------"

    no_proxy=".amazonaws.com" https_proxy="${proxy_url}" yum install -y amazon-cloudwatch-agent || no_proxy=".amazonaws.com" https_proxy="${proxy_url}" apt install -y amazon-cloudwatch-agent || return 1
    configure_aws_logs_agent || return 1
    service amazon-cloudwatch-agent restart || return 1
}

setup_aws_logs_agent || echo "Failed to setup AWS logs agent"

${custom_data}
