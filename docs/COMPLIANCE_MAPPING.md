# Compliance Mapping: FCA Control Areas → Landing-Zone Design

## What this document is

This is a **design reference**, not a compliance attestation. It maps the control areas an FCA-regulated fintech has to think about onto the specific Terraform resources in this landing zone, and shows how the design would satisfy each one.

It is written as a learning and design exercise. It is **not** evidence of a certified or audited environment, and it should not be read as a claim that this repository is FCA-compliant. Where a control is deployed and evidenced versus only written as code, that distinction is called out explicitly — see the status column in each section and the summary table at the end.

**Deployment status (important context for everything below):** only the single-account security stack from this landing zone has been deployed live and evidenced — CloudTrail, GuardDuty, Security Hub, the logging S3 bucket, and IAM Identity Center (see `docs/evidence/live-deployment/`). The multi-account Organizations layer — the OUs and SCPs that several controls below depend on — is written and validated as Terraform but was **not** deployed (a single test account cannot form an Organization). Controls that rely on the Organizations layer are therefore **design, not deployed**, and are marked as such.

---

## FCA Control Areas & How the Design Maps

### 1. Segregated Environments (Dev/Staging/Production)

**Control area:** Separate infrastructure for development, testing, and production so code changes cannot affect live customers.

| Component | Design | Resource | Status |
|-----------|---|---|---|
| Environment isolation | AWS Organizations OUs (Security, SharedServices, Workloads) | `modules/organizations/main.tf` | **Coded, not deployed** |
| Hard account boundaries | Separate AWS accounts per OU | `modules/organizations/outputs.tf` | **Coded, not deployed** |
| Policy enforcement | SCPs applied at OU level | `modules/organizations/main.tf` | **Coded, not deployed** |

*How it would work:* a developer in a dev account could not reach staging/prod, because the OU structure and SCPs would block it even if account access existed. This depends on the Organizations layer, which is written but not stood up — so this is a design, validated by `terraform plan`, not a running control.

---

### 2. Immutable Audit Trail (Non-Repudiation)

**Control area:** User actions and API calls logged, immutable, and tamper-evident.

| Component | Design | Resource | Status |
|-----------|---|---|---|
| CloudTrail logging | Trail feeding a central bucket | `modules/security-logging/main.tf` | **Deployed & evidenced** (single account) |
| Immutable storage | S3 versioning + restrictive bucket policy | `modules/security-logging/main.tf` | **Deployed & evidenced** |
| Log integrity | `log_file_validation = true` | `modules/security-logging/main.tf` | **Deployed & evidenced** |
| Access control | Bucket policy restricts writes to the CloudTrail service | `modules/security-logging/main.tf` | **Deployed & evidenced** |

*Note:* in the deployed single-account form, this is a standard (not organization-wide) trail. `is_organization_trail = true` is set in code but only takes effect once the Organizations layer is deployed.

---

### 3. Complete API Audit Trail

**Control area:** Every API call from every account logged.

| Requirement | Design | Resource | Status |
|---|---|---|---|
| All accounts logged | Organization CloudTrail (`is_organization_trail = true`) | security-logging | **Coded, not deployed** (needs Organizations) |
| All regions logged | Multi-region trail (`is_multi_region_trail = true`) | security-logging | **Deployed** (single account) |
| All event types | Management + data events | security-logging | **Deployed** |
| Global services | `include_global_service_events = true` | security-logging | **Deployed** |

*The "every account" part is design* — it activates when the org trail is deployed. Multi-region and event coverage are live in the deployed account.

---

### 4. Least-Privilege Access Control

**Control area:** No standing admin access; access time-limited and audited.

| Control | Design | Resource | Status |
|---|---|---|---|
| Permission sets | Admin, Developer, SecurityLead roles | `modules/iam-identity-center/main.tf` | **Deployed & evidenced** |
| Developer restrictions | Explicit Deny on `iam:*`, `guardduty:*`, `securityhub:*` | `modules/iam-identity-center/main.tf` | **Deployed** |
| Session limits | 4–8h session duration | `modules/iam-identity-center/main.tf` | **Deployed** |
| Admins only in non-prod | Documented process | DEPLOYMENT.md | **Documented, manual** |

*How it works:* even with console access, a developer's permission set denies modification of security services, and sessions are time-bound.

---

### 5. Continuous Threat Monitoring

**Control area:** Automated detection of anomalous behaviour with alerting, no manual log review.

| Component | Design | Resource | Status |
|---|---|---|---|
| GuardDuty detector | ML-based threat detection on CloudTrail + VPC flow logs | `modules/guardduty/main.tf` | **Deployed & evidenced** |
| Security Hub aggregator | Central findings view | `modules/security-hub/main.tf` | **Deployed & evidenced** |
| Automated alerting | HIGH/CRITICAL → EventBridge → SNS | `modules/security-hub/main.tf` | **Deployed** |
| CloudWatch alarms | Alarm on critical-finding count | `modules/security-hub/main.tf` | **Deployed** |

*In the deployed single account this runs for that account; cross-account aggregation depends on the Organizations layer.*

---

### 6. Compliance Standards Validation

**Control area:** Demonstrable adherence to a recognised framework (CIS, PCI-DSS, etc.).

| Standard | Design | Resource | Status |
|---|---|---|---|
| CIS AWS Foundations | Enabled in Security Hub | `modules/security-hub/main.tf` | **Deployed** |
| PCI DSS | Configurable (optional) | `modules/security-hub/main.tf` | **Coded, optional** |
| Automated assessment | Security Hub runs checks | AWS managed | **Deployed** |

*The CIS standard was enabled on the deployed account; Security Hub reports a compliance score against it.*

---

### 7. Segregation of Duties

**Control area:** Security team cannot modify applications; developers cannot disable security controls.

| Boundary | Design | Resource | Status |
|---|---|---|---|
| Developer cannot touch security services | Permission-set Deny on GuardDuty/Security Hub/Config | `modules/iam-identity-center/main.tf` | **Deployed** |
| Security team limited to read-only + security tools | Separate SecurityLead permission set | `modules/iam-identity-center/main.tf` | **Deployed** |
| No single person approves + deploys | Manual PR approval before apply | `.github/workflows/plan.yml` | **In the pipeline** |

---

### 8. Change Control & Audit Trail

**Control area:** Every infrastructure change reviewed, approved, and logged.

| Layer | Design | Status |
|---|---|---|
| Infrastructure code | Git commit history | **In use** |
| Code review | GitHub PR approval | **In the pipeline** |
| Deployment | GitHub Actions logs each apply with user + timestamp | **In use** |
| Resource changes | CloudTrail captures API calls | **Deployed** (single account) |

---

## Deployed vs Design — Summary

| # | Control area | Deployed & evidenced? |
|---|---|---|
| 1 | Segregated environments (OUs/SCPs) | ❌ Coded, not deployed (needs Organizations) |
| 2 | Immutable audit trail | ✅ Yes (single-account form) |
| 3 | Org-wide API trail | ⚠️ Partial — multi-region live; org-wide is coded |
| 4 | Least-privilege access | ✅ Yes |
| 5 | Threat monitoring | ✅ Yes (single account) |
| 6 | CIS standards validation | ✅ Yes |
| 7 | Segregation of duties | ✅ Yes (permission sets); ⚠️ cross-account needs Organizations |
| 8 | Change control | ✅ Yes |

---

## CIS AWS Foundations — Control Coverage (design)

| CIS Control | AWS Service | Module | Status |
|---|---|---|---|
| 1.1 – MFA enabled | IAM Identity Center | iam-identity-center | Configured (manual Entra ID setup) |
| 2.1 – CloudTrail enabled | CloudTrail | security-logging | Deployed (all regions, single account) |
| 2.2 – CloudTrail logs immutable | S3 | security-logging | Deployed (versioning, bucket policy) |
| 2.3 – CloudTrail log integrity | CloudTrail | security-logging | Deployed (log file validation) |
| 4.1 – SSO enabled | Identity Center | iam-identity-center | Deployed |
| 4.2 – MFA on console | Identity Center | iam-identity-center | Configured (Entra ID) |
| 4.4 – Unused credentials removed | Manual process | — | Documented, not automated |
| 5.1 – CloudTrail logs monitored | CloudWatch Logs | security-logging | Deployed (metric filters) |
| 5.2 – Config enabled | — | — | Not in scope (adds cost) — reference only |
| 6.1 – GuardDuty enabled | GuardDuty | guardduty | Deployed |

---

## Honest Gaps

- **Multi-account deployment** — the OUs/SCPs are written and plan-validated but not stood up; a single test account cannot form an Organization. Several controls above are therefore design, not running.
- **Data residency** — UK-only data residency is not enforced in this build.
- **Encryption in transit** — TLS is used but not explicitly documented per-service.
- **Backup / disaster recovery** — see `DEPLOYMENT.md` and `runbooks/DR.md`; DR timings are targets, not tested.
- **Third-party / vendor risk** — no vendor-integration controls in scope.

---

## How to read this as a portfolio piece

This landing zone is a **design and single-account deployment** demonstrating the AWS building blocks an FCA-regulated fintech would use: multi-account structure with SCP guardrails, organisation-wide logging, automated threat detection, least-privilege SSO, and code-based change control. The security stack was deployed live and evidenced; the multi-account layer is written and validated as Terraform. It shows the reasoning and the implementation approach — it is not, and does not claim to be, a certified or audited compliance environment.
