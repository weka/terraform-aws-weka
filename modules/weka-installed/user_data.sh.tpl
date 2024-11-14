#!/bin/bash

cd /root || exit

# Set hostname
sudo hostnamectl set-hostname weka-instance

# Save the PEM key to a file
echo "${private_key_pem}" > /root/${key_name}.pem
chmod 600 /root/${key_name}.pem
chown ec2-user:ec2-user /root/${key_name}.pem

# Install AWS CLI and jq
sudo yum install -y aws-cli jq

# Retrieve the instance's own region
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
echo "Region: $REGION"  # Debugging: Print the region

# Use the full name prefix passed from Terraform
NAME_PREFIX="${NAME_PREFIX}"
WEKA_VERSION="${WEKA_VERSION}"

# Use AWS CLI to describe instances with the specific Name prefix
INSTANCE_INFO=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=${NAME_PREFIX}-*" \
  --query "Reservations[].Instances[].{PrivateIp:PrivateIpAddress, PublicIp:PublicIpAddress}" \
  --output json)

# Use jq to extract only valid private and public IPs
PRIVATE_IPS=$(echo "$INSTANCE_INFO" | jq -r '.[] | select(.PrivateIp != null) | .PrivateIp')
PUBLIC_IPS=$(echo "$INSTANCE_INFO" | jq -r '.[] | select(.PublicIp != null) | .PublicIp')

echo "$PRIVATE_IPS" > /root/private-backends.txt
echo "$PUBLIC_IPS" > /root/public-backends.txt
echo "$NAME_PREFIX" > /root/instance-name.txt
echo "SELF_PRIVATE_IP" > /root/self-ip.txt
echo "$WEKA_VERSION" > /root/weka-version.txt

################################################################################################
################################################################################################
################################################################################################
########################DO NOT CHANGE ABOVE####################################################
################################################################################################
################################################################################################
################################################################################################

for ip in $(cat public-backends.txt); do
  ssh-keyscan -H "$ip" >> ~/.ssh/known_hosts
done

for ip in $(cat private-backends.txt); do
  ssh-keyscan -H "$ip" >> ~/.ssh/known_hosts
done

# Install additional packages and perform Weka setup
sudo amazon-linux-extras install epel -y
sudo yum update -y
sudo yum install git pdsh -y

# Download and extract Weka
curl -LO https://dNTW8maCGBuuAa0Y@get.weka.io/dist/v1/pkg/weka-$(cat weka-version.txt).tar
tar xvf weka-$(cat weka-version.txt).tar
cd weka-$(cat weka-version.txt)
sudo ./install.sh
cd ..

# Set PDSH SSH arguments
export PDSH_SSH_ARGS="-i $(\pwd|ls *.pem) -o StrictHostKeyChecking=no"

# Install Weka on backend nodes

pdsh -R ssh -l ec2-user -w ^public-backends.txt "sudo curl -s http://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):14000/dist/v1/install | sudo sh"

# Set and configure Weka version
pdsh -R ssh -l ec2-user -w ^public-backends.txt "sudo weka version get $(cat weka-version.txt)"
pdsh -R ssh -l ec2-user -w ^public-backends.txt "sudo weka version set $(cat weka-version.txt)"

# Stop and remove the default Weka setup
pdsh -R ssh -l ec2-user -w ^public-backends.txt "sudo weka local stop default"
pdsh -R ssh -l ec2-user -w ^public-backends.txt "sudo weka local rm default -f"

# Download the container-creation script from S3
aws s3 cp s3://cst-scenario-lab/weka-installation/container-creation.sh .

# Copy files to backend nodes
while IFS= read -r host || [ -n "$host" ]; do
  rsync -avz -e "ssh -i $(\pwd|ls *.pem)" ./private-backends.txt ./container-creation.sh ec2-user@$host:/tmp
done < public-backends.txt

# Run the container creation script on backend nodes
pdsh -R ssh -l ec2-user -w ^public-backends.txt "cd /tmp && sudo chmod +x container-creation.sh && sudo /tmp/container-creation.sh"

# Create and configure the Weka cluster
weka cluster create $(\cat private-backends.txt|xargs)
sleep 10
weka debug config override clusterInfo.nvmeEnabled false
weka cluster hot-spare 1 && weka cluster update --data-drives 4 --parity-drives 2 && weka cluster update --cluster-name $(cat instance-name.txt)

# Add drives to Weka cluster and start IO
for i in {0..5}; do weka cluster drive add $i /dev/nvme1n1; done
weka cluster start-io

sleep 10

# Check Weka status
WEKA_STATUS=$(weka status)
echo "$WEKA_STATUS"

# Verify if the status is "OK"
if echo "$WEKA_STATUS" | grep -q "status: OK"; then
  echo "Weka setup completed successfully!"
  exit 0
else
  echo "Weka setup failed. Status not OK."
  exit 1
fi
