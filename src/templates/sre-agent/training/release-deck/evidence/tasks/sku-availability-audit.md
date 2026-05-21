# SKU Availability Audit

## Identity
- **YAML:** sre-config/scheduled-tasks/sku-availability-audit.yaml
- **Cron:** 0 7 * * 3 — weekly on Wednesday at 07:00 UTC
- **Owning subagent:** azure-capacity-manager
- **FinOps Framework capability:** Capacity Planning (SKU/zone readiness)
- **Maturity:** Crawl
- **Tools used:** PostTeamsMessage

## Latest run summary
The weekly SKU Availability Audit completed successfully. Here's the summary: **Compute SKU Availability:** **westus**: 73 of 1,173 SKUs restricted (6.2%) — low risk **eastus2**: 239 of 1,286 SKUs restricted (18.6%) — moderate risk All restrictions are `NotAvailableForSubscription` (offer-level), not capacity exhaustion **Critical ADX Finding:** `Standard_E4ads_v5` is **NOT available** via the Microsoft.Kusto regional

## Final Teams card / Outlook output (verbatim)
~~~~text
The weekly SKU Availability Audit completed successfully. Here's the
summary:

**Compute SKU Availability:**
- **westus**: 73 of 1,173 SKUs restricted (6.2%) — low risk
- **eastus2**: 239 of 1,286 SKUs restricted (18.6%) — moderate risk
- All restrictions are `NotAvailableForSubscription` (offer-level), not
capacity exhaustion

**Critical ADX Finding:**
- `Standard_E4ads_v5` is **NOT available** via the Microsoft.Kusto regional
API in westus — cluster `msbw-finops-hub` (v12.0) uses this SKU. Existing
instance runs fine, but new provisioning/scaling would fail.
- `Standard_E4d_v4` is confirmed available — cluster `msbwtreyhub` (v13.0)
is unaffected.

**Top Action:** Plan SKU migration for `msbw-finops-hub` from
`Standard_E4ads_v5` to `Standard_E4d_v4`, combined with a version upgrade
from v12.0 to v14.0.

Report posted to Teams and findings saved to knowledge base.
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- Top Action:** Plan SKU migration for `msbw-finops-hub` from
- `Standard_E4ads_v5` to `Standard_E4d_v4`, combined with a version upgrade

## Knowledge updates
- 1. Reading the knowledge base documents
- 8. Saving operational findings to knowledge base
- Reading knowledge base and loading the capacity management skill.
- Read file: memory: finops-hub-health-check-findings.md
- Good, I've read the knowledge base and loaded the capacity management
- From the knowledge base, I can identify:
- Since no priority SKU list exists in the knowledge base, I'll:
- knowledge base). Let me now establish the full scope:
- Since there's no priority VM SKU list in the knowledge base, I'll audit the
- saving findings to the knowledge base.
- 2. Save findings to the knowledge base (task 9)
- knowledge base.
- Read file: memory: advisor-suppression-review-findings.md
- findings to the knowledge base. Let me complete that final step now.
- the knowledge base.
- Created file: memory: sku-availability-audit-findings.md (86 lines)
- Report posted to Teams and findings saved to knowledge base.

## MCAPS asks this task answers
- **#13:** Detects regional/SKU restrictions that would block provisioning or scaling.
- **#14:** Finds westus and eastus2 SKU restrictions and classifies them as offer-level NotAvailableForSubscription.
- **#20:** Identifies a concrete migration path when a required SKU is unavailable in westus.
- **#23:** Acts as a capacity pre-flight check for FinOps Hub Kusto SKU provisioning.
- **#71:** Adds SKU availability to capacity visibility evidence.
