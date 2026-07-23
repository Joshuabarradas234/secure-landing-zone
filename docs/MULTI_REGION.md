# Multi-Region Strategy & Architecture

## Current State (Single Region)

**Deployed in:** `us-east-1` (N. Virginia) — the single-account security stack.

**Resilience:** single-region; if us-east-1 failed, the deployed stack would be offline. The design below is the plan for adding regional resilience; it is not yet built.

**Note:** single-region is a common starting posture; multi-region resilience would be added as the design below describes.

**Cost:** $70/month (baseline)

---

## Multi-Region Target Architecture

### Phase 0: Current State (Today)
```
┌─────────────────────┐
│   us-east-1         │
│  (Primary)          │
│  CloudTrail         │
│  Security Hub       │
│  GuardDuty          │
│  Logging            │
└─────────────────────┘
     ↓
  All findings
  All logs
```

### Phase 1: Passive Standby (Months 3-6, Recommended Next Step)
```
┌─────────────────────┐         ┌──────────────────────┐
│   us-east-1         │         │   us-west-2          │
│  (Primary)          │    ←→   │  (Standby/Read-Only) │
│  CloudTrail (all)   │         │                      │
│  Security Hub       │         │  Security Hub        │
│  GuardDuty          │         │  GuardDuty detector  │
│  Logging            │         │  (mirrored)          │
└─────────────────────┘         └──────────────────────┘
     ↓                                   ↓
  Primary logs                      Replica logs
  Primary findings                  Replica findings
                                    (read-only)
  
Manual failover: 2 hours
Cost increase: +50% ($105/month)
```

### Phase 2: Active-Active (Months 6-12, Advanced)
```
┌─────────────────────┐         ┌──────────────────────┐
│   us-east-1         │         │   us-west-2          │
│  (Active)           │    ↔→    │  (Active)            │
│  CloudTrail         │         │  CloudTrail          │
│  Security Hub       │         │  Security Hub        │
│  GuardDuty          │         │  GuardDuty           │
└─────────────────────┘         └──────────────────────┘
     ↓                                   ↓
  Findings  ←→  Global Aggregator  ←→  Findings
  Logs      ←→  Central Dashboard  ←→  Logs
  
Automatic failover: <30 minutes
Cost increase: +100% ($140/month)
```

---

## Phase 1: Passive Standby Implementation

**Timeline:** ~4 hours to spec, ~4-6 hours to implement

### Architecture Details

**What replicates:**
- ✅ Security Hub detector → runs in us-west-2
- ✅ GuardDuty detector → runs in us-west-2
- ✅ CloudTrail logs → replicated to us-west-2 S3 bucket
- ✅ Permission sets → replicated manually (one-time setup)

**What stays primary:**
- Management account (OUs, SCPs) — stay in us-east-1
- Entra ID federation — single identity source

### Step-by-Step Implementation

#### Step 1: Create Secondary S3 Bucket for Logs (20 minutes)

```hcl
# Add to modules/security-logging/main.tf

resource "aws_s3_bucket" "cloudtrail_logs_west" {
  provider = aws.west
  bucket   = "${var.name_prefix}-cloudtrail-logs-west-${data.aws_caller_identity.current.account_id}"
  
  tags = var.tags
}

# Enable replication from us-east-1 → us-west-2
resource "aws_s3_bucket_replication_configuration" "cloudtrail_logs" {
  role = aws_iam_role.s3_replication.arn

  rule {
    id       = "replicate-cloudtrail"
    status   = "Enabled"
    priority = 1

    destination {
      bucket       = aws_s3_bucket.cloudtrail_logs_west.arn
      storage_class = "STANDARD"
    }

    filter {
      prefix = "AWSLogs/"
    }
  }
}
```

**Cost:** +$0.10/month (minimal S3 storage)

#### Step 2: Deploy GuardDuty Detector in us-west-2 (15 minutes)

```hcl
# Add to modules/guardduty/main.tf

resource "aws_guardduty_detector" "west" {
  provider = aws.west
  enable   = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }

  tags = var.tags
}
```

**Cost:** +$15/month (secondary detector)

#### Step 3: Deploy Security Hub in us-west-2 (15 minutes)

```hcl
# Add to modules/security-hub/main.tf

resource "aws_securityhub_hub" "west" {
  provider                = aws.west
  enable_default_standards = var.enable_default_standards

  tags = var.tags
}

# Link to us-east-1 findings (read-only)
resource "aws_securityhub_finding_aggregator" "west" {
  provider = aws.west
  
  account_aggregation_sources {
    account_ids = var.member_account_ids  # Same accounts
  }
  
  all_regions = true
}
```

**Cost:** +$30/month (secondary Security Hub)

#### Step 4: Update Terraform to Deploy Both Regions (10 minutes)

```hcl
# Add to environments/security/main.tf

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

module "security_logging" {
  source = "../../modules/security-logging"
  # ... (existing config)
}

module "guardduty_west" {
  source = "../../modules/guardduty"
  
  providers = {
    aws = aws.west
  }

  name_prefix = "${local.name_prefix}-west"
  # ... other config
}

module "security_hub_west" {
  source = "../../modules/security-hub"
  
  providers = {
    aws = aws.west
  }

  name_prefix = "${local.name_prefix}-west"
  # ... other config
}
```

### Phase 1 Checklist

- [ ] S3 replication configured (logs flowing to us-west-2)
- [ ] GuardDuty detector running in us-west-2
- [ ] Security Hub running in us-west-2
- [ ] Member accounts added to us-west-2 aggregator
- [ ] Findings appear in us-west-2 dashboard
- [ ] Cost: ~$105/month (+50%)

### Phase 1 Failover Procedure (Manual, 2 hours)

If us-east-1 fails completely:

```bash
# 1. Promote us-west-2 to primary
aws securityhub update-organization-configuration \
  --region us-west-2 \
  --auto-enable

# 2. Redirect your monitoring to us-west-2 dashboard
# 3. Test that findings still appear
# 4. Notify team that you're operating from us-west-2

# 5. (When us-east-1 recovered)
# Resync from us-west-2 back to us-east-1
terraform apply -var "region=us-east-1"
```

---

## Phase 2: Active-Active Implementation (Advanced, 6+ Weeks Away)

**Timeline:** ~8-12 hours to implement (for experienced team)

### Architecture: Global Finding Aggregation

**Key idea:** Both regions collect findings independently, but one dashboard shows all findings from both regions.

```hcl
# New module: modules/global-aggregator/main.tf

resource "aws_securityhub_finding_aggregator" "global" {
  # In management account, aggregates from:
  # 1. us-east-1 findings
  # 2. us-west-2 findings
  
  account_aggregation_sources {
    all_regions = true  # Collects from all regions
    account_ids = [
      data.aws_caller_identity.current.account_id,
      # + all member accounts
    ]
  }
}
```

### Active-Active Trade-offs

| Aspect | Cost | Complexity | RTO |
|---|---|---|---|
| **Passive Standby** | +50% | Low | 2 hours |
| **Active-Active** | +100% | High | <30 min |

**Recommendation:** Do **Phase 1 only** unless you need <30 minute RTO. Cost/benefit doesn't justify Phase 2 for most startups.

---

## Multi-Region Failover Decision Tree

```
Incident in us-east-1?
├─ CloudTrail bucket down → Failover to us-west-2 logs (5 min)
├─ Security Hub down → Switch to us-west-2 dashboard (immediate)
├─ GuardDuty down → Check us-west-2 detector (immediate)
├─ Entire region down
│  ├─ Phase 1 (standby) → Manual failover (2 hours)
│  └─ Phase 2 (active-active) → Automatic (instant)
└─ Partial outage → Failover not needed, continue in us-east-1
```

---

## Cost Impact Summary

| Phase | Monthly Cost | RTO | Recommendation |
|-------|---|---|---|
| **Current (single region)** | $70 | Region failure = offline | ✅ Good for MVP |
| **Phase 1 (passive standby)** | $105 | 2 hours | ✅ Next step (month 3) |
| **Phase 2 (active-active)** | $140 | <30 min | ⚠️ Only if high availability required |

---

## When to Implement Each Phase

### Phase 1 (Passive Standby) is warranted when:
- The workload is in production with real users
- Availability requirements justify the added ~$35/month
- A regulator or customer SLA calls for regional resilience
- **Estimated effort:** ~8 hours (4 to spec, 4 to implement)

### Phase 2 (Active-Active) is warranted when:
- An SLA requires <30-minute RTO
- The organization runs 10+ accounts
- Users are spread across multiple regions
- **Estimated effort:** 20+ hours; complexity rises significantly

---

## Implementation Priority

**Now:** single-region is a reasonable posture for an MVP with no availability SLA.

**When in production with real users:** implement Phase 1 (passive standby).

**When an SLA requires sub-30-minute recovery:** consider Phase 2 (active-active).

---

## Terraform Changes Summary (Phase 1)

### Files to modify:

1. **modules/security-logging/main.tf** — Add S3 replication
2. **modules/guardduty/main.tf** — Add west provider + detector
3. **modules/security-hub/main.tf** — Add west provider + hub
4. **environments/security/main.tf** — Call modules with west provider
5. **environments/security/terraform.tfvars** — Add west region config

### Lines of code to add:
- ~50 lines for S3 replication
- ~30 lines for GuardDuty west
- ~30 lines for Security Hub west
- ~20 lines for provider config

**Total:** ~130 lines (manageable scope)

---

## Summary

The landing zone is currently single-region (`us-east-1`). This document sets out a two-phase plan for regional resilience:

- **Phase 1 — passive standby** (~$105/mo, ~2-hour manual failover): replicate CloudTrail logs to us-west-2 and run standby GuardDuty and Security Hub detectors there. The lower-effort, lower-cost step, and enough for most availability requirements.
- **Phase 2 — active-active** (~$140/mo, <30-min automatic failover): both regions active with a global finding aggregator. Higher complexity, justified only when an SLA genuinely requires sub-30-minute recovery.

For a single-region MVP the trade-off usually favours staying single-region until there is a real availability requirement; Phase 1 is the natural first move when that requirement appears. The Terraform changes for Phase 1 are scoped above at roughly 130 lines across four files, and are written here as a design — they have not been applied.
