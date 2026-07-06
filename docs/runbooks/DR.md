# Disaster Recovery Procedures

## RTO/RPO Targets

| Component | RTO | RPO | Recovery Method |
|-----------|-----|-----|---|
| **CloudTrail logs (S3 bucket)** | 1 hour | 5 minutes | S3 versioning restore |
| **Security Hub findings** | 2 hours | N/A | Redeploy from Terraform, re-link accounts |
| **GuardDuty detector** | 1 hour | 0 | Redeploy from Terraform |
| **Management account (OUs/SCPs)** | 4 hours | 0 | Terraform apply from state backup |
| **Security account** | 4 hours | 0 | Terraform apply from state backup |
| **Workload account VPCs** | 8 hours | varies | Per-account Terraform apply |

**Key Insight:** All RTO/RPO targets assume Terraform state is recoverable from S3 backup. See "State Backup & Recovery" below.

---

## Disaster Scenarios & Step-by-Step Recovery

### Scenario 1: S3 CloudTrail Bucket Accidentally Deleted

**Symptoms:**
- CloudTrail stops logging
- CloudWatch alarm triggers: "CloudTrail no longer writing logs"
- Logs are missing for the past hour

**Root Cause:** Account admin accidentally runs `aws s3 rm s3://bucket --recursive`

**Recovery (30 minutes):**

#### Step 1: Check S3 Bucket State (2 minutes)
```bash
# List all versions of the bucket (including deleted)
aws s3api list-object-versions \
  --bucket your-cloudtrail-logs-bucket \
  --query 'Versions[?Size > `0`]' | head -20
```

If versions exist → bucket wasn't permanently deleted, only cleared.

#### Step 2: Restore from Versioning (5 minutes)
```bash
# Restore most recent version of each log file
aws s3api list-object-versions \
  --bucket your-cloudtrail-logs-bucket \
  --output json | jq -r '.Versions[0:10][] | "\(.Key) \(.VersionId)"' > versions.txt

# Restore in parallel
cat versions.txt | xargs -P 5 -I {} bash -c '
  KEY=$(echo {} | cut -d" " -f1)
  VERSION=$(echo {} | cut -d" " -f2)
  aws s3api copy-object \
    --copy-source "your-bucket/$KEY?versionId=$VERSION" \
    --bucket your-cloudtrail-logs-bucket \
    --key "$KEY"
'
```

#### Step 3: Verify Recovery (3 minutes)
```bash
# Check object count
aws s3 ls s3://your-cloudtrail-logs-bucket --recursive --summarize

# Expected: 50-100 objects (one per account per region per day)
```

#### Step 4: Redeploy Bucket via Terraform (10 minutes)
```bash
cd terraform/environments/security

# Show what will be recreated
terraform plan -target=aws_s3_bucket.cloudtrail_logs

# Reapply
terraform apply -target=aws_s3_bucket.cloudtrail_logs

# Verify CloudTrail is logging again
aws cloudtrail describe-trails --region us-east-1 | grep LogFileValidationEnabled
```

**Total Recovery Time:** ~30 minutes
**Data Lost:** Logs for ~1 hour (what was written during outage, then deleted)

---

### Scenario 2: Security Hub Account Compromised (Unauthorized IAM Activity)

**Symptoms:**
- GuardDuty alert: "Unusual IAM activity in security account"
- You see 10+ CloudTrail events from unknown user
- Someone may have created a backdoor IAM user

**Root Cause:** Weak MFA, compromised credentials, or exposed API key

**Recovery (2-4 hours):**

#### Step 1: Isolate Account Immediately (5 minutes)
```bash
# Remove this account's findings from aggregation (don't break other accounts)
aws securityhub disassociate-from-master-account --region us-east-1

# This stops it from sending/receiving findings (still running locally)
```

#### Step 2: Credential Rotation (10 minutes)
```bash
# Revoke all active access keys for human users
aws iam list-access-keys --user-name your-admin-user | jq -r '.AccessKeyMetadata[] | .AccessKeyId' | xargs -I {} aws iam delete-access-key --access-key-id {}

# Generate new credentials and distribute securely
aws iam create-access-key --user-name your-admin-user
```

#### Step 3: Audit Recent Activity (15 minutes)
```bash
# Look for unauthorized resources created in last 2 hours
aws ec2 describe-instances --filters "Name=launch-time,Values=2026-07-06T*" --output table

# Look for unauthorized IAM users
aws iam list-users --query 'Users[?CreateDate > `2026-07-06T00:00:00+00:00`]'

# Look for security group changes
aws ec2 describe-security-groups --filters "Name=group-name,Values=unauthorized-*"
```

#### Step 4: Remove Unauthorized Resources (20 minutes)
```bash
# Example: Delete compromised IAM user
aws iam delete-user --user-name attacker-user

# Example: Deauthorize security keys
aws iam delete-access-key --access-key-id AKIAIOSFODNN7EXAMPLE

# Example: Revert security group changes
aws ec2 revoke-security-group-ingress --group-id sg-xxx --ingress-rules ...
```

#### Step 5: Redeploy Security Account from Terraform (30 minutes)
```bash
cd terraform/environments/security

# Show all changes that will be applied
terraform plan

# Note any differences (they may show attacker modifications)
# Example: Extra IAM role, modified bucket policy, etc.

# Apply to restore clean state
terraform apply

# Terraform will remove anything not in code (attacker resources)
```

#### Step 6: Re-enable Security Hub Aggregation (10 minutes)
```bash
# Associate this account back as aggregator
aws securityhub associate-admin-account --admin-account-id <YOUR_ACCOUNT_ID>

# Link member accounts again (if they were unlinked)
for account_id in 123456789012 210987654321; do
  aws securityhub create-members --account-details AccountId=$account_id,Email=account-$account_id@company.com
  aws securityhub invite-members --account-ids $account_id
done
```

**Total Recovery Time:** ~2 hours
**Data Lost:** Findings for ~30 minutes (during mitigation)
**Post-Incident:** Review CloudTrail logs for last 24 hours, change all MFA devices, review all permission sets

---

### Scenario 3: Organizations Structure Corrupted (OUs Deleted or SCPs Removed)

**Symptoms:**
- Workload accounts no longer showing SCPs applied
- `terraform plan` shows drift: OUs missing or SCPs detached
- Developers can now delete CloudTrail resources (SCP was removed)

**Root Cause:** Someone accidentally deleted OU via AWS console, or manual API call modified OrgUnit

**Recovery (4-6 hours):**

#### Step 1: DO NOT Delete or Modify Anything (Assess First) (10 minutes)
```bash
# Show current state vs Terraform
cd terraform/environments/management

terraform plan

# This will show what's drifted. Example output:
# - module.organizations.aws_organizations_organizational_unit.workloads will be created
# - module.organizations.aws_organizations_policy_target.protect_services_workloads will be created
```

#### Step 2: Backup Current State (5 minutes)
```bash
# Export current organizations state
aws organizations list-organizational-units-for-parent --parent-id r-xyz > ou_backup.json

aws organizations list-policies --filter SERVICE_CONTROL_POLICY > scp_backup.json
```

#### Step 3: Review Terraform for Discrepancies (15 minutes)
```bash
# Look for resources that exist in console but not in code
# Example: 
# - OU named "Legacy" exists but isn't in terraform/modules/organizations/main.tf
# - SCP attached to root account but isn't in code

# Question: Should they be in code? If yes, add them. If no, they're unauthorized.
```

#### Step 4: Redeploy Organizations Structure (30 minutes)
```bash
cd terraform/environments/management

# This will:
# 1. Create missing OUs
# 2. Attach missing SCPs
# 3. Restore correct structure
terraform apply

# Verify SCPs are now enforced
aws organizations list-policies-for-target \
  --target-id ou-workloads \
  --filter SERVICE_CONTROL_POLICY
```

#### Step 5: Verify All Accounts See New SCPs (10 minutes)
```bash
# In each workload account, check SCP is applied
aws organizations list-policies-for-target \
  --target-id <WORKLOAD_ACCOUNT_ID> \
  --filter SERVICE_CONTROL_POLICY

# Should show all 3 SCPs from code:
# - deny-disable-cloudtrail
# - require-s3-encryption
# - protect-security-services
```

#### Step 6: Test SCP Enforcement (5 minutes)
```bash
# In a workload account, attempt to break SCP
# This SHOULD be denied:
aws s3 mb s3://test-bucket  # No encryption = denied by SCP

# Result: "An error occurred (AccessDenied) because the SCP does not allow this operation"
```

**Total Recovery Time:** ~4 hours
**Data Lost:** None (structure-only recovery)
**Post-Incident:** Review CloudTrail for who deleted OUs, review access logs, audit all account changes in last 24 hours

---

## Terraform State Backup & Recovery

### Automated Backup (Recommended)

Every night, back up Terraform state to immutable storage:

```bash
#!/bin/bash
# backup_tfstate.sh - Run daily via cron or Lambda

DATE=$(date +%Y%m%d)
BACKUP_BUCKET="your-backup-bucket"
TFSTATE_BUCKET="your-tfstate-bucket"

# Copy current state
aws s3 cp \
  s3://$TFSTATE_BUCKET/terraform.tfstate \
  s3://$BACKUP_BUCKET/terraform.tfstate.$DATE.backup \
  --sse AES256

# Verify backup
aws s3 ls s3://$BACKUP_BUCKET/terraform.tfstate.* | tail -5
```

### Manual Recovery (If State Corrupted)

```bash
# List all state backups
aws s3 ls s3://your-backup-bucket/ | grep terraform

# Restore from specific date
aws s3 cp \
  s3://your-backup-bucket/terraform.tfstate.20260705.backup \
  s3://your-tfstate-bucket/terraform.tfstate

# Terraform will now use the restored state
# Apply to bring live infrastructure to that state
cd terraform/environments/management
terraform apply  # Will modify only what's different
```

---

## Testing DR Procedures

### Monthly Checklist

- [ ] **Bucket versioning test:** Restore a log file from version history
- [ ] **Terraform state test:** Restore state from backup, verify `terraform plan` passes
- [ ] **SCP enforcement test:** Attempt to break an SCP policy, verify denial

### Quarterly Checklist

- [ ] **Full account rebuild:** Redeploy security account from Terraform to new region
- [ ] **Findings aggregation:** Break and restore Security Hub member account linking
- [ ] **Credential rotation:** Rotate all programmatic access keys

### Annual Checklist

- [ ] **Disaster simulation:** Take down security account entirely, recover from state
- [ ] **RTO measurement:** Time how long recovery actually takes
- [ ] **Documentation review:** Update this runbook with actual timings

---

## Emergency Contacts & Escalation

**AWS Support:** Create a business support plan (4-hour response time)
- During active breach, open TAC case
- Have AWS account IDs and resource ARNs ready

**Your Team:**
- **Terraform state owner:** Has access to backup S3 bucket
- **AWS Organization owner:** Can modify OUs + SCPs if Terraform role fails
- **Security lead:** Reviews logs and detects breach indicators

---

## What NOT to Do

- ❌ **Don't manually recreate resources** — Use Terraform instead (state stays clean)
- ❌ **Don't delete the state bucket** — You'll lose all recovery capability
- ❌ **Don't apply Terraform without reviewing plan** — `plan` first, always
- ❌ **Don't restore to production without testing** — Test recovery in dev first
- ❌ **Don't skip credential rotation after breach** — Rotate everything

---

## Summary

| Disaster | RTO | Recovery | Most Important Step |
|----------|-----|----------|---|
| **S3 bucket deleted** | 30 min | Restore from versioning | Check CloudTrail still running |
| **Account compromised** | 2 hours | Rotate creds, redeploy | Remove attacker resources first |
| **OUs deleted** | 4 hours | Terraform apply | Verify SCPs re-enforced on all accounts |

All recovery procedures assume Terraform state is accessible. Protect the state bucket like you'd protect your backup tapes.
