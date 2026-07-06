# Runbooks

Operational playbooks for incident response and recurring security operations.
These are written to be usable by someone new joining the team.

## How to read these
Each runbook follows the same structure:
1. Trigger / Detection
2. Triage (confirm scope + severity)
3. Containment (stop the bleeding)
4. Eradication / Fix
5. Recovery
6. Validation
7. Lessons learned + follow-ups

## Runbook index (add as you create them)
- `RB-001-guardduty-triage.md` (placeholder)
- `RB-002-securityhub-investigation.md` (placeholder)
- `RB-003-iam-key-exposure.md` (placeholder)
- `RB-004-s3-public-access.md` (placeholder)

## Automation note
Where possible, steps should reference:
- log sources (CloudTrail/Config/VPC Flow Logs)
- which account to use (Management/Security/Workloads)
- which tool runs the query (Security Lake, SIEM, Athena, etc.)

