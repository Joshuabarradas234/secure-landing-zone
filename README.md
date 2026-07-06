# Secure Multi-Account AWS Landing Zone & DevSecOps Platform

## Live Deployment

I deployed the security stack to a real AWS account on 6 July 2026 to confirm it actually works, captured the evidence, then tore it down with `terraform destroy`.

`terraform apply` stood up 13 resources in about a minute:

- CloudTrail logging across all regions into an encrypted, versioned S3 bucket
- GuardDuty running as the threat-detection layer
- Security Hub with the AWS Foundational Security Best Practices and CIS AWS Foundations benchmarks switched on
- An SNS + EventBridge pipeline to route findings to alerts

Screenshots and notes are in [docs/evidence/live-deployment/](docs/evidence/live-deployment/).

One thing worth being straight about: I ran this in a single account, so it proves the security services deploy and run — not the full multi-account Organizations setup. A lone test account can't really create an Organization to deploy into itself, so that layer is covered by `terraform validate` rather than a live run. Everything else here was genuinely deployed, checked in the console, and destroyed afterwards so it isn't sitting there costing money.

---

## Overview

A multi-account AWS landing zone foundation built as reusable Terraform, with a GitHub Actions CI pipeline. It codifies the security baseline a regulated fintech would need: account segregation, centralised audit logging, threat detection, and least-privilege access.

**Status: honest 8/10 portfolio build**

- ✅ Six Terraform modules (Organizations, Security Hub, GuardDuty, CloudTrail/logging, Identity Center, networking) — real resources, not stubs
- ✅ Security stack deployed to live AWS and verified, then destroyed (see above)
- ✅ GitHub Actions CI (`terraform fmt`, `validate`, `plan`)
- ✅ Deployment guide, cost model, compliance mapping, DR runbook, and multi-region plan
- ⚠️ Multi-account Organizations layer is `terraform validate`-verified but not deployed live (needs a real AWS Organization)
- ⚠️ Entra ID federation is documented, not Terraformed (external identity provider)

---

## The Business Problem

NovaBridge Financial — a UK fintech entering FCA (Financial Conduct Authority) regulation — was running all workloads in a single AWS account with ad-hoc IAM policies and no change control. FCA audit requires environment segregation (dev/staging/prod), complete audit trails, least-privilege access, and continuous compliance monitoring. Without these controls, their regulatory application would fail.

Secondary problem: developers with elevated permissions could inadvertently modify production resources. There was no hard blast-radius boundary.

**Solution:** a multi-account landing zone with SCPs, centralised logging, threat detection, and federated identity — all as version-controlled Terraform.

(NovaBridge is a fictional scenario used to frame the design. It is not a real client.)

---

## What This Achieves

| Control | How | Status |
|---------|-----|--------|
| **Account isolation** | SCPs at OU level (above IAM) | Terraform in `modules/organizations` — validated, not deployed live |
| **Centralised logging** | CloudTrail → encrypted S3 + CloudWatch Logs | Deployed live and verified (single account) |
| **Threat detection** | GuardDuty + Security Hub | Deployed live and verified (single account) |
| **Access control** | IAM Identity Center permission sets (Admin/Developer/SecurityLead) | Terraform in `modules/iam-identity-center` — validated, not deployed live |
| **Compliance visibility** | Security Hub AWS Foundational + CIS benchmarks + CloudWatch alarms | Standards deployed live and verified |
| **Infrastructure as Code** | Terraform modules — reusable, testable, version-controlled | `terraform validate` + `plan` green across all environments |

---

## Architecture

[![Architecture Diagram](./architecture.jpg)](./architecture.jpg)

**Read the full design reasoning:**
- [DECISION_RECORD.md](./DECISION_RECORD.md) — why each service was chosen over alternatives
- [DEPLOYMENT.md](./DEPLOYMENT.md) — step-by-step deployment instructions with validation

---

## Key Components (Terraform Modules)

| Module | Purpose | Files |
|--------|---------|-------|
| `modules/organizations/` | Multi-account structure + SCPs | main.tf, variables.tf, outputs.tf |
| `modules/security-logging/` | CloudTrail + S3 + lifecycle rules | main.tf, variables.tf, outputs.tf |
| `modules/security-hub/` | Aggregator + CIS standards + alarms | main.tf, variables.tf, outputs.tf |
| `modules/guardduty/` | Threat detection + SNS alerts | main.tf, variables.tf, outputs.tf |
| `modules/iam-identity-center/` | Permission sets (Admin/Dev/SecurityLead) | main.tf, variables.tf, outputs.tf |
| `modules/networking/` | VPC scaffold for workload accounts | main.tf, variables.tf, outputs.tf |

---

## Repository Structure

```
├── .github/
│   └── workflows/
│       ├── validate.yml      # fmt, validate, tfsec, checkov
│       └── plan.yml          # Terraform plan on PRs
├── terraform/
│   ├── modules/              # Reusable modules
│   │   ├── organizations/
│   │   ├── security-logging/
│   │   ├── security-hub/
│   │   ├── guardduty/
│   │   ├── iam-identity-center/
│   │   └── networking/
│   ├── environments/          # Account-specific deployments
│   │   ├── management/        # Organizations + SCPs
│   │   ├── security/          # Logging + Security Hub + GuardDuty
│   │   └── workload-base/     # VPC template
│   └── scripts/
│       └── validate.sh        # Local pre-commit checks
├── docs/
│   ├── evidence/
│   │   └── live-deployment/   # Screenshots from the live deploy of this repo
│   ├── decisions/             # Architecture decision records
│   ├── runbooks/              # DR runbook
│   ├── COST_MODEL.md
│   ├── COMPLIANCE_MAPPING.md
│   ├── MULTI_REGION.md
│   └── PERFORMANCE_BENCHMARKS.md
├── DEPLOYMENT.md              # Full deployment guide
├── DECISION_RECORD.md         # Design rationale
└── architecture.jpg           # High-level diagram
```

---

## Quick Start

### 1. Review & Validate (no AWS access needed)

```bash
cd terraform/environments/management
terraform init -backend=false
terraform validate

# Repeat for environments/security and environments/workload-base
```

### 2. Deploy to AWS (Management Account)

```bash
cd terraform/environments/management
terraform init
terraform plan    # Review SCP + OU creation
terraform apply   # Create Organizations structure
```

### 3. Deploy to AWS (Security Account)

```bash
cd terraform/environments/security
terraform init
terraform plan    # Review CloudTrail, Security Hub, GuardDuty
terraform apply   # Enable centralised logging & monitoring
```

**Full walkthrough:** See [DEPLOYMENT.md](./DEPLOYMENT.md)

---

## Evidence

Two kinds of evidence live in this repo:

**1. Live deployment of this repo's Terraform** — [docs/evidence/live-deployment/](docs/evidence/live-deployment/). This is the one that matters: I deployed the security stack from this code to a real account, captured console screenshots (CloudTrail, GuardDuty, Security Hub, S3), and destroyed it afterwards. See the [Live Deployment](#live-deployment) section above.

**2. Earlier console exploration** — [docs/evidence/](docs/evidence/) contains screenshots from earlier hands-on work with these AWS services (Organizations, CloudTrail, Security Hub, GuardDuty, Identity Center). They show the services this landing zone codifies, but are not proof of this repo's own deployment.

---

## Additional Documentation

- **[Cost Model](docs/COST_MODEL.md)** — monthly cost breakdown (~$70 baseline), scaling to 10 accounts, optimisation levers
- **[Compliance Mapping](docs/COMPLIANCE_MAPPING.md)** — how each control maps to FCA requirements and CIS benchmarks
- **[DR Runbook](docs/runbooks/DR.md)** — RTO/RPO targets and recovery procedures
- **[Multi-Region Strategy](docs/MULTI_REGION.md)** — passive-standby and active-active options
- **[Performance Benchmarks](docs/PERFORMANCE_BENCHMARKS.md)** — deployment timings and capacity planning

---

## What's Next

1. Deploy the full multi-account layer in a real AWS Organization (Organizations + SCPs live, not just validated)
2. Enable Entra ID federation (manual setup, documented in the Identity Center module)
3. Subscribe SNS topics to Slack/PagerDuty for alerts
4. Deploy workload VPCs using the `workload-base` module
5. Scale to 10+ accounts via `member_account_ids`

---

## Honest Scope

**Deployed live and verified:** CloudTrail, S3 logging, GuardDuty, Security Hub standards, SNS/EventBridge alerting (single account).

**Written and `terraform validate`-verified, not deployed live:** Organizations + SCPs, IAM Identity Center permission sets, workload networking.

**Deliberately out of scope:**
- AWS Control Tower automation (requires account-factory features)
- Bedrock AI automation for finding summarisation
- Multi-region failover (planned in [docs/MULTI_REGION.md](docs/MULTI_REGION.md), not built)
- Entra ID SAML federation (documented, not Terraformed — external IdP)

---

## Contact

Built by Joshua Barradas as a portfolio project. Feedback welcome via GitHub issues.
