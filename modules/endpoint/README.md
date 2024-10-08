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
| [aws_security_group.ec2_endpoint_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.proxy_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.autoscaling_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.dynamodb_endpoint_gtw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ec2_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.lambda_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.proxy_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3_gateway_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint_security_group_association.ec2_association_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_security_group_association) | resource |
| [aws_vpc_endpoint_security_group_association.proxy_association_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_security_group_association) | resource |
| [aws_route_table.subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_table) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_vpc_endpoint_autoscaling"></a> [create\_vpc\_endpoint\_autoscaling](#input\_create\_vpc\_endpoint\_autoscaling) | Create autoscaling vpc endpoint | `bool` | n/a | yes |
| <a name="input_create_vpc_endpoint_dynamodb_gateway"></a> [create\_vpc\_endpoint\_dynamodb\_gateway](#input\_create\_vpc\_endpoint\_dynamodb\_gateway) | Create dynamodb gateway vpc endpoint | `bool` | n/a | yes |
| <a name="input_create_vpc_endpoint_ec2"></a> [create\_vpc\_endpoint\_ec2](#input\_create\_vpc\_endpoint\_ec2) | Create ec2 vpc endpoint | `bool` | n/a | yes |
| <a name="input_create_vpc_endpoint_lambda"></a> [create\_vpc\_endpoint\_lambda](#input\_create\_vpc\_endpoint\_lambda) | Create lambda vpc endpoint | `bool` | n/a | yes |
| <a name="input_create_vpc_endpoint_proxy"></a> [create\_vpc\_endpoint\_proxy](#input\_create\_vpc\_endpoint\_proxy) | Creates VPC endpoint to weka-provided VPC Endpoint services that enable managed proxy to reach home.weka.io, get.weka.io, and AWS EC2/cloudwatch services”. Alternatively appropriate customer-managed proxy can be provided by proxy\_url variable | `bool` | n/a | yes |
| <a name="input_create_vpc_endpoint_s3_gateway"></a> [create\_vpc\_endpoint\_s3\_gateway](#input\_create\_vpc\_endpoint\_s3\_gateway) | Create s3 gateway vpc endpoint | `bool` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | n/a | yes |
| <a name="input_region_map"></a> [region\_map](#input\_region\_map) | Name of region | `map(string)` | <pre>{<br>  "ap-northeast-1": "com.amazonaws.vpce.ap-northeast-1.vpce-svc-0e8a99999813c71e0",<br>  "ap-northeast-2": "com.amazonaws.vpce.ap-northeast-2.vpce-svc-093e0eeec8b7c6c4c",<br>  "ap-northeast-3": "com.amazonaws.vpce.ap-northeast-3.vpce-svc-09e56cde55ad96a63",<br>  "ap-south-1": "com.amazonaws.vpce.ap-south-1.vpce-svc-09213c43e5711950a",<br>  "ap-southeast-1": "com.amazonaws.vpce.ap-southeast-1.vpce-svc-0816aac78693475d6",<br>  "ap-southeast-2": "com.amazonaws.vpce.ap-southeast-2.vpce-svc-0a473ac647eb853bc",<br>  "ca-central-1": "com.amazonaws.vpce.ca-central-1.vpce-svc-0f3a4b3b0d8c87a7b",<br>  "eu-central-1": "com.amazonaws.vpce.eu-central-1.vpce-svc-0a7f7dd92c316e3fc",<br>  "eu-north-1": "com.amazonaws.vpce.eu-north-1.vpce-svc-006e6faae3f3be641",<br>  "eu-west-1": "com.amazonaws.vpce.eu-west-1.vpce-svc-0f7e742f1fa52d2f7",<br>  "eu-west-2": "com.amazonaws.vpce.eu-west-2.vpce-svc-0ef99d828da2992a6",<br>  "me-south-1": "com.amazonaws.vpce.me-south-1.vpce-svc-06d65d1ac36af2e46",<br>  "sa-east-1": "com.amazonaws.vpce.sa-east-1.vpce-svc-031d8ee7326794e03",<br>  "us-east-1": "com.amazonaws.vpce.us-east-1.vpce-svc-0a99896cec98e7f63",<br>  "us-east-2": "com.amazonaws.vpce.us-east-2.vpce-svc-009318e9319949b54",<br>  "us-west-1": "com.amazonaws.vpce.us-west-1.vpce-svc-0d8adfe18973b86d8",<br>  "us-west-2": "com.amazonaws.vpce.us-west-2.vpce-svc-05e512cfd7a03b097"<br>}</pre> | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet id | `string` | n/a | yes |
| <a name="input_tags_map"></a> [tags\_map](#input\_tags\_map) | A map of tags to assign the same metadata to all resources in the environment. Format: key:value. Note: Manually tagged resources will be overridden by Terraform apply. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID, required only for security group creation | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ec2_endpoint_sg_id"></a> [ec2\_endpoint\_sg\_id](#output\_ec2\_endpoint\_sg\_id) | Vpc endpoint ec2 sg id |
| <a name="output_proxy_endpoint_sg_id"></a> [proxy\_endpoint\_sg\_id](#output\_proxy\_endpoint\_sg\_id) | Vpc endpoint proxy sg id |
<!-- END_TF_DOCS -->
