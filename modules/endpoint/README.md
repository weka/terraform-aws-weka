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
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.ec2_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.lambda_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.proxy_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3_gateway_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint_security_group_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_security_group_association) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_ec2_endpoint"></a> [create\_ec2\_endpoint](#input\_create\_ec2\_endpoint) | Create ec2 endpoint | `bool` | n/a | yes |
| <a name="input_create_proxy_endpoint"></a> [create\_proxy\_endpoint](#input\_create\_proxy\_endpoint) | Create proxy endpoint | `bool` | n/a | yes |
| <a name="input_create_s3_gateway_endpoint"></a> [create\_s3\_gateway\_endpoint](#input\_create\_s3\_gateway\_endpoint) | Create s3 gateway endpoint | `bool` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | n/a | yes |
| <a name="input_region_map"></a> [region\_map](#input\_region\_map) | Name of region | `map(string)` | <pre>{<br>  "ap-northeast-1": "com.amazonaws.vpce.ap-northeast-1.vpce-svc-0e8a99999813c71e0",<br>  "ap-northeast-2": "com.amazonaws.vpce.ap-northeast-2.vpce-svc-093e0eeec8b7c6c4c",<br>  "ap-northeast-3": "com.amazonaws.vpce.ap-northeast-3.vpce-svc-09e56cde55ad96a63",<br>  "ap-south-1": "com.amazonaws.vpce.ap-south-1.vpce-svc-09213c43e5711950a",<br>  "ap-southeast-1": "com.amazonaws.vpce.ap-southeast-1.vpce-svc-0816aac78693475d6",<br>  "ap-southeast-2": "com.amazonaws.vpce.ap-southeast-2.vpce-svc-0a473ac647eb853bc",<br>  "ca-central-1": "com.amazonaws.vpce.ca-central-1.vpce-svc-0f3a4b3b0d8c87a7b",<br>  "eu-central-1": "com.amazonaws.vpce.eu-central-1.vpce-svc-0a7f7dd92c316e3fc",<br>  "eu-north-1": "com.amazonaws.vpce.eu-north-1.vpce-svc-006e6faae3f3be641",<br>  "eu-west-1": "com.amazonaws.vpce.eu-west-1.vpce-svc-0f7e742f1fa52d2f7",<br>  "eu-west-2": "com.amazonaws.vpce.eu-west-2.vpce-svc-0ef99d828da2992a6",<br>  "me-south-1": "com.amazonaws.vpce.me-south-1.vpce-svc-06d65d1ac36af2e46",<br>  "sa-east-1": "com.amazonaws.vpce.sa-east-1.vpce-svc-031d8ee7326794e03",<br>  "us-east-1": "com.amazonaws.vpce.us-east-1.vpce-svc-0a99896cec98e7f63",<br>  "us-east-2": "com.amazonaws.vpce.us-east-2.vpce-svc-009318e9319949b54",<br>  "us-west-1": "com.amazonaws.vpce.us-west-1.vpce-svc-0d8adfe18973b86d8",<br>  "us-west-2": "com.amazonaws.vpce.us-west-2.vpce-svc-05e512cfd7a03b097"<br>}</pre> | no |
| <a name="input_sg_ids"></a> [sg\_ids](#input\_sg\_ids) | List of sg ids | `list(string)` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet ids | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID, required only for security group creation | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_endpoint_sg_id"></a> [endpoint\_sg\_id](#output\_endpoint\_sg\_id) | n/a |
<!-- END_TF_DOCS -->
