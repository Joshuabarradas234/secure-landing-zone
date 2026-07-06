# Cost Model: Secure Multi-Account AWS Landing Zone

## Monthly Cost Breakdown (3 Accounts)

| Service | Unit Cost | Volume | Monthly Cost | Notes |
|---------|-----------|--------|--------------|-------|
| **CloudTrail** | $2 flat | 1 org trail | $2.00 | Organization-wide trail, all regions |
| **S3 CloudTrail Logs** | $0.023/GB | 10GB/month | $0.25 | Typical API volume for 3 accounts |
| **GuardDuty** | $0.30/M events | ~1M events | $30.00 | ML-based threat detection |
| **Security Hub** | $30 flat | 1 aggregator | $30.00 | Aggregator account only |
| **CloudWatch Logs** | $0.50/GB ingested | 10GB/month | $5.00 | CloudTrail + GuardDuty logs |
| **SNS** | $0.50/M notifs | ~100K/month | <$1.00 | Alert routing |
| **IAM Identity Center** | Free | up to 100 users | $0.00 | No per-user cost |
| **VPC Flow Logs** | $0.10/GB | 1GB/month | $0.10 | Network traffic analysis |
| **Lambda (optional)** | $0.20/M invocations | ~50K/month | $0.10 | Finding processors (optional) |
| **Total** | | | **~$68.45/month** | |

## Cost Scaling Model

### At 5 Accounts (Dev, Staging, Prod, Shared Services, Security)

| Service | Scaling Factor | New Cost | Notes |
|---------|---|---|---|
| CloudTrail | same | $2.00 | Flat rate for org trail |
| GuardDuty | 2.5x | $75.00 | More accounts = more events |
| S3 CloudTrail | 1.5x | $0.35 | Slight increase in log volume |
| Everything else | same | ~$35.25 | Minimal change |
| **Total** | | **~$113/month** | +66% vs 3 accounts |

### At 10 Accounts (Full org with business units)

| Service | Scaling Factor | New Cost |
|---------|---|---|
| CloudTrail | same | $2.00 |
| GuardDuty | 5-8x | $150-240 | Significant volume increase |
| S3 CloudTrail | 2x | $0.50 |
| Security Hub | same | $30.00 |
| CloudWatch Logs | 2x | $10.00 |
| **Total** | | **~$193-283/month** | 3-4x vs 3 accounts |

## Cost per Account (Amortized)

| Scenario | Per-Account Cost | Notes |
|----------|---|---|
| 3 accounts | $22.82 each | Security + Shared Services + 1 Workload |
| 5 accounts | $22.60 each | More efficient (shared platform costs) |
| 10 accounts | $19.30-28.30 each | Depends on API activity |

**Insight:** Platform costs (CloudTrail, Security Hub) are fixed. GuardDuty scales with activity. At 10+ accounts, per-account cost decreases due to fixed cost amortization.

## Cost Optimization Levers

### High Priority (Save $5-15/month)

1. **Reduce CloudWatch retention** (30 days → 7 days)
   - **Savings:** $3.50/month
   - **Trade-off:** Lose 30-day history, keep 7-day operational visibility
   - **Recommendation:** Apply to dev/staging only; keep 30 days for prod

2. **GuardDuty: S3 + Kubernetes logs only** (disable EC2 logs)
   - **Savings:** ~$5-10/month
   - **Trade-off:** Miss anomalous EC2 behavior
   - **Recommendation:** Only if not running EC2 workloads

3. **Disable PCI DSS standard** (if not needed for compliance)
   - **Savings:** ~$5/month
   - **Trade-off:** No PCI validation
   - **Recommendation:** Remove if not FCA/PCI requirement

### Medium Priority (Save $2-5/month)

4. **SNS deduplication** (filter duplicate alerts)
   - **Savings:** <$1/month
   - **Trade-off:** Require manual filtering logic
   - **Recommendation:** Not worth the complexity

5. **Turn off VPC Flow Logs** in non-critical accounts
   - **Savings:** $0.10-0.30/month per account
   - **Trade-off:** Lose network visibility
   - **Recommendation:** Keep enabled for security account

### Low Priority (Save <$1/month)

6. **S3 Glacier transition** (keep current)
   - Already implemented (move to Glacier after 90 days)
   - No further optimization needed

## Monthly Cost Breakdown by Account Type

| Account | CloudTrail | GuardDuty | Security Hub | Logs | Total |
|---------|-----------|-----------|--|---|---|
| Management | $0.67 | $5 | — | $1 | $6.67 |
| Security (Aggregator) | $0.67 | $5 | $30 | $3 | $38.67 |
| Workload #1 | $0.67 | $10 | — | $1 | $11.67 |
| Workload #2 | $0.67 | $10 | — | $1 | $11.67 |
| Workload #3 | $0.67 | — | — | $1 | $1.67 |
| **Total** | $3.33 | $30 | $30 | $7 | **$70.33** |

## Annual Cost Projections

| Scenario | Monthly | Annual | Notes |
|----------|---------|--------|-------|
| 3 accounts | $70 | $840 | Startup phase |
| 5 accounts | $113 | $1,356 | Growth phase |
| 10 accounts | $193-283 | $2,316-3,396 | Scaling phase |

**Break-even:** Landing zone pays for itself in reduced security incidents + audit time savings at 5+ accounts.

## Recommendations for Cost Control

### Baseline (Always Keep)
- ✅ CloudTrail (non-negotiable for compliance)
- ✅ Security Hub (foundational for FCA audit)
- ✅ GuardDuty (threat detection ROI is high)

### Adjustable by Environment
- **Dev:** 7-day log retention, no GuardDuty data events
- **Staging:** 14-day log retention, GuardDuty enabled
- **Prod:** 30-day log retention, GuardDuty + all data events

### Scaling Strategy

**At 3-5 accounts:** Accept $100-120/month as operational cost of compliance

**At 5-10 accounts:** Implement cost optimizations (reduce log retention, selective GuardDuty)

**At 10+ accounts:** Automate cost monitoring with AWS Cost Explorer; set up billing alerts

## Cost Monitoring (Optional)

Add AWS Cost Explorer integration to track monthly spending:

```bash
aws ce get-cost-and-usage \
  --time-period Start=2026-07-01,End=2026-07-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --filter file://filter.json
```

Set up CloudWatch alarm: Alert if monthly spend > $100

## Cost vs. Risk Analysis

| Risk | Cost of Breach | Cost of Landing Zone | ROI |
|------|---|---|---|
| **Data breach (regulatory)** | £500K+ (FCA fine) | $840/year | **595x** |
| **Unaudited account access** | £100K+ (audit failure) | $840/year | **119x** |
| **Compliance failure** | £1M+ (regulatory action) | $840/year | **1190x** |

**Conclusion:** Even a single avoided incident pays for 1,000+ years of platform costs.

## Summary

- **3-account baseline:** ~$70/month ($840/year)
- **Scales efficiently:** Cost per account decreases at 5-10 accounts
- **Compliance cost:** Negligible compared to regulatory risk
- **Optimization path:** Reduce log retention by environment to save $3-5/month without compromising security
