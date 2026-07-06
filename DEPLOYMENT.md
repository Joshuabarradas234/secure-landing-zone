# Deployment Guide: Secure Multi-Account Landing Zone

## Prerequisites

Before deploying, ensure:

1. **AWS Account Setup:**
   - Management account with AWS Organizations enabled
   - Billing account configured
   - Administrative IAM credentials available

2. **Local Tools:**
   - Terraform >= 1.5.0 (`terraform version`)
   - AWS CLI v2 configured with appropriate credentials
   - Optional: tfsec for security scanning, checkov for compliance

3. **AWS Service Quotas:**
   - Verify S3 bucket quota (CloudTrail logs bucket)
   - Verify SNS topic quota (for alerts)
   - Verify IAM Identity Center availability in your region

## Deployment Architecture

```
Management Account (AWS Organizations root)
├── Organizations module
│   ├── OUs: Security, SharedServices, Workloads
│   └── SCPs: CloudTrail protection, S3 encryption, security service locks

Security Account (Aggregator account)
├── Security Logging: CloudTrail → S3 + CloudWatch Logs
├── Security Hub: Aggregator for all findings
├── GuardDuty: Threat detection
└── IAM Identity Center: Permission sets + federation setup

Workload Accounts (Dev, Staging, Prod - template)
└── VPC: Multi-AZ with NAT, Flow Logs
```

## Phase 1: Management Account (SCPs + Organizations)

### Step 1: Initialize and Validate

```bash
cd terraform/environments/management

# Review variables
cat terraform.tfvars  # (or create from template)

# Validate syntax
terraform validate

# Generate plan
terraform plan -out=tfplan
```

### Step 2: Review and Apply

```bash
# Review the plan carefully — SCPs are organization-wide
terraform plan -out=tfplan

# Apply (this creates OUs and SCPs across the org)
terraform apply tfplan
```

**What was created:**
- 3 Organizational Units (Security, SharedServices, Workloads)
- 3 Service Control Policies:
  - `deny-disable-cloudtrail`: Blocks CloudTrail modifications
  - `require-s3-encryption`: Enforces S3 encryption
  - `protect-security-services`: Blocks GuardDuty/Security Hub/Config disabling

### Step 3: Verify in AWS Console

1. Go to AWS Organizations → Organizational Units
2. Verify three OUs exist: Security, SharedServices, Workloads
3. Go to Policies → Service Control Policies
4. Verify three SCPs are attached to Workloads OU

**Output to save:**
- Organization ID
- Security OU ID
- Terraform cross-account role ARN (needed for member accounts)

---

## Phase 2: Security Account (Logging + Monitoring)

### Step 1: Switch to Security Account

```bash
# Export security account credentials
export AWS_PROFILE=security-account  # Or set AWS_ACCESS_KEY_ID, etc.

cd terraform/environments/security
```

### Step 2: Update Variables

Edit `terraform.tfvars` or pass via `-var`:

```hcl
# Required: member account IDs that will be aggregated
member_account_ids = [
  "123456789012",  # Dev account
  "210987654321",  # Staging account
  "321098765432",  # Prod account
]

# Optional: enable PCI DSS if needed
enable_pci_dss = false

# Cost optimization: log retention
cloudwatch_retention_days = 30
```

### Step 3: Validate and Plan

```bash
terraform validate
terraform plan -out=tfplan
```

**What will be created:**
- CloudTrail: Organization-wide logging to S3
- S3 Bucket: With encryption, versioning, lifecycle (→ Glacier after 90 days)
- Security Hub: Aggregator + CIS AWS Foundations standard
- GuardDuty: Detector with S3 and Kubernetes audit log sources
- IAM Identity Center: Permission sets (Admin, Developer, SecurityLead)
- EventBridge: Routes critical findings to SNS
- SNS Topics: For Security Hub + GuardDuty alerts
- CloudWatch Dashboards: Security posture overview
- CloudWatch Alarms: Trigger on critical findings

### Step 4: Apply

```bash
terraform apply tfplan
```

### Step 5: Verify in AWS Console

1. **CloudTrail:**
   - Go to CloudTrail → Trails
   - Verify organization trail is logging to S3 bucket

2. **S3 CloudTrail Bucket:**
   - Verify bucket exists with encryption enabled
   - Verify versioning is enabled
   - Check lifecycle rule (should show 90-day → GLACIER transition)

3. **Security Hub:**
   - Go to Security Hub → Home
   - Verify hub is enabled
   - Check "Compliance" tab for CIS AWS Foundations checks

4. **GuardDuty:**
   - Go to GuardDuty → Findings
   - Verify detector is active (should show "Finding count" even if 0)

5. **IAM Identity Center:**
   - Go to IAM Identity Center → Permission sets
   - Verify three permission sets: Admin, Developer, SecurityLead

**Output to save:**
- CloudTrail S3 bucket ARN
- Security Hub hub ARN
- GuardDuty detector ID
- SNS topic ARNs (for alert subscription)

---

## Phase 3: Connect Member Accounts (Optional - Reference Pattern)

To link dev/staging/prod accounts to the Security account:

### For each member account:

1. **Enable GuardDuty as member:**
   ```bash
   aws guardduty create-members \
     --account-details AccountId=<member-id>,Email=<email> \
     --region us-east-1
   ```

2. **Link to Security Hub aggregator:**
   - In Security Hub console (security account), go to Findings
   - Click "Manage accounts"
   - Add member account IDs

3. **Optional: Deploy workload VPC:**
   ```bash
   cd terraform/environments/workload-base
   terraform init
   terraform plan -var "name_prefix=prod-vpc"
   terraform apply
   ```

---

## Phase 4: Configure Entra ID Federation (Manual)

IAM Identity Center requires manual Entra ID setup (not Terraformed due to external provider):

1. **In Azure Portal:**
   - Create enterprise application: "AWS IAM Identity Center"
   - Download SAML metadata
   - Configure SAML assertions (email → user principal name)

2. **In AWS Console (Security Account):**
   - Go to IAM Identity Center → Settings
   - Click "Identity source" → "External identity provider"
   - Upload SAML metadata from Entra ID
   - Test SAML authentication

3. **Create Users/Groups:**
   - In Identity Center, create users matching Entra ID principals
   - Assign permission sets: Admin, Developer, SecurityLead
   - Test login: `https://portal.sso.us-east-1.amazonaws.com`

---

## Validation & Compliance

### Run Validation Script

```bash
cd terraform
bash scripts/validate.sh
```

This runs:
- `terraform fmt --check` (formatting)
- `terraform validate` (syntax)
- `tfsec` (security scan, if installed)
- `checkov` (compliance check, if installed)

### Manually Verify SCPs are Enforced

In any workload account, attempt to:

```bash
# This should be denied by SCP (not by IAM)
aws s3 mb s3://test-bucket  # No encryption = denied

# This should be denied
aws cloudtrail delete-trail --name my-trail  # Denied by SCP
```

---

## Rollback & Cleanup

### To destroy all resources (⚠️ WARNING):

```bash
# Security account
cd terraform/environments/security
terraform destroy

# Management account (destroys OUs + SCPs)
cd terraform/environments/management
terraform destroy
```

**Note:** SCPs applied to OUs will block deletion of some resources. You may need to manually detach SCPs in the AWS console first.

---

## Troubleshooting

### "Error: You do not have permission to perform..."

- Check IAM role has `organizations:*` and security service permissions
- Verify credentials are correct: `aws sts get-caller-identity`

### CloudTrail not logging

- Check S3 bucket policy allows `cloudtrail.amazonaws.com`
- Verify bucket exists and is in the same region

### Security Hub findings not aggregating

- Ensure member accounts are in the Workloads OU
- GuardDuty must be enabled in member accounts first
- Wait 5–10 minutes for findings to aggregate

### Identity Center: "No permission set found"

- Ensure Identity Center is enabled: `aws sso list-instances`
- Create permission sets in the aggregator (security) account
- Verify IAM Identity Center instance ARN matches in module variables

---

## Cost Optimization

### Monthly Cost Model (3 accounts, us-east-1)

| Service | Monthly Cost | Notes |
|---------|-------------|-------|
| CloudTrail | $2 | Organization trail |
| S3 (CloudTrail logs) | $0.50–$5 | Depends on API volume |
| GuardDuty | $30–$50 | ~$0.30–$1.50/million events |
| Security Hub | $30 | Fixed per aggregator account |
| SNS (alerts) | <$1 | Minimal |
| CloudWatch Logs | $5–$15 | 30-day retention |
| IAM Identity Center | Free | Up to 100 users |
| **Total** | **$70–$100/month** | For 3-account org |

### Ways to Reduce Cost

1. **Reduce CloudWatch retention:** Change `cloudwatch_retention_days = 7` (from 30)
2. **Disable S3 Lifecycle:** Remove Glacier transition (saves $$ on storage, loses archival)
3. **Disable Data Events in GuardDuty:** Set `event_selector.read_write_type = "Write"` (fewer logs)
4. **Use AWS Config only on security-critical resources:** Tag-based filtering

---

## Next Steps

After deployment:

1. **Subscribe to SNS topics** for alerts
2. **Set up PagerDuty/Slack integration** for critical findings
3. **Run compliance report:** `aws securityhub get-compliance-summary`
4. **Invite team members** to Identity Center
5. **Test SSO login** with a team member
6. **Review findings** weekly; tune Security Hub filters as needed

---

## References

- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/best-practices.html)
- [Security Hub User Guide](https://docs.aws.amazon.com/securityhub/latest/userguide/)
- [GuardDuty Finding Types](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-active.html)
- [IAM Identity Center + Entra ID](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html)
