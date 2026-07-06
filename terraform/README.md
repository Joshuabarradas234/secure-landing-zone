# Terraform Infrastructure as Code

This directory contains the complete Infrastructure as Code for the Secure Multi-Account Landing Zone.

## Directory Structure

```
terraform/
├── modules/                    # Reusable Terraform modules
│   ├── organizations/          # AWS Organizations + OUs + SCPs
│   ├── security-logging/       # CloudTrail + S3 + CloudWatch Logs
│   ├── security-hub/           # Security Hub aggregator + standards
│   ├── guardduty/              # GuardDuty detector + alerts
│   ├── iam-identity-center/    # IAM Identity Center + permission sets
│   └── networking/             # VPC scaffold for workload accounts
├── environments/               # Account-specific deployments
│   ├── management/             # Management account: Organizations + SCPs
│   ├── security/               # Security account: Logging + Security Hub + GuardDuty
│   └── workload-base/          # Template for workload VPCs (dev/staging/prod)
├── scripts/
│   └── validate.sh             # Pre-commit validation script
└── README.md                   # This file
```

## Modules Overview

### 1. organizations/
Creates multi-account structure with Service Control Policies.

**What it deploys:**
- 3 Organizational Units: Security, SharedServices, Workloads
- 3 Service Control Policies:
  - `deny-disable-cloudtrail`: Blocks CloudTrail modifications at the account level
  - `require-s3-encryption`: Enforces S3 bucket encryption
  - `protect-security-services`: Prevents disabling GuardDuty, Security Hub, Config
- Cross-account IAM role for Terraform delegation

**Inputs:**
```hcl
name_prefix           = "secure-multi-account-landing-zone"
management_account_id = "123456789012"
terraform_external_id = "random-external-id"
tags                  = { Project = "landing-zone", ManagedBy = "terraform" }
```

**Key outputs:**
- `organization_id`: AWS Organization ID
- `security_ou_id`: Security OU ID
- `workloads_ou_id`: Workloads OU ID
- `terraform_cross_account_role_arn`: Cross-account role ARN

---

### 2. security-logging/
Deploys organization-wide CloudTrail with centralized S3 storage.

**What it deploys:**
- S3 bucket for CloudTrail logs (encrypted, versioned, with lifecycle rules)
- Organization CloudTrail (multi-region, log file validation)
- CloudWatch Log Group for CloudTrail events
- IAM role for CloudTrail → CloudWatch Logs
- SNS topic for alerts
- Lifecycle rule: Move logs to Glacier after 90 days

**Inputs:**
```hcl
name_prefix              = "secure-multi-account-landing-zone"
cloudwatch_retention_days = 30
tags                     = { Project = "landing-zone" }
```

**Key outputs:**
- `cloudtrail_s3_bucket_name`: S3 bucket storing logs
- `cloudtrail_arn`: CloudTrail ARN
- `cloudwatch_log_group_name`: CloudWatch Logs group
- `sns_topic_arn`: SNS topic for alerts

---

### 3. security-hub/
Aggregates security findings from all accounts.

**What it deploys:**
- Security Hub hub in aggregator account
- CIS AWS Foundations Benchmark standard (enabled by default)
- PCI DSS standard (optional, `enable_pci_dss = true`)
- Finding aggregator (pulls findings from member accounts across all regions)
- EventBridge rule: Routes HIGH/CRITICAL findings to SNS
- SNS topic for notifications
- CloudWatch dashboard: Security posture overview
- CloudWatch alarm: Alerts on critical findings

**Inputs:**
```hcl
name_prefix              = "secure-multi-account-landing-zone"
member_account_ids       = ["123456789012", "210987654321"]  # Dev, Staging, Prod
enable_default_standards = true
enable_pci_dss          = false
tags                     = { Project = "landing-zone" }
```

**Key outputs:**
- `hub_arn`: Security Hub ARN
- `finding_aggregator_arn`: Finding aggregator ARN
- `sns_topic_arn`: SNS for alerts

---

### 4. guardduty/
Enables threat detection across all accounts.

**What it deploys:**
- GuardDuty detector (S3 + Kubernetes audit logs enabled)
- EventBridge rule: Routes HIGH/CRITICAL findings to SNS
- SNS topic for notifications
- CloudWatch Log Group for findings
- CloudWatch alarm: Alert on multiple findings

**Inputs:**
```hcl
name_prefix              = "secure-multi-account-landing-zone"
cloudwatch_retention_days = 30
tags                     = { Project = "landing-zone" }
```

**Key outputs:**
- `detector_id`: GuardDuty detector ID
- `detector_arn`: Detector ARN
- `sns_topic_arn`: SNS for alerts

---

### 5. iam-identity-center/
Configures centralized identity with permission sets.

**What it deploys:**
- 3 permission sets:
  - **Admin**: Full administrative access
  - **Developer**: EC2, RDS, DynamoDB, Lambda (deny IAM, security services)
  - **SecurityLead**: Read-only + Security Hub/GuardDuty access
- CloudWatch Log Group for identity activity
- Setup instructions for Entra ID federation

**Note:** Full Entra ID integration is manual (SAML configuration in Azure). This module sets up the AWS side.

**Inputs:**
```hcl
name_prefix              = "secure-multi-account-landing-zone"
aws_region              = "us-east-1"
cloudwatch_retention_days = 30
tags                     = { Project = "landing-zone" }
```

**Key outputs:**
- `identity_center_instance_arn`: Identity Center instance
- `admin_permission_set_arn`: Admin permission set
- `developer_permission_set_arn`: Developer permission set
- `security_lead_permission_set_arn`: SecurityLead permission set
- `entra_id_setup_instructions`: Manual Entra ID integration guide

---

### 6. networking/
VPC scaffold for workload accounts.

**What it deploys:**
- VPC with configurable CIDR
- Public subnets (one per AZ) + Internet Gateway
- Private subnets (one per AZ) + NAT Gateway
- Route tables: Public (→ IGW), Private (→ NAT per AZ)
- VPC Flow Logs → CloudWatch Logs
- IAM role for Flow Logs

**Inputs:**
```hcl
name_prefix               = "prod-vpc"
vpc_cidr                 = "10.0.0.0/16"
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs     = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones       = ["us-east-1a", "us-east-1b"]
cloudwatch_retention_days = 30
tags                     = { Project = "landing-zone" }
```

**Key outputs:**
- `vpc_id`: VPC ID
- `public_subnet_ids`: Public subnet IDs
- `private_subnet_ids`: Private subnet IDs
- `nat_gateway_ids`: NAT Gateway IDs
- `vpc_flow_log_group_name`: Flow Logs group name

---

## Environments

### Management Account (`environments/management/`)

Deploy Organizations + OUs + SCPs.

```bash
cd environments/management
terraform init
terraform plan
terraform apply
```

**Variables:**
- `aws_region`: Default us-east-1
- `terraform_external_id`: Random string for cross-account role assumption

**Output:** Organization structure with SCPs applied to Workloads OU

---

### Security Account (`environments/security/`)

Deploy centralized logging + Security Hub + GuardDuty.

```bash
cd environments/security
terraform init
terraform plan
terraform apply
```

**Variables:**
- `member_account_ids`: List of dev/staging/prod account IDs
- `cloudwatch_retention_days`: Log retention (default 30)
- `enable_pci_dss`: Optional PCI DSS standard (default false)

**Output:** CloudTrail, Security Hub aggregator, GuardDuty detector, SNS topics

---

### Workload Base (`environments/workload-base/`)

VPC template for deploying to workload accounts.

```bash
cd environments/workload-base
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

**Variables:**
- `environment`: dev, staging, or prod
- `vpc_cidr`: Custom CIDR block
- `public_subnet_cidrs`, `private_subnet_cidrs`: Customizable subnets

**Output:** VPC + subnets + NAT gateway + VPC Flow Logs

---

## Validation & Testing

### Local Validation

```bash
# From terraform/ directory
bash scripts/validate.sh
```

This runs:
- `terraform fmt --check` (formatting)
- `terraform validate` (syntax)
- `tfsec` (security scan, if installed)
- `checkov` (compliance check, if installed)

### GitHub Actions CI/CD

Two workflows are provided:

1. **`.github/workflows/validate.yml`** — Pre-commit checks
   - Runs on every PR touching `terraform/`
   - Checks formatting, syntax, security
   - Comments results on PR

2. **`.github/workflows/plan.yml`** — Terraform plan
   - Generates plan for each environment
   - Requires AWS credentials (via OIDC or IAM role)
   - Comments plan summary on PR

---

## Deployment Order

1. **Management account** — Create Organizations + OUs + SCPs
   ```bash
   cd environments/management && terraform apply
   ```

2. **Security account** — Create logging + Security Hub + GuardDuty
   ```bash
   cd environments/security && terraform apply
   ```

3. **Workload VPCs** (optional) — Create VPC templates
   ```bash
   cd environments/workload-base && terraform apply -var="environment=dev"
   ```

See [DEPLOYMENT.md](../DEPLOYMENT.md) for detailed walkthrough.

---

## Cost Considerations

### Per-Month Costs (Production)

| Component | Cost |
|-----------|------|
| CloudTrail | $2–$5 |
| S3 (logs) | $0.50–$5 |
| GuardDuty | $30–$50 |
| Security Hub | $30 |
| CloudWatch Logs | $5–$15 |
| SNS/Identity Center | <$1 |
| **Total** | **$70–$100** |

### Cost Optimization

- **Reduce log retention:** Change `cloudwatch_retention_days = 7` (from 30)
- **Disable S3 lifecycle:** Remove Glacier transition
- **Disable PCI DSS:** Set `enable_pci_dss = false`

---

## Troubleshooting

### Error: "You do not have permission to perform"
- Verify IAM role has Organizations, Security Hub, GuardDuty permissions
- Check credentials: `aws sts get-caller-identity`

### CloudTrail not logging
- Verify S3 bucket exists
- Check S3 bucket policy allows CloudTrail service
- Wait 5 minutes for CloudTrail to deliver logs

### Security Hub findings not aggregating
- Ensure member accounts are in Workloads OU
- GuardDuty must be enabled in member accounts
- Wait 5–10 minutes for findings to sync

### Error: "Identity Center not found"
- Ensure Identity Center is enabled: `aws sso list-instances`
- Instance must be in the same region as Terraform deployment

---

## Next Steps

1. **Deploy to production** — Follow [DEPLOYMENT.md](../DEPLOYMENT.md)
2. **Subscribe to SNS topics** — Get alerts in email/Slack
3. **Configure Entra ID** — Follow identity-center module output
4. **Invite team members** — Create users in Identity Center
5. **Scale to 10+ accounts** — Update `member_account_ids` and redeploy

---

## References

- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/best-practices.html)
- [Security Hub User Guide](https://docs.aws.amazon.com/securityhub/latest/userguide/)
- [GuardDuty Finding Types](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-active.html)
- [IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
