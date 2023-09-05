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

## Weke deployment prerequisites:
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
    },
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
<summary>Cloud Watch iam policy (replace *prefix* and *cluster_name* with relevant values)</summary>

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

## Usage example
```hcl
provider "aws" {
}

module "deploy_weka" {
  source             = "../../"
  prefix             = "weka-tf"
  cluster_name       = "test"
  availability_zones = ["a"]
  allow_ssh_ranges   = ["0.0.0.0/0"]
  get_weka_io_token  = "..."
  sg_ids             = [
    "..."
  ]
  subnet_ids = [
    "...",
  ]
  instance_iam_profile_arn = "..."
  lambda_iam_role_arn = "..."
  sfn_iam_role_arn = "..."
  event_iam_role_arn = "..."
  additional_alb_subnet         = "..."
  vpc_id                        = "..."
  create_secretmanager_endpoint = false
  set_obs_integration = true
}

output "deploy_weka_output" {
  value = module.deploy_weka
}
```

## Helper modules
We provide iam, network and security_group modules to help you create the prerequisites for the weka deployment.
<br>Check our [example](examples/public_network/main.tf) that uses these modules.
- When sg_ids isn't provided we automatically create a security group using our module.
- When subnet_ids isn't provided we automatically create a subnet using our module.
- When instance_iam_profile_arn isn't provided we automatically create an iam profile using our module.


### Private network deployment:
#### To avoid public ip assignment:
```hcl
assign_public_ip   = false
```

## Ssh keys
The username for ssh into vms is `ec2-user`.
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
## OBS
We support tiering to s3.
In order to setup tiering, you must supply the following variables:
```hcl
set_obs_integration = true
obs_name = "..."
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
client_instance_type = "c5.2xlarge"
client_nics_num = DESIRED_NUM
```


## Protocol Gateways
We support creating protocol gateways that will be mounted automatically to the cluster.
<br>In order to create you need to provide the number of protocol gateways instances you want (by default the number is 0),
for example:
```hcl
protocol_gateways_number = 2
```
This will automatically create 2 instances.
<br>In addition you can supply these optional variables:
```hcl
protocol                                  = VALUE
protocol_gateway_secondary_ips_per_nic    = 3
protocol_gateway_instance_type            = "c5.2xlarge"
protocol_gateway_nics_num                 = 2
protocol_gateway_disk_size                = 48
protocol_gateway_frontend_num             = 1
protocol_gateway_instance_iam_profile_arn = ""
```
### prerequisites:
- protocol_gateway_instance_iam_profile_arn
<details>
<summary>Protocol gateway iam policy (replace *prefix* and *cluster_name* with relevant values)</summary>

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
      "arn:aws:secretsmanager:*:*:secret:${var.secret_prefix}*"
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
      "arn:aws:logs:*:*:log-group:/wekaio/clients/${var.gateways_name}*"
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

## Secret manager
We use the secret manager to store the weka username, password (and get.weka.io token).
We need to be able to use them on `scale down` lambda which runs inside the provided vpc.
In case providing secret manager endpoint isn't possible, you can set `use_secretmanager_endpoint=false`
On your weka deployment module and we not use it. In this case the weka username password will be sent to
`scale_down` lambda via `fetch` lambda and the will be shown as plain text on the state machine.

<br>In case you want to use secret manager, and would like to create the endpoint automatically,
you can set: `create_secretmanager_endpoint=true`

## Terraform output
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
| <a name="module_security_group"></a> [security\_group](#module\_security\_group) | ./modules/security_group | n/a |

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
| [aws_dynamodb_table_item.weka_deployment_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_key_pair.generated_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_lambda_function.clusterize_finalization_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.clusterize_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.deploy_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.fetch_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.report_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.scale_down_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.status_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.terminate_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.transient_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.invoke_lambda_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_launch_template.launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.lb_http_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.lb_https_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_placement_group.placement_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/placement_group) | resource |
| [aws_route53_record.lb_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_secretsmanager_secret.get_weka_io_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.weka_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.weka_username](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.get_weka_io_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.weka_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.weka_username](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_sfn_state_machine.scale_down_state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [aws_vpc_endpoint.secretmanager_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [tls_private_key.key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [aws_ami.amzn_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_add_frontend_container"></a> [add\_frontend\_container](#input\_add\_frontend\_container) | Create cluster with FE containers | `bool` | `true` | no |
| <a name="input_additional_alb_subnet"></a> [additional\_alb\_subnet](#input\_additional\_alb\_subnet) | Additional subnet for ALB | `string` | `""` | no |
| <a name="input_alb_alias_name"></a> [alb\_alias\_name](#input\_alb\_alias\_name) | Set ALB alias name | `string` | `""` | no |
| <a name="input_alb_cert_arn"></a> [alb\_cert\_arn](#input\_alb\_cert\_arn) | HTTPS certificate ARN for ALB | `string` | `null` | no |
| <a name="input_alb_sg_ids"></a> [alb\_sg\_ids](#input\_alb\_sg\_ids) | Security group ids for ALB | `list(string)` | `[]` | no |
| <a name="input_allow_https_ranges"></a> [allow\_https\_ranges](#input\_allow\_https\_ranges) | Allow port 443, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_allow_ssh_ranges"></a> [allow\_ssh\_ranges](#input\_allow\_ssh\_ranges) | Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_allow_weka_api_ranges"></a> [allow\_weka\_api\_ranges](#input\_allow\_weka\_api\_ranges) | Allow port 14000, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | ami id | `string` | `null` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public ip. | `bool` | `true` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | AZ in which all the resources will be deployed | `list(string)` | n/a | yes |
| <a name="input_client_instance_ami_id"></a> [client\_instance\_ami\_id](#input\_client\_instance\_ami\_id) | The client instance AMI ID | `string` | `null` | no |
| <a name="input_client_instance_iam_profile_arn"></a> [client\_instance\_iam\_profile\_arn](#input\_client\_instance\_iam\_profile\_arn) | The client instance IAM profile ARN | `string` | `""` | no |
| <a name="input_client_instance_type"></a> [client\_instance\_type](#input\_client\_instance\_type) | The client instance type (sku) to deploy | `string` | `"c5.2xlarge"` | no |
| <a name="input_client_nics_num"></a> [client\_nics\_num](#input\_client\_nics\_num) | The client NICs number | `string` | `2` | no |
| <a name="input_client_placement_group_name"></a> [client\_placement\_group\_name](#input\_client\_placement\_group\_name) | The client instances placement group name | `string` | `""` | no |
| <a name="input_client_root_volume_size"></a> [client\_root\_volume\_size](#input\_client\_root\_volume\_size) | The client root volume size in GB | `number` | `50` | no |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | The number of client instances to deploy | `number` | `0` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The cluster name. | `string` | `"poc"` | no |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | The number of virtual machines to deploy. | `number` | `6` | no |
| <a name="input_container_number_map"></a> [container\_number\_map](#input\_container\_number\_map) | Maps the number of objects and memory size per machine type. | <pre>map(object({<br>    compute  = number<br>    drive    = number<br>    frontend = number<br>    nvme     = number<br>    nics     = number<br>    memory   = list(string)<br>  }))</pre> | <pre>{<br>  "i3.16xlarge": {<br>    "compute": 9,<br>    "drive": 4,<br>    "frontend": 1,<br>    "memory": [<br>      "387.9GB",<br>      "349.3GB"<br>    ],<br>    "nics": 15,<br>    "nvme": 4<br>  },<br>  "i3.2xlarge": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "30.9GB",<br>      "30.7GB"<br>    ],<br>    "nics": 4,<br>    "nvme": 1<br>  },<br>  "i3.4xlarge": {<br>    "compute": 5,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "74.3GB",<br>      "74.1GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 2<br>  },<br>  "i3.8xlarge": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": [<br>      "186GB",<br>      "185.8GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 4<br>  },<br>  "i3en.12xlarge": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": [<br>      "310.7GB",<br>      "310.4GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 4<br>  },<br>  "i3en.24xlarge": {<br>    "compute": 9,<br>    "drive": 4,<br>    "frontend": 1,<br>    "memory": [<br>      "637.1GB",<br>      "573.6GB"<br>    ],<br>    "nics": 15,<br>    "nvme": 8<br>  },<br>  "i3en.2xlarge": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "32.9GB",<br>      "32.64GB"<br>    ],<br>    "nics": 4,<br>    "nvme": 2<br>  },<br>  "i3en.3xlarge": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "62.GB",<br>      "61.7GB"<br>    ],<br>    "nics": 4,<br>    "nvme": 1<br>  },<br>  "i3en.6xlarge": {<br>    "compute": 5,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "136.5GB",<br>      "136.2GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 2<br>  }<br>}</pre> | no |
| <a name="input_create_alb"></a> [create\_alb](#input\_create\_alb) | Create ALB | `bool` | `true` | no |
| <a name="input_create_secretmanager_endpoint"></a> [create\_secretmanager\_endpoint](#input\_create\_secretmanager\_endpoint) | Enable secret manager endpoint on vpc | `bool` | `true` | no |
| <a name="input_dynamodb_hash_key_name"></a> [dynamodb\_hash\_key\_name](#input\_dynamodb\_hash\_key\_name) | DynamoDB hash key name (optional configuration, will use 'Key' by default) | `string` | `"Key"` | no |
| <a name="input_dynamodb_table_name"></a> [dynamodb\_table\_name](#input\_dynamodb\_table\_name) | DynamoDB table name, if not supplied a new table will be created | `string` | `""` | no |
| <a name="input_event_iam_role_arn"></a> [event\_iam\_role\_arn](#input\_event\_iam\_role\_arn) | Event iam role arn | `string` | `""` | no |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | The token to download the Weka release from get.weka.io. | `string` | n/a | yes |
| <a name="input_hotspare"></a> [hotspare](#input\_hotspare) | Hot-spare value. | `number` | `1` | no |
| <a name="input_install_weka_url"></a> [install\_weka\_url](#input\_install\_weka\_url) | The URL of the Weka release. Supports path to weka tar file or installation script. | `string` | `""` | no |
| <a name="input_instance_iam_profile_arn"></a> [instance\_iam\_profile\_arn](#input\_instance\_iam\_profile\_arn) | Instance IAM profile ARN | `string` | `""` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The virtual machine type (sku) to deploy. | `string` | `"i3en.2xlarge"` | no |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | Ssh key pair name to pass to the instances. | `string` | `null` | no |
| <a name="input_lambda_iam_role_arn"></a> [lambda\_iam\_role\_arn](#input\_lambda\_iam\_role\_arn) | Lambda IAM role ARN | `string` | `""` | no |
| <a name="input_lambdas_dist"></a> [lambdas\_dist](#input\_lambdas\_dist) | Lambdas code dist | `string` | `"dev"` | no |
| <a name="input_lambdas_version"></a> [lambdas\_version](#input\_lambdas\_version) | Lambdas code version (hash) | `string` | `"2a9f1c0a87c61e9f6f027ee4c9611e29"` | no |
| <a name="input_mount_clients_dpdk"></a> [mount\_clients\_dpdk](#input\_mount\_clients\_dpdk) | Mount weka clients in DPDK mode | `bool` | `true` | no |
| <a name="input_obs_name"></a> [obs\_name](#input\_obs\_name) | Name of existing obs storage account | `string` | `""` | no |
| <a name="input_placement_group_name"></a> [placement\_group\_name](#input\_placement\_group\_name) | n/a | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | `"weka"` | no |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | Determines whether to enable a private or public network. The default is public network. Relevant only when subnet\_ids is empty. | `bool` | `false` | no |
| <a name="input_protection_level"></a> [protection\_level](#input\_protection\_level) | Cluster data protection level. | `number` | `2` | no |
| <a name="input_proxy_url"></a> [proxy\_url](#input\_proxy\_url) | Weka home proxy url | `string` | `""` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 zone id | `string` | `""` | no |
| <a name="input_secretmanager_endpoint_sg_ids"></a> [secretmanager\_endpoint\_sg\_ids](#input\_secretmanager\_endpoint\_sg\_ids) | Secret manager endpoint security groups ids | `list(string)` | `[]` | no |
| <a name="input_set_obs_integration"></a> [set\_obs\_integration](#input\_set\_obs\_integration) | Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration. | `bool` | `false` | no |
| <a name="input_sfn_iam_role_arn"></a> [sfn\_iam\_role\_arn](#input\_sfn\_iam\_role\_arn) | Step function iam role arn | `string` | `""` | no |
| <a name="input_sg_ids"></a> [sg\_ids](#input\_sg\_ids) | Security group ids | `list(string)` | `[]` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Ssh public key to pass to the instances. | `string` | `null` | no |
| <a name="input_stripe_width"></a> [stripe\_width](#input\_stripe\_width) | Stripe width = cluster\_size - protection\_level - 1 (by default). | `number` | `-1` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet ids | `list(string)` | `[]` | no |
| <a name="input_tags_map"></a> [tags\_map](#input\_tags\_map) | A map of tags to assign the same metadata to all resources in the environment. Format: key:value. | `map(string)` | <pre>{<br>  "creator": "tf",<br>  "env": "dev"<br>}</pre> | no |
| <a name="input_tiering_ssd_percent"></a> [tiering\_ssd\_percent](#input\_tiering\_ssd\_percent) | When set\_obs\_integration is true, this variable sets the capacity percentage of the filesystem that resides on SSD. For example, for an SSD with a total capacity of 20GB, and the tiering\_ssd\_percent is set to 20, the total available capacity is 100GB. | `number` | `20` | no |
| <a name="input_use_secretmanager_endpoint"></a> [use\_secretmanager\_endpoint](#input\_use\_secretmanager\_endpoint) | Use secret manager endpoint | `bool` | `true` | no |
| <a name="input_vm_username"></a> [vm\_username](#input\_vm\_username) | The user name for logging in to the virtual machines. | `string` | `"ec2-user"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID, required only for security group creation | `string` | `""` | no |
| <a name="input_weka_username"></a> [weka\_username](#input\_weka\_username) | Weka cluster username | `string` | `"admin"` | no |
| <a name="input_weka_version"></a> [weka\_version](#input\_weka\_version) | The Weka version to deploy. | `string` | `"4.2.1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_alias_record"></a> [alb\_alias\_record](#output\_alb\_alias\_record) | n/a |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | n/a |
| <a name="output_client_ips"></a> [client\_ips](#output\_client\_ips) | n/a |
| <a name="output_cluster_helper_commands"></a> [cluster\_helper\_commands](#output\_cluster\_helper\_commands) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_ips_type"></a> [ips\_type](#output\_ips\_type) | n/a |
| <a name="output_lambda_name"></a> [lambda\_name](#output\_lambda\_name) | n/a |
| <a name="output_local_ssh_private_key"></a> [local\_ssh\_private\_key](#output\_local\_ssh\_private\_key) | n/a |
| <a name="output_ssh_user"></a> [ssh\_user](#output\_ssh\_user) | n/a |
| <a name="output_weka_cluster_password_secret_id"></a> [weka\_cluster\_password\_secret\_id](#output\_weka\_cluster\_password\_secret\_id) | n/a |
<!-- END_TF_DOCS -->
