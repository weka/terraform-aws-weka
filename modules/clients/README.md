<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.autoscaling_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.autoscaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy_attachment.autoscaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ec2_ssm_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_placement_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/placement_group) | resource |
| [aws_ami.amzn_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.provided_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_dns_name"></a> [alb\_dns\_name](#input\_alb\_dns\_name) | ALB DNS name | `string` | `null` | no |
| <a name="input_arch"></a> [arch](#input\_arch) | n/a | `string` | `null` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public ip. | `bool` | `true` | no |
| <a name="input_backends_asg_name"></a> [backends\_asg\_name](#input\_backends\_asg\_name) | Name of the backends autoscaling group | `string` | n/a | yes |
| <a name="input_capacity_reservation_id"></a> [capacity\_reservation\_id](#input\_capacity\_reservation\_id) | The ID of the capacity reservation in which to run the clients | `string` | `null` | no |
| <a name="input_cert_pem"></a> [cert\_pem](#input\_cert\_pem) | Certificate PEM to use for the ALB when using self-signed certificate. | `string` | `null` | no |
| <a name="input_client_instance_ami_id"></a> [client\_instance\_ami\_id](#input\_client\_instance\_ami\_id) | The default AMI ID is set to Amazon Linux 2. For the list of all supported Weka Client OSs please refer to: https://docs.weka.io/planning-and-installation/prerequisites-and-compatibility#operating-system | `string` | `null` | no |
| <a name="input_clients_name"></a> [clients\_name](#input\_clients\_name) | The clients name. | `string` | n/a | yes |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | The number of virtual machines to deploy. | `number` | `2` | no |
| <a name="input_clients_use_dpdk"></a> [clients\_use\_dpdk](#input\_clients\_use\_dpdk) | Install weka cluster with DPDK | `bool` | `true` | no |
| <a name="input_custom_data"></a> [custom\_data](#input\_custom\_data) | Custom data to pass to the instances | `string` | `""` | no |
| <a name="input_ebs_encrypted"></a> [ebs\_encrypted](#input\_ebs\_encrypted) | Enables EBS encryption on the volume | `bool` | `true` | no |
| <a name="input_ebs_kms_key_id"></a> [ebs\_kms\_key\_id](#input\_ebs\_kms\_key\_id) | The ARN of the AWS Key Management Service | `string` | `""` | no |
| <a name="input_frontend_container_cores_num"></a> [frontend\_container\_cores\_num](#input\_frontend\_container\_cores\_num) | Number of frontend cores to use on client instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC | `number` | `1` | no |
| <a name="input_iam_base_name"></a> [iam\_base\_name](#input\_iam\_base\_name) | The prefix of the IAM role | `string` | `"weka"` | no |
| <a name="input_instance_iam_profile_arn"></a> [instance\_iam\_profile\_arn](#input\_instance\_iam\_profile\_arn) | Instance IAM profile ARN | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The virtual machine type (sku) to deploy | `string` | n/a | yes |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | Ssh key pair name to pass to the instances. | `string` | n/a | yes |
| <a name="input_metadata_http_tokens"></a> [metadata\_http\_tokens](#input\_metadata\_http\_tokens) | Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2 (IMDSv2) | `string` | `"required"` | no |
| <a name="input_placement_group_name"></a> [placement\_group\_name](#input\_placement\_group\_name) | Placement group name | `string` | `null` | no |
| <a name="input_proxy_url"></a> [proxy\_url](#input\_proxy\_url) | Weka proxy url | `string` | `""` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | root disk size. | `number` | `48` | no |
| <a name="input_sg_ids"></a> [sg\_ids](#input\_sg\_ids) | Security group ids | `list(string)` | `[]` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Id of the subnet | `string` | n/a | yes |
| <a name="input_tags_map"></a> [tags\_map](#input\_tags\_map) | A map of tags to assign the same metadata to all resources in the environment. Format: key:value. Note: Manually tagged resources will be overridden by Terraform apply. | `map(string)` | `{}` | no |
| <a name="input_use_autoscaling_group"></a> [use\_autoscaling\_group](#input\_use\_autoscaling\_group) | Use autoscaling group | `bool` | `false` | no |
| <a name="input_use_placement_group"></a> [use\_placement\_group](#input\_use\_placement\_group) | Use cluster placement group for clients. Note: If not using a cluster placement group, the instances will most likely be spread out across the underlying AWS infrastructure, resulting in not getting the maximum performance from the WEKA cluster | `bool` | `true` | no |
| <a name="input_weka_cluster_size"></a> [weka\_cluster\_size](#input\_weka\_cluster\_size) | [Deprecated] Number of backends in the weka cluster | `number` | `0` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | Name of ASG |
| <a name="output_client_helper_commands"></a> [client\_helper\_commands](#output\_client\_helper\_commands) | n/a |
| <a name="output_client_ips"></a> [client\_ips](#output\_client\_ips) | Ips of clients |
| <a name="output_clients_name"></a> [clients\_name](#output\_clients\_name) | Name of clients |
<!-- END_TF_DOCS -->
