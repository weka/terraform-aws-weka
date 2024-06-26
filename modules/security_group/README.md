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
| [aws_security_group.sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_allow_https_cidrs"></a> [alb\_allow\_https\_cidrs](#input\_alb\_allow\_https\_cidrs) | CIDRs to allow connecting to ALB over 443 port, by default 443 is not opened, and port 14000 used for connection, inheriting setting from  allow\_weka\_api\_ranges | `list(string)` | `[]` | no |
| <a name="input_allow_ssh_cidrs"></a> [allow\_ssh\_cidrs](#input\_allow\_ssh\_cidrs) | Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_allow_weka_api_cidrs"></a> [allow\_weka\_api\_cidrs](#input\_allow\_weka\_api\_cidrs) | Allow connection to port 14000 on weka backends and ALB(if exists and not provided with dedicated SG)  from specified CIDRs, by default no CIDRs are allowed. All ports (including 14000) are allowed within VPC | `list(string)` | `[]` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The cluster name. | `string` | `"poc"` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources names | `string` | `"weka"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_sg_ids"></a> [sg\_ids](#output\_sg\_ids) | SG Id |
<!-- END_TF_DOCS -->
