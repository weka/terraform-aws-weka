# terraform-aws-weka
AWS terraform weka deployment module.
<br>Applying this terraform module will create the following resources:
- **DynamoDB** table (stores the the weka cluster state default KMS key)
- **Lambda**:
    - *deploy* - responsible for providing new machines installation script
    - *clusterize* - responsible for providing clusterize script
    - *clusterize-finalization* - responsible for updating the cluster state about clusterization completion
    - *report* - responsible for updating the state about clusterization and new machines installation progress
    - *status* - responsible for providing the cluster progress status

    - for State Machine:
        - *fetch* - fetches cluster/autoscaling group information and passes to the next stage
        - *scale-down* - relied on *fetch* information to work on the Weka cluster, i.e., deactivate drives/hosts. Will fail if the required target is not supported (like scaling down to 2 backend instances)
        - *terminate* - terminates deactivated hosts
        - *transient* - lambda responsible for reporting transient errors, e.g., could not deactivate specific hosts, but some have been deactivated, and the whole flow proceeded

- **Launch Template**: used for new auto-scaling group instances; will run the deploy script on launch.
- **Ec2 instances**
- **Placement Group**
- **Auto Scaling Group**
- **ALB** (optional for UI and Backends)
- **State Machine**: invokes the *fetch*, *scale-down*, *terminate*, *transient*
    - Uses the previous lambda output as input for the following lambda.
    - **CloudWatch**: invokes the state machine every minute
- **SecretManager** (stores the weka user name, password and get.weka.io token)
- **IAM Roles (and policies)**:

## Weka deployment prerequisites:
- vpc (with secret manager endpoint)
- subnet (optional: additional_alb_subnet for ALB)
- security group (with self reference rule)
- iam roles
    <details>
    <summary>Ec2 iam policy (replace *prefix* and *cluster_name* with relevant values)</summary>

    ```json
    {
        "Statement": [
        {
            "Action": [
                "ec2:DescribeNetworkInterfaces",
                "ec2:AttachNetworkInterface",
                "ec2:CreateNetworkInterface",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:DeleteNetworkInterface"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:lambda:*:*:function:prefix-cluster_name*"
            ]
        },
        {
            "Action": [
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObject"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::prefix-cluster_name-obs/*"
            ]
        },
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams",
                "logs:PutRetentionPolicy"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:logs:*:*:log-group:/wekaio/prefix-cluster_name*"
            ]
        }
        ],
        "Version": "2012-10-17"
    }
    ```
    </details>
    <details>
    <summary>Lambda iam policy (replace *prefix* and *cluster_name* with relevant values)</summary>

    ```json
    {
        "Statement": [
        {
            "Action": [
              "s3:CreateBucket"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::prefix-cluster_name-obs"
            ]
        },
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:logs:*:*:log-group:/aws/lambda/prefix-cluster_name*:*"
            ]
        },
        {
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface",
                "ec2:ModifyInstanceAttribute",
                "ec2:TerminateInstances",
                "ec2:DescribeInstances"
            ],
            "Effect": "Allow",
            "Resource": [
              "*"
            ]
        },
        {
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:UpdateItem"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:dynamodb:*:*:table/prefix-cluster_name-weka-deployment"
            ]
        },
        {
            "Action": [
              "secretsmanager:GetSecretValue"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:secretsmanager:*:*:secret:weka/prefix-cluster_name/*"
            ]
        },
        {
            "Action": [
                "autoscaling:DetachInstances",
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:SetInstanceProtection"
            ],
            "Effect": "Allow",
            "Resource": [
              "*"
            ]
        }
        ],
        "Version": "2012-10-17"
        }
    ```
    </details>
    <details>
    <summary>State Machine iam policy (replace *prefix* and *cluster_name* with relevant values)</summary>

    ```json
    {
      "Statement": [
        {
          "Action": [
            "lambda:InvokeFunction"
          ],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:lambda:*:*:function:prefix-cluster_name-*-lambda"
          ]
        },
        {
          "Action": [
            "logs:CreateLogDelivery",
            "logs:GetLogDelivery",
            "logs:UpdateLogDelivery",
            "logs:DeleteLogDelivery",
            "logs:ListLogDeliveries",
            "logs:PutLogEvents",
            "logs:PutResourcePolicy",
            "logs:DescribeResourcePolicies",
            "logs:DescribeLogGroups"
          ],
          "Effect": "Allow",
          "Resource": [
            "*"
          ]
        }
      ],
      "Version": "2012-10-17"
    }
    ```
    </details>
    <details>
    <summary>Cloud Watch Events iam policy (replace *prefix* and *cluster_name* with relevant values)</summary>

    ```json
    {
      "Statement": [
        {
          "Action": [
            "states:StartExecution"
          ],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:states:*:*:stateMachine:prefix-cluster_name-scale-down-state-machine"
          ]
        }
      ],
      "Version": "2012-10-17"
    }
    ```
    </details>
## Usage example:
This example will automatically create a vpc, subnets, security group and iam roles.
```hcl
provider "aws" {
}

module "deploy_weka" {
  source                            = "weka/weka/aws"
  version                           = "1.0.1"
  prefix                            = "weka-tf"
  cluster_name                      = "test"
  allow_ssh_cidrs                   = ["0.0.0.0/0"]
  get_weka_io_token                 = "..."
}

output "deploy_weka_output" {
  value = module.deploy_weka
}
```
### Using existing vpc:
```hcl
vpc_id                            = "..."
```
### Using existing subnet:
```hcl
subnet_ids                        = ["..."]
```
### Using existing security groups:
```hcl
sg_ids                            = ["..."]
```
### Using existing iam roles:
```hcl
instance_iam_profile_arn          = "..."
lambda_iam_role_arn               = "..."
sfn_iam_role_arn                  = "..."
event_iam_role_arn                = "..."
```

## Helper modules
We provide iam, network and security_group modules to help you create the prerequisites for the weka deployment.
<br>Check our [example](examples/public_network/main.tf) that uses these modules.
- When sg_ids isn't provided we automatically create a security group using our module.
- When subnet_ids isn't provided we automatically create a subnet using our module.
- When instance_iam_profile_arn isn't provided we automatically create an iam instance profile using our module.
- var `availability_zones` need to provide only when we create network module, Currently limited to single subnet. for example `eu-west-1c`

### NAT network deployment:
we provide module for creating private network with NAT
To create private vpc with NAT, you must provide the following variables:
```hcl
create_nat_gateway      = true
nat_public_subnet_cidr = PUBLIC_CIDR_RANGE
```
### Private network deployment:
we provide module for creating private network with NO internet access
To create private vpc, you must provide the following variables:
```hcl
subnet_autocreate_as_private = true
```

#### To avoid public ip assignment:
```hcl
assign_public_ip   = false
```

## Ssh keys
The username for ssh into vms is `ec2-user`.
If `ami_id` is provided by the user, the default ssh username will be accordingly.
<br />

We allow passing existing key pair name:
```hcl
key_pair_name = "..."
```
We allow passing an existing public key string to create new key pair:
```hcl
ssh_public_key = "..."
```
If key pair name and public key aren't passed we will create it for you and store the private key locally under `/tmp`
Names will be:
```
/tmp/${prefix}-${cluster_name}-public-key.pub
/tmp/${prefix}-${cluster_name}-private-key.pem
```

To disable using key pair need to set:
```hcl
enable_key_pair = false
```

To pass any custom data to init script, for example to install SSM need to set:
```hcl
custom_data = "sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm\n sudo systemctl start amazon-ssm-agent"
```

## Create ALB
We support ALB creation for backend UI, and joining weka clients will use this ALB to join a cluster, allowing for better distribution of load amongst backends.
mandatory variables you must provide are:
```hcl
create_alb                       = true
alb_additional_subnet_cidr_block = ADDITIONAL_SUBNET_CIDR_BLOCK
```
To use existing additional subnet, you must supply the following variables:
```hcl
additional_alb_subnet_id = SUBNET_ID
alb_sg_ids               = ALB_SG_IDS
```
To add ALB dns name to zone record, you must supply the following variables:
```hcl
alb_alias_name      = ALB_ALIAS_NAME
alb_route53_zone_id = ROUTE53_ZONE_ID
```
TO create alb listener with `certificate ARN`, you must supply the following variable:
```hcl
alb_cert_arn = ALB_CERT_ARN
```

## OBS
We support tiering to s3.
In order to setup tiering, you must supply the following variables:
```hcl
tiering_enable_obs_integration = true
tiering_obs_name               = "..."
```
In addition, you can supply (and override our default):
```hcl
tiering_ssd_percent = VALUE
```
## Clients
### prerequisites:
- client_instance_iam_profile_arn
<details>
<summary>Clients iam policy (replace *prefix* and *cluster_name* with relevant values)</summary>

```json
{
    "Statement": [
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups"
            ],
            "Effect": "Allow",
            "Resource": [
                "*"
            ]
        },
      {
        "Action": [
          "ec2:DescribeNetworkInterfaces",
          "ec2:AttachNetworkInterface",
          "ec2:CreateNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeInstances"
        ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy"
        ],
        "Effect": "Allow",
        "Resource": [
          "arn:aws:logs:*:*:log-group:/wekaio/clients/prefix-cluster_name-client*"
        ]
      }
    ],
    "Version": "2012-10-17"
}
```
</details>

We support creating clients that will be mounted automatically to the cluster.
<br>In order to create clients you need to provide the number of clients you want (by default the number is 0),
for example:
```hcl
clients_number = 2
```
This will automatically create 2 clients.
<br>In addition you can provide these optional variables:
```hcl
client_instance_type   = "c5.2xlarge"
client_nics_num        = DESIRED_NUM
client_instance_ami_id = AMI_ID
client_arch            = "x86_64"
```

<br>In order to use exising iam instance profile ARN you need to provide the following variable:
```
client_instance_iam_profile_arn = CLIENT_ARN
```

## NFS Protocol Gateways
We support creating protocol gateways that will be mounted automatically to the cluster.
<br>In order to create you need to provide the number of protocol gateways instances you want (by default the number is 0),
for example:
```hcl
nfs_protocol_gateways_number = 2
```
This will automatically create 2 instances.
<br>In addition you can supply these optional variables:
```hcl
nfs_protocol_gateway_secondary_ips_per_nic    = 3
nfs_protocol_gateway_instance_type            = "c5.2xlarge"
nfs_protocol_gateway_nics_num                 = 2
nfs_protocol_gateway_disk_size                = 48
nfs_protocol_gateway_fe_cores_num             = 1
nfs_protocol_gateway_instance_iam_profile_arn = ""
```

<br>In order to create stateless clients, need to set variable:
```hcl
nfs_setup_protocol = true
```

### prerequisites:
- protocol_gateway_instance_iam_profile_arn
<details>
<summary>Protocol gateway iam policy (replace *prefix*, *cluster_name* and *gateways_name* with relevant values)</summary>

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action":
    [
      "ec2:DescribeNetworkInterfaces",
      "ec2:AttachNetworkInterface",
      "ec2:CreateNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances"
    ]
    "Resource":  "*",
    },
    {
      "Effect": "Allow",
      "Action":
    [
      "secretsmanager:GetSecretValue"
    ]
    "Resource":
    [
      "arn:aws:secretsmanager:*:*:secret:weka/prefix-cluster_name/*"
    ]
    },
    {
      "Effect": "Allow",
      "Action":
    [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy"
    ]
    "Resource":
    [
      "arn:aws:logs:*:*:log-group:/wekaio/clients/gateways_name*"
    ]
    },
    {
      "Effect": "Allow",
      "Action":
    [
      "autoscaling:DescribeAutoScalingGroups"
    ],
    "Resource":
    [
      "*"
    ]
    }
  ]
}

```
</details>

## S3 Protocol Gateways
We support creating protocol gateways that will be mounted automatically to the cluster.
<br>In order to create you need to provide the number of protocol gateways instances you want (by default the number is 0),

for example:
```hcl
s3_protocol_gateways_number = 2
```
This will automatically create 2 instances.
<br>In addition you can supply these optional variables:
```hcl
s3_protocol_gateway_instance_type            = "c5.2xlarge"
s3_protocol_gateway_disk_size                = 48
s3_protocol_gateway_fe_cores_num             = 1
s3_protocol_gateway_instance_iam_profile_arn = "<YOUR ARN>"
```

## SMB Protocol Gateways
We support creating protocol gateways that will be mounted automatically to the cluster.
<br>In order to create you need to provide the number of protocol gateways instances you want (by default the number is 0),

*The amount of SMB protocol gateways should be at least 3.*
</br>
for example:
```hcl
smb_protocol_gateways_number = 3
```
This will automatically create 2 instances.
<br>In addition you can supply these optional variables:
```hcl
smb_protocol_gateway_secondary_ips_per_nic    = 3
smb_protocol_gateway_instance_type            = "c5.2xlarge"
smb_protocol_gateway_nics_num                 = 2
smb_protocol_gateway_disk_size                = 48
smb_protocol_gateway_fe_cores_num             = 1
smb_protocol_gateway_instance_iam_profile_arn = ""
smb_cluster_name                              = ""
smb_domain_name                               = ""
```

<br>In order to create stateless clients, need to set variable:
```hcl
smb_setup_protocol = true
```

<br>In order to enable SMBW, need to set variable:
```hcl
smbw_enabled = true
```

To join an SMB cluster in Active Directory, need to run manually command:

`weka smb domain join <smb_domain_username> <smb_domain_password> [--server smb_server_name]`.


### prerequisites:
- protocol_gateway_instance_iam_profile_arn
<details>
<summary>Protocol gateway iam policy (replace *prefix*, *cluster_name* and *gateways_name* with relevant values)</summary>

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action":
    [
      "ec2:DescribeNetworkInterfaces",
      "ec2:AttachNetworkInterface",
      "ec2:CreateNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances"
    ]
    "Resource":  "*",
    },
    {
      "Effect": "Allow",
      "Action":
    [
      "secretsmanager:GetSecretValue"
    ]
    "Resource":
    [
      "arn:aws:secretsmanager:*:*:secret:weka/prefix-cluster_name/*"
    ]
    },
    {
      "Effect": "Allow",
      "Action":
    [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy"
    ]
    "Resource":
    [
      "arn:aws:logs:*:*:log-group:/wekaio/clients/gateways_name*"
    ]
    },
    {
      "Effect": "Allow",
      "Action":
    [
      "autoscaling:DescribeAutoScalingGroups"
    ],
    "Resource":
    [
      "*"
    ]
    }
  ]
}
```
</details>

## Secret manager
By default, if not provided explicitly to the module, we will set:
```hcl
secretmanager_use_vpc_endpoint = true
secretmanager_create_vpc_endpoint = true
```
This means we will create a secretmanager endpoint and will use it in the scale down lambda function.
<br>If a secretmanager endpoint already exists, then set:
```hcl
secretmanager_create_vpc_endpoint = false
```
It is possible to not use the secretmanager endpoint, but not recommended.
<br>To not use the secretmanager endpoint, set:
```hcl
secretmanager_use_vpc_endpoint = false
secretmanager_create_vpc_endpoint = false
```

### Run lambdas inside vpc:
To enable vpc config for lambdas, set:
```hcl
enable_lambda_vpc_config = true
```

If network VPC is not configured with a NAT gateway, the following needs to be set:
```hcl
vpc_endpoint_ec2_create              = true
vpc_endpoint_lambda_create           = true
vpc_endpoint_dynamodb_gateway_create = true
vpc_endpoint_autoscaling_create      = true
```



#### Further explanation:
We use the secret manager to store the weka username, password (and get.weka.io token).
<br>We need to be able to use them on `scale down` lambda which runs inside the provided vpc.
<br>This is the reason we need the secret manager endpoint on the vpc.
<br>In case setting secret manager endpoint isn't possible, you will need to set the variables as described above.
<br> In this case the weka password will be shown as plain text on the state machine, since it will need to be sent
from the fetch lambda to the scale down lambda.


# Endpoints
In case you want to deploy a weka cluster inside a vpc with no internet access, you will need to set the following endpoints:
## vpc endpoint proxy
We need an endpoint to reach home.weka.io, get.weka.io, and AWS EC2/cloudwatch services.
<br>To use weka vpc endpoint service, set:
```hcl
vpc_endpoint_proxy_create = true
```
Alternatively appropriate customer-managed proxy can be provided by `proxy_url` variable:
```hcl
proxy_url = "..."
```

## vpc endpoint ec2
Weka deployment requires access to EC2 services.
<br>To let terraform create ec2 endpoint, set:
```hcl
vpc_endpoint_ec2_create = true
```
## vpc endpoint s3 gateway
Weka deployment requires access to S3 services.
<br>To let terraform create s3 gateway, set:
```hcl
vpc_endpoint_s3_gateway_create = true
```
## vpc endpoint lambda
Weka deployment requires access to lambda services.
<br>To let terraform create lambda endpoint, set:
```hcl
vpc_endpoint_s3_gateway_create = true
```

# Terraform output
The module output contains useful information about the created resources.
For example: ssh username, weka password secret id etc.
The `helper_commands` part in the output provides lambda call that can be used to learn about the clusterization process.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.5.0 |
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.5.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | >= 4.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_clients"></a> [clients](#module\_clients) | ./modules/clients | n/a |
| <a name="module_iam"></a> [iam](#module\_iam) | ./modules/iam | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_nfs_protocol_gateways"></a> [nfs\_protocol\_gateways](#module\_nfs\_protocol\_gateways) | ./modules/protocol_gateways | n/a |
| <a name="module_s3_protocol_gateways"></a> [s3\_protocol\_gateways](#module\_s3\_protocol\_gateways) | ./modules/protocol_gateways | n/a |
| <a name="module_security_group"></a> [security\_group](#module\_security\_group) | ./modules/security_group | n/a |
| <a name="module_smb_protocol_gateways"></a> [smb\_protocol\_gateways](#module\_smb\_protocol\_gateways) | ./modules/protocol_gateways | n/a |
| <a name="module_vpc_endpoint"></a> [vpc\_endpoint](#module\_vpc\_endpoint) | ./modules/endpoint | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_attachment.alb_autoscaling_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment) | resource |
| [aws_autoscaling_group.autoscaling_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_event_rule.event_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.step_function_event_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.cloudwatch_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.sfn_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.weka_deployment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table_item.weka_deployment_nfs_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_dynamodb_table_item.weka_deployment_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_key_pair.generated_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_kms_alias.kms_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.kms_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_lambda_function.clusterize_finalization_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.clusterize_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.deploy_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.fetch_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.join_nfs_finalization_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.report_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.scale_down_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.status_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.terminate_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.transient_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.invoke_lambda_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_launch_template.launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.lb_weka_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_placement_group.placement_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/placement_group) | resource |
| [aws_route53_record.lb_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_secretsmanager_secret.get_weka_io_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.weka_deployment_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.weka_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.weka_username](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.get_weka_io_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.weka_username](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_sfn_state_machine.scale_down_state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [aws_vpc_endpoint.secretmanager_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [random_password.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [tls_private_key.key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [aws_ami.amzn_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_instance_iam_policy_statement"></a> [additional\_instance\_iam\_policy\_statement](#input\_additional\_instance\_iam\_policy\_statement) | Additional IAM policy statement to be added to the instance IAM role. | <pre>list(object({<br>    Effect   = string<br>    Action   = list(string)<br>    Resource = list(string)<br>  }))</pre> | `null` | no |
| <a name="input_alb_additional_subnet_cidr_block"></a> [alb\_additional\_subnet\_cidr\_block](#input\_alb\_additional\_subnet\_cidr\_block) | Additional CIDR block for public subnet | `string` | `"10.0.3.0/24"` | no |
| <a name="input_alb_additional_subnet_id"></a> [alb\_additional\_subnet\_id](#input\_alb\_additional\_subnet\_id) | Required to specify if subnet\_ids were used to specify pre-defined subnets for weka. ALB requires an additional subnet, and in the case of pre-defined networking this one also should be pre-defined | `string` | `""` | no |
| <a name="input_alb_additional_subnet_zone"></a> [alb\_additional\_subnet\_zone](#input\_alb\_additional\_subnet\_zone) | Zone for the ALB additional subnet | `string` | `""` | no |
| <a name="input_alb_alias_name"></a> [alb\_alias\_name](#input\_alb\_alias\_name) | Set ALB alias name | `string` | `""` | no |
| <a name="input_alb_allow_https_cidrs"></a> [alb\_allow\_https\_cidrs](#input\_alb\_allow\_https\_cidrs) | CIDRs to allow connecting to ALB over 443 port, by default 443 is not opened, and port 14000 used for connection, inheriting setting from  allow\_weka\_api\_ranges | `list(string)` | `[]` | no |
| <a name="input_alb_cert_arn"></a> [alb\_cert\_arn](#input\_alb\_cert\_arn) | HTTPS certificate ARN for ALB | `string` | `null` | no |
| <a name="input_alb_route53_zone_id"></a> [alb\_route53\_zone\_id](#input\_alb\_route53\_zone\_id) | Route53 zone id | `string` | `""` | no |
| <a name="input_alb_sg_ids"></a> [alb\_sg\_ids](#input\_alb\_sg\_ids) | Security group ids for ALB | `list(string)` | `[]` | no |
| <a name="input_allow_ssh_cidrs"></a> [allow\_ssh\_cidrs](#input\_allow\_ssh\_cidrs) | Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_allow_weka_api_cidrs"></a> [allow\_weka\_api\_cidrs](#input\_allow\_weka\_api\_cidrs) | Allow connection to port 14000 on weka backends and ALB(if exists and not provided with dedicated SG)  from specified CIDRs, by default no CIDRs are allowed. All ports (including 14000) are allowed within VPC | `list(string)` | `[]` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID to use, Amazon Linux 2 is the supported OS. | `string` | `null` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public IP to all instances deployed by TF module. Includes backends, clients and protocol gateways | `string` | `"auto"` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Required only if not specifying subnet\_ids, this zone(s) will be used to create subnet that will be used by weka. Currently limited to single subnet | `list(string)` | `[]` | no |
| <a name="input_backends_weka_volume_size"></a> [backends\_weka\_volume\_size](#input\_backends\_weka\_volume\_size) | The backends' default disk size. | `number` | `48` | no |
| <a name="input_capacity_reservation_id"></a> [capacity\_reservation\_id](#input\_capacity\_reservation\_id) | The ID of the Capacity Reservation in which to run the backends | `string` | `null` | no |
| <a name="input_client_arch"></a> [client\_arch](#input\_client\_arch) | Use arch for ami id, value can be arm64/amd64. | `string` | `null` | no |
| <a name="input_client_capacity_reservation_id"></a> [client\_capacity\_reservation\_id](#input\_client\_capacity\_reservation\_id) | The ID of the capacity reservation in which to run the clients | `string` | `null` | no |
| <a name="input_client_frontend_cores"></a> [client\_frontend\_cores](#input\_client\_frontend\_cores) | Number of frontend cores to use on client instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC | `number` | `1` | no |
| <a name="input_client_instance_ami_id"></a> [client\_instance\_ami\_id](#input\_client\_instance\_ami\_id) | The default AMI ID is set to Amazon Linux 2. For the list of all supported Weka Client OSs please refer to: https://docs.weka.io/planning-and-installation/prerequisites-and-compatibility#operating-system | `string` | `null` | no |
| <a name="input_client_instance_iam_profile_arn"></a> [client\_instance\_iam\_profile\_arn](#input\_client\_instance\_iam\_profile\_arn) | ARN of IAM Instance Profile to use by client instance. If not specified Instance Profile will be automatically created | `string` | `""` | no |
| <a name="input_client_instance_type"></a> [client\_instance\_type](#input\_client\_instance\_type) | The client instance type (sku) to deploy | `string` | `"c5.2xlarge"` | no |
| <a name="input_client_placement_group_name"></a> [client\_placement\_group\_name](#input\_client\_placement\_group\_name) | The client instances placement group name. Backend placement group can be reused. If not specified placement group will be created automatically | `string` | `null` | no |
| <a name="input_client_root_volume_size"></a> [client\_root\_volume\_size](#input\_client\_root\_volume\_size) | The client volume size in GB | `number` | `8` | no |
| <a name="input_client_use_backends_placement_group"></a> [client\_use\_backends\_placement\_group](#input\_client\_use\_backends\_placement\_group) | Use backends placement group for clients | `bool` | `true` | no |
| <a name="input_clients_custom_data"></a> [clients\_custom\_data](#input\_clients\_custom\_data) | Custom data to pass to the client instances | `string` | `""` | no |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | The number of client instances to deploy | `number` | `0` | no |
| <a name="input_clients_use_autoscaling_group"></a> [clients\_use\_autoscaling\_group](#input\_clients\_use\_autoscaling\_group) | Use autoscaling group for clients | `bool` | `false` | no |
| <a name="input_clients_use_dpdk"></a> [clients\_use\_dpdk](#input\_clients\_use\_dpdk) | Mount weka clients in DPDK mode | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The cluster name. | `string` | `"poc"` | no |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | The number of virtual machines to deploy. | `number` | `6` | no |
| <a name="input_containers_config_map"></a> [containers\_config\_map](#input\_containers\_config\_map) | Maps the number of objects and memory size per machine type. | <pre>map(object({<br>    compute  = number<br>    drive    = number<br>    frontend = number<br>    nvme     = number<br>    nics     = number<br>    memory   = list(string)<br>  }))</pre> | <pre>{<br>  "i3en.12xlarge": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": [<br>      "310.7GB",<br>      "310.4GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 4<br>  },<br>  "i3en.24xlarge": {<br>    "compute": 9,<br>    "drive": 4,<br>    "frontend": 1,<br>    "memory": [<br>      "384GB",<br>      "384GB"<br>    ],<br>    "nics": 15,<br>    "nvme": 8<br>  },<br>  "i3en.2xlarge": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "32.9GB",<br>      "32.64GB"<br>    ],<br>    "nics": 4,<br>    "nvme": 2<br>  },<br>  "i3en.3xlarge": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "62GB",<br>      "61.7GB"<br>    ],<br>    "nics": 4,<br>    "nvme": 1<br>  },<br>  "i3en.6xlarge": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": [<br>      "136.5GB",<br>      "136.2GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 2<br>  }<br>}</pre> | no |
| <a name="input_create_alb"></a> [create\_alb](#input\_create\_alb) | Create ALB for backend UI, and joining weka clients will use this ALB to join a cluster, allowing for better distribution of load amongst backends | `bool` | `true` | no |
| <a name="input_create_nat_gateway"></a> [create\_nat\_gateway](#input\_create\_nat\_gateway) | NAT needs to be created when no public ip is assigned to the backend, to allow internet access | `bool` | `false` | no |
| <a name="input_custom_data"></a> [custom\_data](#input\_custom\_data) | Custom data to pass to instances. | `string` | `""` | no |
| <a name="input_debug_down_backends_removal_timeout"></a> [debug\_down\_backends\_removal\_timeout](#input\_debug\_down\_backends\_removal\_timeout) | Don't change this value without consulting weka support team. Timeout for removing down backends. Valid time units are ns, us (or µs), ms, s, m, h. | `string` | `"3h"` | no |
| <a name="input_dynamodb_hash_key_name"></a> [dynamodb\_hash\_key\_name](#input\_dynamodb\_hash\_key\_name) | DynamoDB hash key name (optional configuration, will use 'Key' by default). This key will be used if dynamodb table will be created automatically, by not setting `dynamodb_table_name` param. In case `dynamodb_table_name` parameter is set, `dynamodb_hash_key_name` should match the key that should be used by us within pre-created table | `string` | `"Key"` | no |
| <a name="input_dynamodb_table_name"></a> [dynamodb\_table\_name](#input\_dynamodb\_table\_name) | DynamoDB table name, if not supplied a new table will be created | `string` | `""` | no |
| <a name="input_ebs_encrypted"></a> [ebs\_encrypted](#input\_ebs\_encrypted) | Enables EBS encryption on the volume | `bool` | `false` | no |
| <a name="input_ebs_kms_key_id"></a> [ebs\_kms\_key\_id](#input\_ebs\_kms\_key\_id) | The ARN of the AWS Key Management Service | `string` | `null` | no |
| <a name="input_enable_key_pair"></a> [enable\_key\_pair](#input\_enable\_key\_pair) | create / use key pair for instance template | `bool` | `true` | no |
| <a name="input_enable_lambda_vpc_config"></a> [enable\_lambda\_vpc\_config](#input\_enable\_lambda\_vpc\_config) | Config lambda to run inside vpc | `bool` | `false` | no |
| <a name="input_event_iam_role_arn"></a> [event\_iam\_role\_arn](#input\_event\_iam\_role\_arn) | IAM Role that will be used by cloudwatch rule(event), if not specified will be created automatically. If pre-created should match policy described in readme | `string` | `""` | no |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | The token to download the Weka release from get.weka.io. | `string` | n/a | yes |
| <a name="input_get_weka_io_token_secret_id"></a> [get\_weka\_io\_token\_secret\_id](#input\_get\_weka\_io\_token\_secret\_id) | The secrets manager secret id of the token to download the Weka release from get.weka.io. i.e. arn:aws:secretsmanager:<REGION>:<ACCOUNT\_NUMBER>:secret:<SECRET\_NAME> | `string` | `""` | no |
| <a name="input_hotspare"></a> [hotspare](#input\_hotspare) | Number of hotspares to set on weka cluster. Refer to https://docs.weka.io/overview/ssd-capacity-management#hot-spare | `number` | `1` | no |
| <a name="input_install_cluster_dpdk"></a> [install\_cluster\_dpdk](#input\_install\_cluster\_dpdk) | Install weka cluster with DPDK | `bool` | `true` | no |
| <a name="input_install_weka_url"></a> [install\_weka\_url](#input\_install\_weka\_url) | The URL of the Weka release. Supports path to weka tar file or installation script. | `string` | `""` | no |
| <a name="input_instance_iam_profile_arn"></a> [instance\_iam\_profile\_arn](#input\_instance\_iam\_profile\_arn) | ARN of IAM Instance Profile that will be used by weka backend instances, if not specified will be created automatically. If pre-created should match policy described in readme | `string` | `""` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The virtual machine type (sku) to deploy. | `string` | `"i3en.2xlarge"` | no |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | Ssh key pair name to pass to the instances. | `string` | `null` | no |
| <a name="input_lambda_iam_role_arn"></a> [lambda\_iam\_role\_arn](#input\_lambda\_iam\_role\_arn) | IAM Role that will be used by AWS Lambdas, if not specified will be created automatically. If pre-created should match policy described in readme | `string` | `""` | no |
| <a name="input_lambdas_dist"></a> [lambdas\_dist](#input\_lambdas\_dist) | Lambdas code dist | `string` | `"dev"` | no |
| <a name="input_lambdas_version"></a> [lambdas\_version](#input\_lambdas\_version) | Lambdas code version (hash) | `string` | `"87a1d3c485d6429bf993d74808b71a2a"` | no |
| <a name="input_metadata_http_tokens"></a> [metadata\_http\_tokens](#input\_metadata\_http\_tokens) | Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2 (IMDSv2) | `string` | `"required"` | no |
| <a name="input_nat_public_subnet_cidr"></a> [nat\_public\_subnet\_cidr](#input\_nat\_public\_subnet\_cidr) | CIDR block for public subnet | `string` | `"10.0.2.0/24"` | no |
| <a name="input_nfs_capacity_reservation_id"></a> [nfs\_capacity\_reservation\_id](#input\_nfs\_capacity\_reservation\_id) | The ID of the capacity reservation in which to run the nfs clients | `string` | `null` | no |
| <a name="input_nfs_interface_group_name"></a> [nfs\_interface\_group\_name](#input\_nfs\_interface\_group\_name) | Interface group name. | `string` | `"weka-ig"` | no |
| <a name="input_nfs_protocol_gateway_fe_cores_num"></a> [nfs\_protocol\_gateway\_fe\_cores\_num](#input\_nfs\_protocol\_gateway\_fe\_cores\_num) | The protocol gateways' NICs number. | `number` | `1` | no |
| <a name="input_nfs_protocol_gateway_instance_iam_profile_arn"></a> [nfs\_protocol\_gateway\_instance\_iam\_profile\_arn](#input\_nfs\_protocol\_gateway\_instance\_iam\_profile\_arn) | The protocol gateway instance IAM profile ARN | `string` | `""` | no |
| <a name="input_nfs_protocol_gateway_instance_type"></a> [nfs\_protocol\_gateway\_instance\_type](#input\_nfs\_protocol\_gateway\_instance\_type) | The protocol gateways' virtual machine type (sku) to deploy. | `string` | `"c5n.2xlarge"` | no |
| <a name="input_nfs_protocol_gateway_secondary_ips_per_nic"></a> [nfs\_protocol\_gateway\_secondary\_ips\_per\_nic](#input\_nfs\_protocol\_gateway\_secondary\_ips\_per\_nic) | Number of secondary IPs per single NIC per protocol gateway virtual machine. | `number` | `3` | no |
| <a name="input_nfs_protocol_gateway_weka_volume_size"></a> [nfs\_protocol\_gateway\_weka\_volume\_size](#input\_nfs\_protocol\_gateway\_weka\_volume\_size) | The protocol gateways' default disk size. | `number` | `48` | no |
| <a name="input_nfs_protocol_gateways_number"></a> [nfs\_protocol\_gateways\_number](#input\_nfs\_protocol\_gateways\_number) | The number of protocol gateway virtual machines to deploy. | `number` | `0` | no |
| <a name="input_nfs_setup_protocol"></a> [nfs\_setup\_protocol](#input\_nfs\_setup\_protocol) | Setup protocol, default if false | `bool` | `false` | no |
| <a name="input_placement_group_name"></a> [placement\_group\_name](#input\_placement\_group\_name) | n/a | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | `"weka"` | no |
| <a name="input_protection_level"></a> [protection\_level](#input\_protection\_level) | Cluster data protection level. | `number` | `2` | no |
| <a name="input_proxy_url"></a> [proxy\_url](#input\_proxy\_url) | Weka proxy url | `string` | `""` | no |
| <a name="input_s3_capacity_reservation_id"></a> [s3\_capacity\_reservation\_id](#input\_s3\_capacity\_reservation\_id) | The ID of the capacity reservation in which to run the s3 clients | `string` | `null` | no |
| <a name="input_s3_protocol_gateway_fe_cores_num"></a> [s3\_protocol\_gateway\_fe\_cores\_num](#input\_s3\_protocol\_gateway\_fe\_cores\_num) | S3 protocol gateways' NICs number. | `number` | `1` | no |
| <a name="input_s3_protocol_gateway_instance_iam_profile_arn"></a> [s3\_protocol\_gateway\_instance\_iam\_profile\_arn](#input\_s3\_protocol\_gateway\_instance\_iam\_profile\_arn) | The protocol gateway instance IAM profile ARN | `string` | `""` | no |
| <a name="input_s3_protocol_gateway_instance_type"></a> [s3\_protocol\_gateway\_instance\_type](#input\_s3\_protocol\_gateway\_instance\_type) | The protocol gateways' virtual machine type (sku) to deploy. | `string` | `"c5n.2xlarge"` | no |
| <a name="input_s3_protocol_gateway_weka_volume_size"></a> [s3\_protocol\_gateway\_weka\_volume\_size](#input\_s3\_protocol\_gateway\_weka\_volume\_size) | The protocol gateways' default disk size. | `number` | `48` | no |
| <a name="input_s3_protocol_gateways_number"></a> [s3\_protocol\_gateways\_number](#input\_s3\_protocol\_gateways\_number) | The number of protocol gateway virtual machines to deploy. | `number` | `0` | no |
| <a name="input_s3_setup_protocol"></a> [s3\_setup\_protocol](#input\_s3\_setup\_protocol) | Config protocol, default if false | `bool` | `false` | no |
| <a name="input_secretmanager_create_vpc_endpoint"></a> [secretmanager\_create\_vpc\_endpoint](#input\_secretmanager\_create\_vpc\_endpoint) | Enable secret manager VPC endpoint | `bool` | `true` | no |
| <a name="input_secretmanager_sg_ids"></a> [secretmanager\_sg\_ids](#input\_secretmanager\_sg\_ids) | Secret manager endpoint security groups ids | `list(string)` | `[]` | no |
| <a name="input_secretmanager_use_vpc_endpoint"></a> [secretmanager\_use\_vpc\_endpoint](#input\_secretmanager\_use\_vpc\_endpoint) | Use of secret manager is optional, if not used secrets will be passed between lambdas over step function. If secret manager is used, all lambdas will fetch secret directly when needed. | `bool` | `true` | no |
| <a name="input_set_dedicated_fe_container"></a> [set\_dedicated\_fe\_container](#input\_set\_dedicated\_fe\_container) | Create cluster with FE containers | `bool` | `true` | no |
| <a name="input_sfn_iam_role_arn"></a> [sfn\_iam\_role\_arn](#input\_sfn\_iam\_role\_arn) | Step function iam role arn | `string` | `""` | no |
| <a name="input_sg_ids"></a> [sg\_ids](#input\_sg\_ids) | Security group ids | `list(string)` | `[]` | no |
| <a name="input_smb_capacity_reservation_id"></a> [smb\_capacity\_reservation\_id](#input\_smb\_capacity\_reservation\_id) | The ID of the capacity reservation in which to run the smb clients | `string` | `null` | no |
| <a name="input_smb_cluster_name"></a> [smb\_cluster\_name](#input\_smb\_cluster\_name) | The name of the SMB setup. | `string` | `"Weka-SMB"` | no |
| <a name="input_smb_domain_name"></a> [smb\_domain\_name](#input\_smb\_domain\_name) | The domain to join the SMB cluster to. | `string` | `""` | no |
| <a name="input_smb_protocol_gateway_fe_cores_num"></a> [smb\_protocol\_gateway\_fe\_cores\_num](#input\_smb\_protocol\_gateway\_fe\_cores\_num) | The protocol gateways' NICs number. | `number` | `1` | no |
| <a name="input_smb_protocol_gateway_instance_iam_profile_arn"></a> [smb\_protocol\_gateway\_instance\_iam\_profile\_arn](#input\_smb\_protocol\_gateway\_instance\_iam\_profile\_arn) | The protocol gateway instance IAM profile ARN | `string` | `""` | no |
| <a name="input_smb_protocol_gateway_instance_type"></a> [smb\_protocol\_gateway\_instance\_type](#input\_smb\_protocol\_gateway\_instance\_type) | The protocol gateways' virtual machine type (sku) to deploy. | `string` | `"c5n.2xlarge"` | no |
| <a name="input_smb_protocol_gateway_secondary_ips_per_nic"></a> [smb\_protocol\_gateway\_secondary\_ips\_per\_nic](#input\_smb\_protocol\_gateway\_secondary\_ips\_per\_nic) | Number of secondary IPs per single NIC per protocol gateway virtual machine. | `number` | `0` | no |
| <a name="input_smb_protocol_gateway_weka_volume_size"></a> [smb\_protocol\_gateway\_weka\_volume\_size](#input\_smb\_protocol\_gateway\_weka\_volume\_size) | The protocol gateways' default disk size. | `number` | `48` | no |
| <a name="input_smb_protocol_gateways_number"></a> [smb\_protocol\_gateways\_number](#input\_smb\_protocol\_gateways\_number) | The number of protocol gateway virtual machines to deploy. | `number` | `0` | no |
| <a name="input_smb_setup_protocol"></a> [smb\_setup\_protocol](#input\_smb\_setup\_protocol) | Config protocol, default if false | `bool` | `false` | no |
| <a name="input_smbw_enabled"></a> [smbw\_enabled](#input\_smbw\_enabled) | Enable SMBW protocol. This option should be provided before cluster is created to leave extra capacity for SMBW setup. | `bool` | `true` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Ssh public key to pass to the instances. | `string` | `null` | no |
| <a name="input_stripe_width"></a> [stripe\_width](#input\_stripe\_width) | Stripe width = cluster\_size - protection\_level - 1 (by default). | `number` | `-1` | no |
| <a name="input_subnet_autocreate_as_private"></a> [subnet\_autocreate\_as\_private](#input\_subnet\_autocreate\_as\_private) | Create private subnet using nat gateway to route traffic. The default is public network. Relevant only when subnet\_ids is empty. | `bool` | `false` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet ids | `list(string)` | `[]` | no |
| <a name="input_subnets_cidrs"></a> [subnets\_cidrs](#input\_subnets\_cidrs) | CIDR block for subnet creation, required only if not specifying subnet\_ids, this block will be used to create subnet that will be used by weka. Currently limited to single | `list(string)` | <pre>[<br>  "10.0.1.0/24"<br>]</pre> | no |
| <a name="input_tags_map"></a> [tags\_map](#input\_tags\_map) | A map of tags to assign the same metadata to all resources in the environment. Format: key:value. Note: Manually tagged resources will be overridden by Terraform apply. | `map(string)` | `{}` | no |
| <a name="input_tiering_enable_obs_integration"></a> [tiering\_enable\_obs\_integration](#input\_tiering\_enable\_obs\_integration) | Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration. | `bool` | `false` | no |
| <a name="input_tiering_enable_ssd_percent"></a> [tiering\_enable\_ssd\_percent](#input\_tiering\_enable\_ssd\_percent) | When set\_obs\_integration is true, this variable sets the capacity percentage of the filesystem that resides on SSD. For example, for an SSD with a total capacity of 20GB, and the tiering\_ssd\_percent is set to 20, the total available capacity is 100GB. | `number` | `20` | no |
| <a name="input_tiering_obs_name"></a> [tiering\_obs\_name](#input\_tiering\_obs\_name) | Name of an existing S3 bucket | `string` | `""` | no |
| <a name="input_tiering_obs_start_demote"></a> [tiering\_obs\_start\_demote](#input\_tiering\_obs\_start\_demote) | Target tiering cue (in seconds) before starting upload data to OBS (turning it into read cache). Default is 10 seconds. | `number` | `10` | no |
| <a name="input_tiering_obs_target_ssd_retention"></a> [tiering\_obs\_target\_ssd\_retention](#input\_tiering\_obs\_target\_ssd\_retention) | Target retention period (in seconds) before tiering to OBS (how long data will stay in SSD). Default is 86400 seconds (24 hours). | `number` | `86400` | no |
| <a name="input_use_placement_group"></a> [use\_placement\_group](#input\_use\_placement\_group) | Use cluster placement group for backends. Note: If not using a cluster placement group, the instances will most likely be spread out across the underlying AWS infrastructure, resulting in not getting the maximum performance from the WEKA cluster | `bool` | `true` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block of the vpc | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_endpoint_autoscaling_create"></a> [vpc\_endpoint\_autoscaling\_create](#input\_vpc\_endpoint\_autoscaling\_create) | Create autoscaling VPC endpoint | `bool` | `false` | no |
| <a name="input_vpc_endpoint_dynamodb_gateway_create"></a> [vpc\_endpoint\_dynamodb\_gateway\_create](#input\_vpc\_endpoint\_dynamodb\_gateway\_create) | Create dynamodb gateway VPC endpoint | `bool` | `false` | no |
| <a name="input_vpc_endpoint_ec2_create"></a> [vpc\_endpoint\_ec2\_create](#input\_vpc\_endpoint\_ec2\_create) | Create Ec2 VPC endpoint | `bool` | `false` | no |
| <a name="input_vpc_endpoint_lambda_create"></a> [vpc\_endpoint\_lambda\_create](#input\_vpc\_endpoint\_lambda\_create) | Create Ec2 VPC endpoint | `bool` | `false` | no |
| <a name="input_vpc_endpoint_proxy_create"></a> [vpc\_endpoint\_proxy\_create](#input\_vpc\_endpoint\_proxy\_create) | creates VPC endpoint to weka-provided VPC Endpoint services that enable managed proxy to reach home.weka.io, get.weka.io, and AWS EC2/cloudwatch services”. Alternatively appropriate customer-managed proxy can be provided by proxy\_url variable | `bool` | `false` | no |
| <a name="input_vpc_endpoint_s3_gateway_create"></a> [vpc\_endpoint\_s3\_gateway\_create](#input\_vpc\_endpoint\_s3\_gateway\_create) | Create S3 gateway VPC endpoint | `bool` | `false` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID, required only for security group creation | `string` | `""` | no |
| <a name="input_weka_home_url"></a> [weka\_home\_url](#input\_weka\_home\_url) | Weka Home url | `string` | `""` | no |
| <a name="input_weka_version"></a> [weka\_version](#input\_weka\_version) | The Weka version to deploy. | `string` | `"4.2.12.87"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_alias_record"></a> [alb\_alias\_record](#output\_alb\_alias\_record) | If 'alb\_alias\_name` not null, it will output fqdn of the ALB` |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | If 'create\_alb` set to true, it will output dns name of the ALB` |
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | Name of ASG |
| <a name="output_client_asg_name"></a> [client\_asg\_name](#output\_client\_asg\_name) | n/a |
| <a name="output_client_helper_commands"></a> [client\_helper\_commands](#output\_client\_helper\_commands) | n/a |
| <a name="output_client_ips"></a> [client\_ips](#output\_client\_ips) | Ips of clients |
| <a name="output_cluster_helper_commands"></a> [cluster\_helper\_commands](#output\_cluster\_helper\_commands) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The cluster name |
| <a name="output_deploy_lambda_name"></a> [deploy\_lambda\_name](#output\_deploy\_lambda\_name) | n/a |
| <a name="output_ips_type"></a> [ips\_type](#output\_ips\_type) | If 'assign\_public\_ip' is set to true, it will output the public ips, If no it will output the private ips |
| <a name="output_lambda_status_name"></a> [lambda\_status\_name](#output\_lambda\_status\_name) | Name of lambda status |
| <a name="output_local_ssh_private_key"></a> [local\_ssh\_private\_key](#output\_local\_ssh\_private\_key) | If 'ssh\_public\_key' is set to null and no key\_pair\_name provided, it will output the private ssh key location. |
| <a name="output_nfs_protocol_gateways_ips"></a> [nfs\_protocol\_gateways\_ips](#output\_nfs\_protocol\_gateways\_ips) | Ips of NFS protocol gateways |
| <a name="output_placement_group_name"></a> [placement\_group\_name](#output\_placement\_group\_name) | Name of placement group |
| <a name="output_pre_terraform_destroy_command"></a> [pre\_terraform\_destroy\_command](#output\_pre\_terraform\_destroy\_command) | Mandatory pre-destroy steps only when S3/SMB protocol gateways are crated. Terraform doesn't handle protection removal. |
| <a name="output_s3_protocol_gateways_ips"></a> [s3\_protocol\_gateways\_ips](#output\_s3\_protocol\_gateways\_ips) | Ips of S3 protocol gateways |
| <a name="output_sg_ids"></a> [sg\_ids](#output\_sg\_ids) | Security group ids of backends |
| <a name="output_smb_protocol_gateways_ips"></a> [smb\_protocol\_gateways\_ips](#output\_smb\_protocol\_gateways\_ips) | Ips of SMB protocol gateways |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet ids of backends |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC id |
| <a name="output_weka_cluster_admin_password_secret_id"></a> [weka\_cluster\_admin\_password\_secret\_id](#output\_weka\_cluster\_admin\_password\_secret\_id) | Secret id of weka admin password |
<!-- END_TF_DOCS -->
