# terraform-aws-weka
Deploy weka on aws cloud with TF script

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
| <a name="module_security_group"></a> [security\_group](#module\_security\_group) | ./modules/security-group | n/a |

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
| [aws_lb_listener.lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
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
| <a name="input_allow_ssh_ranges"></a> [allow\_ssh\_ranges](#input\_allow\_ssh\_ranges) | Allow ssh from ips list to weka vms | `list(string)` | `[]` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | ami id | `string` | `null` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public ip. | `bool` | `true` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | AZ in which all the resources will be deployed | `list(string)` | n/a | yes |
| <a name="input_client_instance_ami_id"></a> [client\_instance\_ami\_id](#input\_client\_instance\_ami\_id) | The client instance AMI ID | `string` | `null` | no |
| <a name="input_client_instance_iam_profile_arn"></a> [client\_instance\_iam\_profile\_arn](#input\_client\_instance\_iam\_profile\_arn) | The client instance IAM profile ARN | `string` | `""` | no |
| <a name="input_client_instance_type"></a> [client\_instance\_type](#input\_client\_instance\_type) | The client instance type (sku) to deploy | `string` | `"i3en.large"` | no |
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
| <a name="input_event_iam_role"></a> [event\_iam\_role](#input\_event\_iam\_role) | Event iam role arn | `string` | `""` | no |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | The token to download the Weka release from get.weka.io. | `string` | n/a | yes |
| <a name="input_hotspare"></a> [hotspare](#input\_hotspare) | Hot-spare value. | `number` | `1` | no |
| <a name="input_install_weka_url"></a> [install\_weka\_url](#input\_install\_weka\_url) | The URL of the Weka release. Supports path to weka tar file or installation script. | `string` | `""` | no |
| <a name="input_instance_iam_profile_arn"></a> [instance\_iam\_profile\_arn](#input\_instance\_iam\_profile\_arn) | Instance IAM profile ARN | `string` | `""` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The virtual machine type (sku) to deploy. | `string` | `"i3en.2xlarge"` | no |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | Ssh key pair name to pass to the instances. | `string` | `null` | no |
| <a name="input_lambda_iam_role_arn"></a> [lambda\_iam\_role\_arn](#input\_lambda\_iam\_role\_arn) | Lambda IAM role ARN | `string` | `""` | no |
| <a name="input_lambdas_dist"></a> [lambdas\_dist](#input\_lambdas\_dist) | Lambdas code dist | `string` | `"dev"` | no |
| <a name="input_lambdas_version"></a> [lambdas\_version](#input\_lambdas\_version) | Lambdas code version (hash) | `string` | `"062bd488691dae860f9e2a98a865a194"` | no |
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
| <a name="input_sfn_iam_role"></a> [sfn\_iam\_role](#input\_sfn\_iam\_role) | Step function iam role arn | `string` | `""` | no |
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
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_helper_commands"></a> [helper\_commands](#output\_helper\_commands) | n/a |
| <a name="output_ips_type"></a> [ips\_type](#output\_ips\_type) | n/a |
| <a name="output_lambda_name"></a> [lambda\_name](#output\_lambda\_name) | n/a |
| <a name="output_local_ssh_private_key"></a> [local\_ssh\_private\_key](#output\_local\_ssh\_private\_key) | n/a |
| <a name="output_ssh_user"></a> [ssh\_user](#output\_ssh\_user) | n/a |
| <a name="output_weka_cluster_password_secret_id"></a> [weka\_cluster\_password\_secret\_id](#output\_weka\_cluster\_password\_secret\_id) | n/a |
<!-- END_TF_DOCS -->