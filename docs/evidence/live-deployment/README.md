# Live Deployment Evidence

## Summary

The security services in this landing zone were **deployed to live AWS and verified working** on **July 6, 2026**, then torn down cleanly with `terraform destroy`.

**Account:** `664418992605` (personal test account)
**Region:** us-east-1 (N. Virginia)
**Deployment method:** `terraform apply` (13 resources created in ~1 minute)
**Teardown:** `terraform destroy` (13 resources destroyed, verified empty)

This proves the Terraform modules are not just syntactically valid — they deploy and run in real AWS.

---

## What Was Deployed

A single-account version of the landing zone's security stack (the multi-account Organizations layer requires an AWS Organization, which a single test account can't use — so this proves the security services work, which is the core of the platform):

| Service | Resource | Evidence |
|---------|----------|----------|
| **CloudTrail** | Multi-region trail → encrypted S3 | `02-cloudtrail-active.png` |
| **S3** | Versioned, encrypted log bucket | `05-s3-cloudtrail-bucket.png` |
| **GuardDuty** | Threat detection detector | `03-guardduty-enabled.png` |
| **Security Hub** | AWS Foundational + CIS standards | `04-securityhub-standards.png` |
| **SNS + EventBridge** | Findings alerting pipeline | (in terraform apply output) |

Terraform apply output: `01-terraform-apply-complete.png`

---

## Screenshots

### 1. Terraform Apply — 13 Resources Created
`01-terraform-apply-complete.png`

Shows `Apply complete! Resources: 13 added, 0 changed, 0 destroyed` with the output values (account ID, CloudTrail name, GuardDuty detector ID, Security Hub ARN, SNS topic ARN).

### 2. CloudTrail — Multi-Region Trail Active
`02-cloudtrail-active.png`

Shows the `landing-zone-demo-trail` as a multi-region trail logging to the S3 bucket.

### 3. GuardDuty — Detector Enabled
`03-guardduty-enabled.png`

Shows the GuardDuty summary dashboard with the detector active and monitoring (0 findings — a clean environment, as expected for a fresh deployment).

### 4. Security Hub — Standards Enabled
`04-securityhub-standards.png`

Shows Security Hub with **AWS Foundational Security Best Practices v1.0.0** and **CIS AWS Foundations Benchmark v1.2.0** enabled. Scores show 0/0 because compliance checks run over the following hours.

### 5. S3 — Encrypted CloudTrail Bucket
`05-s3-cloudtrail-bucket.png`

Shows the `landing-zone-demo-cloudtrail-664418992605` bucket in us-east-1.

---

## Honesty Notes

- This was deployed in a **single account**, not a full multi-account Organization. The Organizations/SCP layer is validated with `terraform validate` but was not deployed live (a test account can't create an Organization to deploy into itself meaningfully, and doing so has cleanup friction).
- The deployment ran for a short period (minutes) for evidence capture, then was destroyed. It is **not currently running**.
- GuardDuty and Security Hub showed 0 findings because the environment was clean and freshly deployed — compliance checks and threat detection populate over hours/days, not seconds.
- The `terraform destroy` was verified: `aws guardduty list-detectors` returned an empty list, confirming teardown.

---

## Reproducing This

The standalone deployment file used for this evidence is a single-account adaptation of the modules in `terraform/modules/`. To reproduce:

1. Configure AWS CLI with credentials for a test account
2. `terraform init`
3. `terraform apply` (creates 13 resources)
4. Capture evidence from the AWS Console
5. `terraform destroy` (removes everything)

**Cost:** ~£1-2 for a same-day deploy-and-destroy cycle (well within GuardDuty/Security Hub free-tier for a new account).
