# terraform-aws-weka

AWS Terraform module for deploying and managing Weka distributed filesystem clusters on AWS.

## Agentic Flow

The main agent is an orchestrator. It should delegate work via Task tool and minimize direct tool use. Direct tool use is acceptable only for 1-2 quick checks to orient. Model should always be set explicitly on tasks/subagents.

### Delegation Model (in order)

1. **Haiku task** — all codebase exploration, investigation, searching, and reading files. Even for complex debugging — haiku can read and trace code paths. It's 10-20x cheaper than opus.
2. **Sonnet task** — code edits, test runs, build verification, deploy flows.
3. **Opus task** — only for complex plan generation that requires deep understanding of the codebase. Use it only while having better initial context from a haiku task, or when sonnet is struggling with execution.

## Rules

- On each code change, update `.claude/CLAUDE.md` and `README.md` if needed.
- Run `/simplify` on each code change.

## Project Structure

```
terraform-aws-weka/
├── main.tf                  # EC2 instances, ASGs, placement groups, launch templates
├── variables.tf             # 100+ input variables
├── outputs.tf               # Cluster access & helper commands
├── versions.tf              # Provider constraints (TF >=1.4.6, AWS >=6.0.0)
├── alb.tf                   # Application Load Balancer
├── lambdas.tf               # Lambda function resources
├── step_function.tf         # Step Function state machine
├── secrets.tf               # Secrets Manager resources
├── state.tf                 # DynamoDB state table
├── prerequisites.tf         # Network/IAM prerequisites
├── clients.tf               # Client node module invocation
├── data_services.tf         # Data services module invocation
├── protocol_gateways.tf     # Protocol gateway module invocation
├── user_data.sh             # EC2 user data script template
├── Taskfile.yml             # Build tasks (lambda zip, upload, hash)
│
├── modules/
│   ├── acm/                 # ACM certificates with Route53 DNS validation
│   ├── clients/             # Client EC2 instances (mount Weka FS, DPDK)
│   ├── data_services/       # Data services instances
│   ├── endpoint/            # VPC endpoints (EC2, Lambda, S3, DynamoDB, etc.)
│   ├── iam/                 # IAM roles, policies, instance profiles
│   ├── kms/                 # KMS key management for EBS encryption
│   ├── network/             # VPC, subnets, NAT, IGW, route tables
│   ├── protocol_gateways/   # NFS, SMB, S3 gateway instances (multi-NIC)
│   ├── security_group/      # Security group rules (SSH, HTTPS, Weka API)
│   └── self_signed_certificate/  # TLS cert generation for ACM
│
├── lambdas/                 # Go-based Lambda functions
│   ├── main.go              # Handler dispatcher
│   ├── go.mod               # Go 1.21.1
│   ├── functions/
│   │   ├── deploy/          # Installation scripts for new machines
│   │   ├── clusterize/      # Cluster initialization
│   │   ├── clusterize_finalization/  # Post-clusterization state update
│   │   ├── report/          # Deployment progress tracking
│   │   ├── status/          # Cluster health status
│   │   ├── fetch/           # Cluster/ASG info for state machine
│   │   └── terminate/       # Instance deactivation & termination
│   ├── common/              # Shared state/DynamoDB utilities
│   ├── connectors/          # AWS SDK session management
│   └── management/          # Cluster lifecycle logic
│
├── lambdas_distribution/    # Build scripts for Lambda packaging
├── examples/public_network/ # Example deployment configuration
├── release/                 # Release artifacts
├── supported_regions/       # Region support data
└── .github/workflows/       # CI: lambda build, terraform-docs, linting
```

## Key Technical Details

- **Instance types**: i3en, i7ie, and i8ge families (NVMe-optimized)
- **Min cluster size**: 6 nodes
- **Default instance**: i3en.2xlarge
- **Orchestration**: Lambda + Step Functions + CloudWatch (1-min interval)
- **State**: DynamoDB table
- **Secrets**: AWS Secrets Manager (admin password, weka.io token)
- **Providers**: AWS >=6.0.0, TLS >=4.0.0, Local >=2.0.0, Random >=3.5.0
- **Lambda language**: Go 1.21.1
- **Build**: Taskfile.yml (task v3+)
- **CI**: GitHub Actions (lambda build, terraform-docs, tf-style-checks)
- **Pre-commit**: terraform_fmt, terraform_tflint

## Key Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `get_weka_io_token` | required | Token to download Weka releases |
| `cluster_name` | "poc" | Cluster identifier |
| `cluster_size` | 6 | Number of backend nodes |
| `instance_type` | "i3en.2xlarge" | EC2 instance type |
| `weka_version` | "" | Weka release version |
| `prefix` | "weka" | Resource name prefix |
| `create_alb` | true | Create Application Load Balancer |
| `tiering_enable_obs_integration` | false | Enable S3 object store tiering |

## Key Outputs

- `cluster_helper_commands` — map with `get_ips`, `get_password`, `get_status` CLI commands
- `alb_dns_name` — ALB DNS for cluster access
- `pre_terraform_destroy_command` — must run before `terraform destroy`
