# Decision Record — Secure Multi-Account AWS Landing Zone & DevSecOps Platform

**Project:** Secure Multi-Account AWS Landing Zone with DevSecOps & Amazon Bedrock AI Automation  
**Customer (Fictional):** NovaBridge Financial — UK fintech entering the FCA-regulated market  
**Author:** Joshua Barradas  
**Date:** May 2026  

---

## 1. Customer & Context

### Who is the customer?
NovaBridge Financial is a UK-based fintech startup preparing to launch a regulated payment processing product. They are entering FCA (Financial Conduct Authority) oversight, which requires documented controls, segregation of environments, audit trails for all infrastructure changes, and demonstrable data security practices. They are 35 staff, growing to 100 within 18 months.

### What business problem are they solving?
NovaBridge has been building in a single AWS account with ad-hoc IAM policies. As they approach FCA authorisation, their security posture is a blocker — auditors need to see: centralised logging, least-privilege access, change traceability, and continuous compliance monitoring. Without this foundation in place, their FCA application will fail on technical due diligence.

The secondary problem: developer velocity. Engineers are currently blocked by manual access requests and undocumented permissions. Every change carries risk because there's no change control process.

### What constraints are they operating under?
- **Regulatory:** FCA requires segregated environments (dev/staging/prod), complete audit trails (CloudTrail covering all accounts), encryption at rest and in transit, and access reviews.
- **Timeline:** FCA application is 90 days away. The foundation needs to be in place and evidenced before submission.
- **Budget:** Startup budget — £3,000–8,000/month for cloud infrastructure total. Security tooling needs to be proportionate.
- **Team:** Two platform engineers and one security lead. No dedicated SecOps team. Automation is essential — manual security reviews don't scale.
- **Future scale:** Architecture must support adding 10+ new AWS accounts as products multiply, without rebuilding from scratch.

---

## 2. Candidate Architectures

### Option A — AWS Organizations + Control Tower + Security Hub + GuardDuty *(chosen)*
Use AWS Organizations to create a multi-account structure. Control Tower to provision and govern accounts with guardrails (SCPs). Federated SSO via Azure Entra ID to IAM Identity Center. Centralised security visibility via Security Hub aggregating findings from GuardDuty, Inspector, and Macie across all accounts. DevSecOps pipeline with IaC (Terraform) + policy-as-code + supply-chain scanning.

### Option B — Single AWS account with strict IAM boundaries + Config rules
Stay in one account but enforce strict IAM permission boundaries, tag-based policies, and AWS Config rules for compliance checking. Simpler to set up, lower upfront cost.

### Option C — AWS Organizations with manual account setup (no Control Tower)
Use Organizations for account structure but configure each account manually rather than via Control Tower's automated guardrails. More flexibility over exact configuration, but significantly more operational work.

---

## 3. Chosen Design

**AWS Organizations → Control Tower → Security Hub (aggregator account) → individual workload accounts**, with Terraform IaC, federated SSO (Azure Entra ID → IAM Identity Center), and automated threat detection.

**Account structure:**
```
Management Account (root)
├── Security Account (centralised logging, Security Hub aggregator, GuardDuty master)
├── Shared Services Account (networking, DNS, shared tools)
└── Workload Accounts
    ├── Dev
    ├── Staging
    └── Production
```

---

## 4. Why I Chose Each AWS Service (Design Reasoning)

### AWS Organizations + Control Tower over single-account
The FCA requires demonstrated environment segregation — dev, staging, and production must be isolated with different access controls. In a single account, you can approximate this with IAM and resource tags, but an auditor can point to the fact that a developer with elevated permissions could, in theory, touch production resources. Separate accounts are a hard blast radius boundary. Control Tower automates the guardrail application (SCPs) across all accounts — without it, you'd manually apply the same policies to every new account, and drift would be inevitable.

### Service Control Policies (SCPs) via Control Tower over IAM alone
SCPs apply at the account level, above IAM. Even if an IAM admin inside a workload account tries to disable CloudTrail or create unencrypted S3 buckets, the SCP blocks it. IAM policies can be changed by someone with sufficient permissions within the account — SCPs cannot be overridden by the account itself. For a regulated environment, this is a non-negotiable control.

### IAM Identity Center (SSO) with Azure Entra ID over IAM users
NovaBridge already uses Microsoft Azure Entra ID for their corporate identity. Creating separate IAM users in each AWS account would mean duplicate identity management, separate passwords, and a security audit trail that doesn't connect to their HR onboarding/offboarding process. When a developer leaves, you'd need to remember to revoke access in every AWS account individually. With SSO federated from Entra ID, offboarding one user in Active Directory removes their access to all AWS accounts simultaneously. It also enforces MFA from the corporate identity provider.

### Security Hub as aggregator over individual account monitoring
With multiple AWS accounts, you'd otherwise need to log into each account to check GuardDuty findings. Security Hub with cross-account aggregation pulls all findings into the Security account, where the security lead has a single dashboard. Critical severity findings trigger SNS → email/Slack within minutes. Without aggregation, findings would sit unread in individual accounts.

### GuardDuty over manual CloudTrail analysis
GuardDuty uses ML to detect anomalous behaviour in CloudTrail, VPC flow logs, and DNS logs — things like an IAM credential being used from an unusual country, cryptocurrency mining activity, or reconnaissance API calls. Manually analysing CloudTrail for these patterns would require a full-time security analyst. GuardDuty runs continuously at ~$0.50–$3/day depending on log volume, far cheaper than analyst time.

### Terraform over AWS CloudFormation
The team already had Terraform experience. Terraform modules allow reusable patterns — provision a new workload account, apply the same module, and it inherits security baseline configuration automatically. CloudFormation StackSets can achieve similar multi-account deployment, but Terraform's HCL is more readable for a small team and integrates better with their existing CI/CD toolchain. The trade-off: state file management requires care (remote state in S3 with DynamoDB locking). This was accepted because the team was already familiar with it.

### Bedrock AI Automation (optional) for incident summarisation
Security Hub produces findings in structured JSON. Before Bedrock, the security lead would read raw findings and manually write incident reports. Bedrock (Claude model) can ingest a GuardDuty finding and produce a natural-language summary with recommended remediation steps. This isn't a security control — it's an ops efficiency tool. It reduces the time from "finding detected" to "incident report written" from 20 minutes to 2 minutes. It's optional and switched off by default; the architecture is secure without it.

---

## 5. Trade-off Scorecard

| Dimension | Option A: Orgs + Control Tower (chosen) | Option B: Single account | Option C: Orgs, manual |
|---|---|---|---|
| **FCA audit readiness** | High ✅ | Medium ⚠️ | High ✅ |
| **Blast radius isolation** | Hard boundary ✅ | Soft (IAM) ⚠️ | Hard boundary ✅ |
| **Setup time** | Medium (2–3 weeks) | Low (1 week) | High (4–6 weeks) |
| **Ongoing ops burden** | Low (automated guardrails) ✅ | Medium | High ❌ |
| **Cost** | Medium | Low | Medium |
| **Scales to 10+ accounts** | Yes ✅ | No ❌ | Yes ✅ |
| **Team fit (small team)** | High ✅ | High ✅ | Low ❌ |

---

## 6. Cost Model

**Assumptions:** 3-account structure (Management, Security, 1 Workload), eu-west-2 (London), moderate log volume.

| Service | Cost basis | Monthly estimate |
|---|---|---|
| Control Tower | Free (pay for underlying services) | £0 |
| AWS Config (all accounts) | $0.003/configuration item recorded | £30–80 |
| CloudTrail (org trail) | $2/100k events after free tier | £20–50 |
| Security Hub | $0.0010/finding ingested after free tier | £15–40 |
| GuardDuty (all accounts) | $0.50–$4/day per account (volume-based) | £45–130 |
| Inspector | $0.11/instance-month (EC2) | £10–30 |
| IAM Identity Center | Free | £0 |
| S3 (log storage, 90-day retention) | $0.023/GB/month | £20–60 |
| **Estimated total** | | **£140–390/month** |

**Top 3 cost drivers:**
1. GuardDuty — scales with log volume and number of accounts
2. CloudTrail + Config — scales with API call and resource change volume
3. S3 log storage — scales with retention period

**At 10 accounts:** Roughly 3× current cost as GuardDuty and Config scale per account. Mitigation: centralise findings aggregation, reduce Config recording scope to only security-relevant resource types.

---

## 7. At 10× Scale (10+ accounts, 500+ engineers)

**What breaks first:** Manual account provisioning, even with Control Tower, becomes a bottleneck. The Security Hub aggregator's finding volume becomes harder to triage manually.

**What I'd change at 10× scale:**

1. **Account Vending Machine.** Build a self-service portal (or Service Catalog product) where a team can request a new AWS account, and automation provisions it with all guardrails, tags, and baseline config in under 30 minutes. At 10+ accounts, manual provisioning via Console is too slow.

2. **Security Hub + EventBridge + Lambda for automated triage.** Route CRITICAL severity findings through EventBridge to a Lambda that auto-creates an incident ticket in Jira/PagerDuty. Remove the human from the initial triage loop.

3. **Centralised Firewall Manager.** At 10+ accounts, managing VPC security groups individually drifts. AWS Firewall Manager lets you define network security policies centrally and enforce them across all accounts automatically.

4. **Cost Allocation Tags enforced via SCP.** At scale, cost attribution becomes a governance problem. Enforce mandatory tagging (team, environment, cost-centre) via SCP so FinOps can allocate costs automatically.
