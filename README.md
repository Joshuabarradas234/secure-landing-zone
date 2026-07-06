# Secure Multi-Account AWS Landing Zone & DevSecOps Platform

A multi-account AWS landing zone built as reusable Terraform, with a GitHub Actions CI pipeline. It codifies the security baseline a regulated fintech needs: account segregation via AWS Organizations and Service Control Policies, centralised audit logging with CloudTrail, managed threat detection with GuardDuty and Security Hub, and least-privilege access through IAM Identity Center.

The design is delivered as six composable Terraform modules with separate environment configurations for the management, security, and workload accounts, plus supporting documentation covering cost, compliance mapping, disaster recovery, multi-region strategy, and performance.

## Live deployment

The security stack was deployed to a real AWS account on 6 July 2026, verified in the console, and torn down with `terraform destroy`. A single `terraform apply` provisioned 13 resources in about a minute:

- CloudTrail logging across all regions into an encrypted, versioned S3 bucket
- GuardDuty as the managed threat-detection layer
- Security Hub with the AWS Foundational Security Best Practices and CIS AWS Foundations benchmarks enabled
- An SNS + EventBridge pipeline routing findings to alerts

Console screenshots and deployment notes are in [docs/evidence/live-deployment/](docs/evidence/live-deployment/).

This live run covered the security services in a single account. The multi-account Organizations and SCP layer is written as Terraform and verified with `terraform validate` — deploying it live requires an existing AWS Organization, which is documented in [DEPLOYMENT.md](./DEPLOYMENT.md). Entra ID federation is configured through the AWS console (external identity provider) and documented in the Identity Center module rather than managed in Terraform.

## Highlights

- Six Terraform modules (Organizations, Security Hub, GuardDuty, CloudTrail/logging, Identity Center, networking) — real resources across roughly 1,000 lines of HCL
- Security stack deployed to live AWS and verified, then destroyed
- GitHub Actions CI running `terraform fmt`, `validate`, and Checkov on every change
- Deployment guide, cost model, FCA compliance mapping, DR runbook, and multi-region strategy

---

## What This Achieves

| Control | How | Status |
|---------|-----|--------|
| **Account isolation** | SCPs at OU level (above IAM) | Terraform in `modules/organizations` — validated, not deployed live |
| **Centralised logging** | CloudTrail → encrypted S3 + CloudWatch Logs | Deployed live and verified (single account) |
| **Threat detection** | GuardDuty + Security Hub | Deployed live and verified (single account) |
| **Access control** | IAM Identity Center permission sets (Admin/Developer/SecurityLead) | Terraform in `modules/iam-identity-center` — validated, not deployed live |
| **Compliance visibility** | Security Hub AWS Foundational + CIS benchmarks; CloudWatch alarms defined in module | Standards deployed live and verified |
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
│       ├── validate.yml      # fmt, validate, checkov
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

**1. Live deployment of this repo's Terraform** — [docs/evidence/live-deployment/](docs/evidence/live-deployment/). This is the one that matters: the security stack in this repo was deployed to a real account, captured as console screenshots (CloudTrail, GuardDuty, Security Hub, S3), and destroyed afterwards. See the [Live deployment](#live-deployment) section above.

**2. Earlier console exploration** — [docs/evidence/](docs/evidence/) contains screenshots from earlier hands-on work with these AWS services (Organizations, CloudTrail, Security Hub, GuardDuty, Identity Center). They show the services this landing zone codifies, but are not proof of this repo's own deployment.

---

## Additional Documentation

- **[Cost Model](docs/COST_MODEL.md)** — monthly cost breakdown (~$70 baseline), scaling to 10 accounts, optimisation levers
- **[Compliance Mapping](docs/COMPLIANCE_MAPPING.md)** — how each control maps to FCA requirements and CIS benchmarks
- **[DR Runbook](docs/runbooks/DR.md)** — RTO/RPO targets and recovery procedures
- **[Multi-Region Strategy](docs/MULTI_REGION.md)** — passive-standby and active-active options
- **[Performance Benchmarks](docs/PERFORMANCE_BENCHMARKS.md)** — deployment timings and capacity planning

---

## Roadmap

1. Deploy the full multi-account layer in a real AWS Organization (Organizations + SCPs live, not just validated)
2. Enable Entra ID federation (console setup, documented in the Identity Center module)
3. Subscribe SNS topics to Slack/PagerDuty for alerts
4. Deploy workload VPCs using the `workload-base` module
5. Scale to 10+ accounts via `member_account_ids`

---

## Scope

**Deployed live and verified:** CloudTrail, S3 logging, GuardDuty, Security Hub standards, SNS/EventBridge alerting (single account).

**Written and `terraform validate`-verified, not deployed live:** Organizations and SCPs, IAM Identity Center permission sets, workload networking.

**Out of scope by design:**
- AWS Control Tower automation (requires account-factory features)
- Bedrock AI automation for finding summarisation
- Multi-region failover (planned in [docs/MULTI_REGION.md](docs/MULTI_REGION.md), not built)
- Entra ID SAML federation (documented, external identity provider — not managed in Terraform)

---

## Author

Built by Joshua Barradas. Feedback and questions welcome via GitHub issues.
