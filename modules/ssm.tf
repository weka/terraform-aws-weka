# Define the SSM Document
resource "aws_ssm_document" "weka_setup_script" {
  name          = "WekaSetupScript"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Run setup commands for Weka on the primary host"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "SetupWeka"
      inputs = {
        runCommand = [
          "sudo amazon-linux-extras install epel -y",
          "sudo yum update -y",
          "sudo yum install git pdsh -y",
          "git clone https://github.com/weka/tools --depth 1",
          "curl -LO https://dNTW8maCGBuuAa0Y@get.weka.io/dist/v1/pkg/weka-4.4.0.tar",
          "tar xvf weka-4.4.0.tar",
          "cd weka-4.4.0 && sudo ./install.sh",
          "export PDSH_SSH_ARGS=\"-i $(pwd|ls *.pem) -o StrictHostKeyChecking=no\"",
          // Run pdsh commands using public-backends.txt and private-backends.txt
          "pdsh -R ssh -l ec2-user -w ^public-backends.txt \"sudo curl -s $(cat public-backends.txt | head -n 1):14000/dist/v1/install | sudo sh\"",
          "pdsh -R ssh -l ec2-user -w ^public-backends.txt \"sudo weka version get 4.4.0\"",
          "pdsh -R ssh -l ec2-user -w ^public-backends.txt \"sudo weka version set 4.4.0\"",
          "pdsh -R ssh -l ec2-user -w ^public-backends.txt \"sudo weka local stop default\"",
          "pdsh -R ssh -l ec2-user -w ^public-backends.txt \"sudo weka local rm default -f\"",
          "while IFS= read -r host || [ -n \"$host\" ]; do rsync -avz -e \"ssh -i $(pwd|ls *.pem)\" ./private-backends.txt ./container-creation.sh ec2-user@$host:/tmp; done < public-backends.txt",
          "pdsh -R ssh -l ec2-user -w ^public-backends.txt \"cd /tmp && sudo /tmp/container-creation.sh\"",
          "weka cluster create $(cat private-backends.txt | xargs)",
          "weka debug config override clusterInfo.nvmeEnabled false",
          "weka cluster hot-spare 1 && weka cluster update --data-drives 4 --parity-drives 2 && weka cluster update --cluster-name (petname)",
          "for i in {0..5}; do weka cluster drive add $i /dev/nvme1n1; done",
          "weka cluster start-io"
        ]
      }
    }]
  })
}

resource "aws_ssm_association" "run_weka_setup" {
  name = "WekaSetupScript"
}
  targets {
    key    = "InstanceIds"
    values = [aws_instance.cst_scenario_test[0].id]  # Run on the first instance only
  }

  parameters = {
    commands = ["sh /home/ec2-user/container-creation.sh"]
  }
