# Lab 5: Monitoring & governance

## Overview

This lab walks you through the operational controls that keep your Azure consumption predictable and aligned with business objectives. You'll set up quota alerts to catch capacity constraints early, deploy budgets to track spend against forecasts, implement cost anomaly detection, monitor capacity reservation utilization, suppress noisy advisor recommendations, and build dashboards that feed forecasting decisions. These controls align with the [workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain) model and [cost management alerting](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending).

We focus on the mechanics—the knobs you turn, the thresholds you set, the data you extract—not prescriptive governance models. The tools here assume you're running SaaS workloads under an EA or Microsoft Customer Agreement with multiple subscriptions organized under management groups.

### Prerequisites

- Access to at least two subscriptions (one for exercises 1–5, one additional for scale exercises)
- Subscriptions organized under a management group
- Contributor role on subscriptions; Advisor Contributor role for suppression exercises
- Azure CLI installed with the quota extension
- PowerShell 7+ with Azure modules (Az.CostManagement, Az.Advisor)
- Action groups already created for alerts (or create one during exercise 1)
- Read-only access to the lab script repository (scripts/ directory)

### Lab goals

By the end of this lab, you'll be able to:

- configure quota usage alerts at 60%, 80%, and 90% thresholds
- deploy budgets programmatically to individual subscriptions and at scale
- activate cost anomaly detection for anomalous spend patterns
- query and interpret capacity reservation allocation states
- suppress Advisor recommendations with time-to-live (TTL) constraints
- export quota usage data and build trend dashboards
- integrate monitoring signals into your forecasting feedback loop

---

## The 4-signal model

Monitoring in this context means tracking four signals:

- **Signal 1: Quota**—usage vs. limit by subscription, region, and VM family
- **Signal 2: Reservation**—capacity reservation group utilization and overallocation state via instanceView
- **Signal 3: Cost**—budget consumption, anomaly detection, and commitment utilization
- **Signal 4: Gate**—CI/CD pipeline pass/fail for capacity checks before stamp deployments

Each signal maps to a different enforcement point and a different response. The exercises below cover all four signals.

Reference: [Workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain)

---

## Exercise 1: Create quota usage alerts

### Goal

Set up proactive quota alerts so you catch capacity constraints before they block deployments. You'll use the My quotas portal experience to configure thresholds and attach action groups.

### Context

Azure quotas limit the number of resources you can create in a subscription by type—compute cores, network interfaces, public IPs, and so on. When a quota fills up, new resource deployments fail. Quota alerts notify you at 60%, 80%, and 90% utilization so you can request quota increases before you hit the hard limit.

The alert mechanism integrates with action groups to send emails, webhooks, or other actions when thresholds are crossed. This guidance describes [quota monitoring and alerting](https://learn.microsoft.com/en-us/azure/quotas/monitoring-alerting).

### Steps

1. Sign in to the Azure portal and go to **Quotas** (search "quotas" in the top bar).

2. Filter to your subscription and region. You'll see a table of resource types with current usage and limits.

3. Select a quota you want to monitor—for example, **Standard DSv3 Family vCPUs** in East US. Select the checkbox next to it.

4. Choose **Create alert**. The alert creation panel opens.

5. Select or create an action group. If creating one:
   - Set **Action Group Name** to something like `quota-alerts-compute`
   - Set **Short Name** to `quota-cmp`
   - Add a receiver (email, webhook, etc.)

6. Configure thresholds and severity tiers:
   - Enter **60** for the first threshold (Severity 3 = informational, no action)
   - Enter **80** for the second (Severity 2 = plan quota action)
   - Enter **90** for the third (Severity 1 = block new stamps)
   - Enter **95** for the fourth (Severity 0 = critical/emergency, escalate immediately and block stamp expansion)
   - Leave **100** to alert on hard limit

   Each severity tier should route to a different action group. For example:
   - 60% → email to the platform team (informational)
   - 80% → email to platform and finance teams (planning phase)
   - 90% → email and webhook to PagerDuty on-call rotation (deployment blocker)
   - 95% → immediate escalation via PagerDuty, ITSM ticket creation, and leadership notification (emergency)

7. Enter an alert name like `quota-alert-dsvx-eastus-60pct` and select **Create**.

8. Repeat for other quota types relevant to your workloads (vCPUs, managed disks, network interfaces). Create separate action groups for each severity level to ensure the right people get the right alerts at the right time.

### Validation

After 5–10 minutes, the alerts appear in **Monitor > Alerts**. When utilization crosses a threshold, the action group fires. You can test by selecting **Test action group** from the alert rule's detail page.

---

## Exercise 2: Deploy subscription budgets

### Goal

Deploy a budget to a single subscription using the `Deploy-Budget.ps1` script, configure thresholds, and verify it tracks actual spend.

### Context

Budgets are subscription-scoped cost controls. They track actual and forecasted spend and trigger alerts at your chosen thresholds (50%, 75%, 90%, and optionally 100% of forecasted spend). Unlike quotas, budgets don't block resources—they notify you so you can course-correct. This guidance describes [budget alerts](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending).

The `Deploy-Budget.ps1` script automates budget creation. It accepts budget amounts as parameters or reads them from a subscription tag (`BudgetAmount`). This approach lets you manage per-subscription budgets without editing scripts.

### Steps

1. Identify or create a subscription tag called `BudgetAmount` with a value—for example, `5000` (USD). This becomes your monthly budget cap. If you omit the tag, the script defaults to `$10`.

2. Open PowerShell and go to the lab scripts directory.

3. Run the script with parameters:

```powershell
$contactEmails = @("platform-team@example.com", "finance@example.com")
$subscriptionId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

.\Deploy-Budget.ps1 `
  -SubscriptionId $subscriptionId `
  -ContactEmails $contactEmails `
  -Amount 5000 `
  -TimeGrain Monthly `
  -StartDate (Get-Date) `
  -FirstThreshold 50 `
  -SecondThreshold 75 `
  -ThirdThreshold 90 `
  -ForecastedThreshold 100
```

4. The script creates a budget named `subscription-budget-<subscriptionId>` with action groups targeting your contact emails.

5. Verify in the portal: go to **Cost Management > Budgets** and confirm the budget appears with correct thresholds.

### Parameters explained

- `-Amount`: monthly budget in currency units (USD by default)
- `-TimeGrain`: Monthly, Quarterly, or Annually
- `-ContactEmails`: array of email addresses for alerts
- `-FirstThreshold`, `-SecondThreshold`, `-ThirdThreshold`, `-ForecastedThreshold`: percentage thresholds (0–100)
- `-WhatIf`: preview changes without applying
- `-Force`: skip confirmation prompts
- `-Quiet`: suppress console output

### Validation

In Cost Management, select the budget and confirm it shows:

- Start and end dates
- Threshold alerts listed
- Associated action group(s)

Wait 24 hours for the first cost data to populate (Cost Management refreshes daily). Then check **Alerts** to see if any fire.

---

## Exercise 3: Deploy budgets at scale

### Goal

Use `Deploy-BulkBudgets.ps1` to deploy budgets across all subscriptions under a management group. Preview changes with `-WhatIf` before applying.

### Context

When you have dozens or hundreds of subscriptions, deploying budgets one at a time is unsustainable. The bulk script iterates subscriptions under a management group and applies the same budget template to each. Tag-based amounts let you vary the budget per subscription without script changes. This guidance describes [budget alerts](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending).

### Steps

1. Ensure all subscriptions under your target management group have the `BudgetAmount` tag set appropriately. If a subscription lacks the tag, the script uses the default amount you specify.

2. Run the script with `-WhatIf` to preview:

```powershell
$contactEmails = @("platform-team@example.com")
$managementGroup = "prod-workloads"  # name or ID
$defaultAmount = 10000

.\Deploy-BulkBudgets.ps1 `
  -ManagementGroup $managementGroup `
  -ContactEmails $contactEmails `
  -Amount $defaultAmount `
  -TimeGrain Monthly `
  -WhatIf
```

3. Review the `-WhatIf` output. It shows each subscription and the budget that would be created.

4. If the preview looks correct, run without `-WhatIf`:

```powershell
.\Deploy-BulkBudgets.ps1 `
  -ManagementGroup $managementGroup `
  -ContactEmails $contactEmails `
  -Amount $defaultAmount `
  -TimeGrain Monthly `
  -Quiet
```

The `-Quiet` flag suppresses per-subscription output, useful for large deployments.

5. Verify in Cost Management: filter to **Budgets** and confirm one budget per subscription appears.

### Scale considerations

- The script paginates subscriptions internally—no manual pagination needed
- For 100+ subscriptions, the script may take 5–10 minutes
- Each budget gets its own action group to avoid alert storms on shared groups
- If a subscription already has a budget with the same name, the script skips it (use `-Force` to overwrite)

---

## Exercise 4: Deploy cost anomaly alerts

### Goal

Deploy cost anomaly detection to catch unusual spending patterns. You'll deploy to a single subscription first, then at enterprise scale using the bulk script.

### Context

Cost anomaly alerts use machine learning to detect when spending deviates from historical trends. Unlike budgets (which use fixed thresholds), anomaly detection learns your baseline spend and flags outliers. This is particularly useful for SaaS workloads with variable usage patterns. This guidance describes [analyzing unexpected charges](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/analyze-unexpected-charges) and the [scheduled actions API](https://learn.microsoft.com/en-us/rest/api/cost-management/scheduled-actions).

The `Deploy-AnomalyAlert.ps1` script creates a scheduled action—a standing automation rule—that monitors daily cost data and notifies you when anomalies occur.

### Steps (single subscription)

1. Identify the target subscription and a notification email.

2. Run the script:

```powershell
$emailRecipients = @("platform-team@example.com", "finance-alerts@example.com")
$notificationEmail = "platform-team@example.com"
$subscriptionId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

.\Deploy-AnomalyAlert.ps1 `
  -SubscriptionId $subscriptionId `
  -EmailRecipients $emailRecipients `
  -NotificationEmail $notificationEmail `
  -Quiet
```

3. The script deploys a Bicep template (`anomaly-alert.bicep`) that creates a `Microsoft.CostManagement/scheduledActions` resource at subscription scope.

4. Verify in the portal: go to **Cost Management > Cost anomaly** and confirm a detection rule appears.

### Steps (enterprise scale)

For multiple subscriptions under a management group:

```powershell
$tenantId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$managementGroup = "prod-workloads"
$emailRecipients = @("platform-team@example.com")
$notificationEmail = "platform-team@example.com"

.\Deploy-BulkALZ.ps1 `
  -TenantId $tenantId `
  -ManagementGroup $managementGroup `
  -EmailRecipients $emailRecipients `
  -NotificationEmail $notificationEmail `
  -WhatIf
```

After reviewing the `-WhatIf` output, run without it to deploy.

### How anomaly detection works

Once deployed, the alert monitors spend each day. The system builds a baseline over the first ~10 days. After that, Cost Management's ML models detect statistically significant deviations from your baseline spending pattern and trigger notifications. Unlike budgets, anomaly thresholds don't require manual tuning for each subscription.

### Validation

Check **Cost Management > Alerts > Cost anomaly**. You'll see:

- Detection rules listed per subscription or management group
- **Alert** tab showing any triggered anomalies (there won't be any until spend deviates from baseline)

---

## Exercise 5: Monitor capacity reservation utilization

### Goal

Query capacity reservation utilization via the instanceView property, interpret allocation states, and use that data to adjust reservation sizes.

### Context

Capacity reservations guarantee VM instance availability in a specific zone. The instanceView property tracks three quantities:

- **available**: reserved capacity not yet allocated to instances
- **consumed**: capacity actively in use by running instances
- **overallocated**: capacity reserved but sold beyond the limit (only possible if you explicitly enabled overallocation)

Monitoring these three states helps you right-size reservations—keeping available capacity low without running short. This guidance describes [capacity reservation overallocation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate).

### Steps

1. List all capacity reservations in your subscription:

```bash
az capacity reservation list --subscription $SUBSCRIPTION_ID -o json
```

2. For each reservation, get the instanceView to see allocation states:

```bash
az capacity reservation show \
  --capacity-reservation-group myGroup \
  --name myReservation \
  --resource-group myRG \
  --subscription $SUBSCRIPTION_ID
```

Look for the `instanceView` object, which contains:

```json
"instanceView": {
  "statuses": [
    {
      "code": "ProvisioningState/succeeded",
      "level": "Info"
    }
  ],
  "utilizationInfo": {
    "virtualMachinesAllocated": [
      {
        "id": "/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1"
      }
    ]
  }
}
```

The `sku.capacity` property on the reservation itself defines the reserved quantity. Compare `virtualMachinesAllocated` count against `sku.capacity` to calculate utilization. See the [capacity reservation overview](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) for the full response schema.

3. Calculate your utilization ratio:

```
Utilization = count(virtualMachinesAllocated) / sku.capacity
```

Aim for 80–95% utilization. If utilization creeps above 95%, request a larger reservation. If it drops below 50%, consider reducing the reserved quantity.

4. If you've enabled [overallocation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) on a reservation, the count of allocated VMs may exceed `sku.capacity`. This is intentional and allows you to pack more VMs than you reserved, accepting burst risk.

### Interpretation guide

| State | Meaning | Action |
|-------|---------|--------|
| allocated VMs < sku.capacity | Unused reserved capacity | Consider reducing reservation size to improve ROI |
| allocated VMs ≈ sku.capacity | Optimal utilization | No action needed |
| allocated VMs > sku.capacity | Overallocation enabled | Expected; verify burst tolerance with platform team |
| allocated VMs < 0.5 x sku.capacity | Underutilized | Reduce reservation size or consolidate workloads |

### Export for dashboards

You can export instanceView data via the portal or CLI:

```bash
az capacity reservation list \
  --subscription $SUBSCRIPTION_ID \
  --query "[].{name: name, reserved: sku.capacity, allocatedVMs: length(instanceView.utilizationInfo.virtualMachinesAllocated || [])}" \
  -o table
```

Use this output to feed dashboards in Azure Monitor or Power BI.

---

## Exercise 5b: Validate monitoring scope coverage

### Goal

Ensure that your cost, quota, and capacity reservation monitoring rules cover all relevant scopes so you don't miss alerts due to scope mismatches.

### Context

Different monitoring signal types operate at different scopes:

- **Cost anomaly detection** operates at subscription or resource group scope
- **Quota alerts** are per subscription + region + VM family
- **Capacity reservation utilization** is per capacity reservation group (there's no built-in anomaly detection—you monitor utilization via instanceView)

If your monitoring scopes don't align with where changes actually occur, you'll miss notifications. For example, if you configure a cost anomaly at the management group level but your actual spend variance happens at a resource group level, the aggregation might hide the signal.

### Steps

1. List your subscriptions and organize them by region and VM family (for quota tracking):

```bash
az account list -o table --query "[].{name: name, subscriptionId: id}"
```

2. For cost anomalies, define your scope explicitly:
   - Are you monitoring at subscription or resource group level?
   - Document which subscriptions have cost anomalies enabled and at what scope
   - Verify that all cost-critical subscriptions are covered

3. For quota anomalies, map your subscriptions to the regions and VM families you use:

```bash
az vm list-usage --subscription $SUBSCRIPTION_ID --location eastus -o table
```

Record the VM families in use. For each subscription + region + family combination, ensure you have a quota alert configured (see Exercise 1).

4. For capacity reservations, list all CRGs and verify monitoring is enabled:

```bash
az capacity reservation group list --subscription $SUBSCRIPTION_ID -o json | jq -r '.[].id'
```

Check that you're extracting instanceView data regularly for each CRG (see Exercise 5).

5. Create a scope coverage matrix:

| Scope Type | Scope | Anomaly Type | Coverage | Action Group |
|------------|-------|--------------|----------|--------------|
| Subscription | sub-prod-1 | Cost | Yes | cost-alerts-prod |
| Subscription + Region + VM Family | sub-prod-1, eastus, Standard_D2s_v3 | Quota | Yes | quota-alerts-compute |
| Capacity Reservation Group | crg-prod-app-tier | Overallocation | Yes | reservation-alerts |

Document any gaps. If a scope is missing, either configure monitoring or document why it's intentionally excluded.

### Validation

After defining your scope boundaries:

- Run a test anomaly detection run to verify the scope captures the signal
- Confirm that each monitoring rule fires only for its intended scope
- Review alerts from the past week to ensure scope coverage is complete

Reference: [Capacity reservation overallocation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate)

---

## Exercise 6: Suppress noisy Advisor recommendations

### Goal

Use the Advisor suppression API to mute recommendations you've reviewed and decided not to act on. Suppressions include a TTL (time-to-live) so recommendations re-surface after investigation.

### Context

Azure Advisor generates recommendations across categories: cost, security, reliability, operational excellence, and performance. Some recommendations are noisy (e.g., "use reserved instances" even though you already use them for most workloads) or not applicable to your architecture. Suppression lets you silence them without losing the capability to review them later.

Suppressions expire after a maximum of 90 days, forcing you to actively re-evaluate rather than permanently hiding recommendations. This guidance describes [Advisor suppression](https://learn.microsoft.com/en-us/azure/advisor/suppress-recommendations).

Your account must have the **Advisor Contributor** role. This guidance describes [Advisor permissions](https://learn.microsoft.com/en-us/azure/advisor/permissions).

### Steps

1. Identify noisy recommendation types. Go to **Azure Advisor > Cost** and look for recommendations you want to suppress (e.g., "buy reserved instances").

2. Note the recommendation type ID. You can find these in the Advisor API docs or by querying the API directly:

```bash
az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Advisor/recommendations?api-version=2020-01-01" \
  --query "value[0].properties.recommendationType" -o tsv
```

Common type IDs include:
- Cost optimization recommendations (GUIDs vary by region and recommendation category)

3. Run the suppression script with a TTL (max 90 days):

```powershell
$managementGroupId = "prod-workloads"
$recommendationTypeIds = @(
  "01234567-89ab-cdef-0123-456789abcdef",  # example GUID
  "fedcba98-7654-3210-fedc-ba9876543210"   # another example
)
$days = 30

.\Suppress-AdvisorRecommendations.ps1 `
  -ManagementGroupId $managementGroupId `
  -RecommendationTypeIds $recommendationTypeIds `
  -Days $days `
  -WhatIf
```

4. Review the `-WhatIf` output and confirm the recommendation types you want to suppress.

5. Run without `-WhatIf` to apply:

```powershell
.\Suppress-AdvisorRecommendations.ps1 `
  -ManagementGroupId $managementGroupId `
  -RecommendationTypeIds $recommendationTypeIds `
  -Days $days
```

6. Verify in the portal: go to **Azure Advisor** and confirm suppressed recommendations no longer appear (or appear with a "suppressed" badge).

### TTL and re-evaluation

After 30 days (in the example above), the suppression expires and the recommendation re-surfaces. This forces periodic re-review rather than fire-and-forget. If you want permanent suppression, re-run the script periodically or increase the TTL up to 90 days.

---

## Exercise 6b: CI/CD capacity gates

### Goal

Integrate four capacity checks into your deployment pipeline to prevent stamp deployments that would violate quota, budget, or reservation constraints.

### Context

The workload supply chain model uses gates to promote workloads through dev → staging → production. Capacity gates are enforcement points that verify sufficient headroom exists before a deployment proceeds. This prevents cascading failures and ensures your monitoring and governance layers are connected to operational decisions.

### Steps

Add the following four checks to your deployment pipeline (e.g., in your CI/CD orchestration or pre-deployment validation step):

1. **Quota headroom check**: Verify available quota is greater than the deployment requirement for both the region and VM family

   ```bash
   # Pseudocode for quota gate
   REQUIRED_CORES=20
   QUOTA_FAMILY="Standard_D2s_v3"
   TARGET_REGION="eastus"

   AVAILABLE=$(az vm list-usage \
     --location $TARGET_REGION \
     --subscription $SUBSCRIPTION_ID \
     --query "[?name.value=='$QUOTA_FAMILY'].{available: (limit - currentValue)}" \
     -o tsv)

   if [ "$AVAILABLE" -lt "$REQUIRED_CORES" ]; then
     echo "GATE_FAILED: Insufficient quota in $TARGET_REGION for $QUOTA_FAMILY"
     exit 1
   fi
   ```

2. **Alert coverage check**: Verify that quota and cost alerts are configured for the target subscription and region

   ```bash
   # Pseudocode for alert coverage gate
   SUBSCRIPTION_ID="target-sub"
   TARGET_REGION="eastus"

   # Check for quota alerts in this region
   QUOTA_ALERTS=$(az monitor metrics alert list \
     --subscription $SUBSCRIPTION_ID \
     --query "[?contains(description, '$TARGET_REGION')].name" \
     -o tsv)

   if [ -z "$QUOTA_ALERTS" ]; then
     echo "GATE_FAILED: No quota alerts configured for $TARGET_REGION"
     exit 1
   fi
   ```

3. **Capacity reservation check** (if applicable): Verify reserved quantity ≥ deployment target

   ```bash
   # Pseudocode for CRG gate
   TARGET_CRG="crg-prod-app-tier"
   REQUIRED_INSTANCES=10

   RESERVED=$(az capacity reservation show \
     --capacity-reservation-group $TARGET_CRG \
     --subscription $SUBSCRIPTION_ID \
     --query "instanceView.allocatedQuantity" \
     -o tsv)

   if [ "$RESERVED" -lt "$REQUIRED_INSTANCES" ]; then
     echo "GATE_FAILED: Insufficient reserved capacity in $TARGET_CRG"
     exit 1
   fi
   ```

4. **Budget posture check**: Verify current spend + projected deployment spend doesn't exceed budget

   ```bash
   # Pseudocode for budget gate
   SUBSCRIPTION_ID="target-sub"
   PROJECTED_MONTHLY_SPEND=500  # USD

   CURRENT_SPEND=$(az rest --method post \
     --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.CostManagement/query?api-version=2023-11-01" \
     --body '{"type":"ActualCost","timeframe":"MonthToDate","dataset":{"granularity":"None","aggregation":{"totalCost":{"name":"Cost","function":"Sum"}}}}' \
     --query "properties.rows[0][0]" \
     -o tsv)

   BUDGET=$(az consumption budget show \
     --budget-name "subscription-budget-$SUBSCRIPTION_ID" \
     --query "amount" \
     -o tsv)

   if [ $(($CURRENT_SPEND + $PROJECTED_MONTHLY_SPEND)) -gt "$BUDGET" ]; then
     echo "GATE_FAILED: Budget insufficient for deployment"
     exit 1
   fi
   ```

5. Integrate these checks as pass/fail gates in your pipeline. Each check should either pass (proceed to next stage) or fail (block deployment and alert the team).

### Example pipeline integration (GitHub Actions)

```yaml
name: Deploy with capacity gates

jobs:
  capacity-gates:
    runs-on: ubuntu-latest
    steps:
      - name: Quota headroom gate
        run: |
          # Run quota check script
          ./scripts/check-quota-headroom.sh ${{ secrets.SUBSCRIPTION_ID }} eastus
      - name: Alert coverage gate
        run: |
          # Run alert coverage check
          ./scripts/check-alert-coverage.sh ${{ secrets.SUBSCRIPTION_ID }} eastus
      - name: CRG capacity gate
        run: |
          # Run reservation check
          ./scripts/check-crg-capacity.sh ${{ secrets.SUBSCRIPTION_ID }} crg-prod-app-tier
      - name: Budget posture gate
        run: |
          # Run budget check
          ./scripts/check-budget-posture.sh ${{ secrets.SUBSCRIPTION_ID }}
      - name: Deploy
        if: success()
        run: |
          # Proceed to deployment only if all gates pass
          az deployment group create --resource-group myRG --template-file main.bicep
```

### Validation

After implementing capacity gates:

- Attempt a deployment that would exceed quota—verify it blocks
- Attempt a deployment when budget is exhausted—verify it blocks
- Attempt a deployment when alert coverage is missing—verify it blocks
- Attempt a valid deployment—verify it proceeds

Reference: [Workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain)

---

## Exercise 7: Build a quota usage dashboard

### Goal

Export quota usage data and build a dashboard that shows trends over time, helping you forecast when you'll need quota increases.

### Context

Quota usage changes as your workloads scale. A dashboard that tracks utilization trends helps you predict when you'll hit limits and request increases proactively. The `Get-AzVMQuotaUsage.ps1` script provides multi-threaded quota data collection—fast enough for large subscriptions.

This guidance describes the [workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain) and how it connects to forecasting.

### Steps

1. Export quota usage for a subscription using the script:

```powershell
.\Get-AzVMQuotaUsage.ps1 -SubscriptionId $subscriptionId
```

This returns a PowerShell object with quota type, current usage, limit, and percentage utilization.

2. Export to CSV for ingestion into a dashboard tool:

```powershell
$quotas = .\Get-AzVMQuotaUsage.ps1 -SubscriptionId $subscriptionId
$quotas | Export-Csv -Path "quota-usage-$(Get-Date -Format 'yyyy-MM-dd').csv" -NoTypeInformation
```

3. Collect CSV files daily or weekly via Azure Automation or a scheduled task, appending to a data store (Azure Table Storage, SQL Database, etc.).

4. Build a dashboard in Power BI or Azure Monitor that shows:

   - Quota utilization over time (line chart with percentage on Y axis, date on X axis)
   - Trends per quota type (e.g., vCPUs, managed disks)
   - Forecasted utilization (using linear regression or moving averages)
   - Subscriptions where utilization exceeds 80% (highlight for action)

5. Schedule the dashboard as a daily email or embed it in your platform operations portal.

### Example dashboard queries

If you're storing quota data in a SQL database:

```sql
SELECT
  quota_type,
  subscription_id,
  current_usage,
  quota_limit,
  CAST(current_usage AS FLOAT) / quota_limit * 100 AS utilization_pct,
  captured_date
FROM quota_usage
WHERE subscription_id = @subscriptionId
  AND captured_date >= DATEADD(day, -90, GETDATE())
ORDER BY captured_date DESC, quota_type;
```

Use this to build trend charts and alert thresholds in your BI tool.

### PaaS service monitoring

Quota groups cover IaaS compute only. For PaaS services, monitor quotas and costs through service-specific mechanisms:

- **Azure Storage**: Storage accounts have a [per-subscription quota](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-storage-limits) (default 250 per region). Monitor account counts and configure budget alerts for storage spend.

  ```bash
  az storage account list --subscription $SUBSCRIPTION_ID \
    --query "length([?location=='eastus'])" -o tsv
  ```

- **Azure Cosmos DB**: Monitor [provisioned RU throughput](https://learn.microsoft.com/en-us/azure/cosmos-db/monitor#monitoring-overview) and set budget alerts for Cosmos DB spend. Use Azure Monitor metrics (`TotalRequestUnits`, `NormalizedRUConsumption`) to track utilization against provisioned capacity.

  ```bash
  az monitor metrics list --resource $COSMOS_RESOURCE_ID \
    --metric "NormalizedRUConsumption" --interval PT1H -o table
  ```

- **Azure Service Bus**: Monitor [messaging unit utilization](https://learn.microsoft.com/en-us/azure/service-bus-messaging/monitor-service-bus-reference) with Azure Monitor metrics (`NamespaceMemoryUsage`, `IncomingMessages`). Premium namespaces have messaging unit quotas that constrain throughput.

  ```bash
  az monitor metrics list --resource $SERVICEBUS_RESOURCE_ID \
    --metric "IncomingMessages" --interval PT1H -o table
  ```

- **Azure Key Vault**: Monitor [transaction rate limits](https://learn.microsoft.com/en-us/azure/key-vault/general/service-limits) with Azure Monitor metrics (`ServiceApiHit`, `ServiceApiLatency`). Key Vault enforces throttling at 4,000 transactions per 10 seconds for vaults in the same region.

- **Azure Event Hubs**: Monitor [throughput units](https://learn.microsoft.com/en-us/azure/event-hubs/monitor-event-hubs-reference) with Azure Monitor metrics (`IncomingBytes`, `OutgoingBytes`). Auto-inflate can scale throughput units automatically, but set budget alerts to catch unexpected cost growth.

Include these PaaS metrics in your quota usage dashboard alongside compute data for a complete view of your capacity posture.

### Connecting to forecasting

Once you have historical quota usage data, you can forecast when you'll hit limits:

1. Calculate the rate of quota usage increase (e.g., 5% per week)
2. Extrapolate: if current utilization is 60% and you're growing at 5% per week, you'll hit 90% in 6 weeks
3. Submit quota increase requests with 2–4 weeks lead time

This closes the feedback loop from monitoring to forecasting to capacity planning.

---

## Wrap-up: Monitoring feeds forecasting

The exercises above create a monitoring and governance backbone organized around the 4-signal model:

1. **Signal 1: Quota**—quota alerts catch capacity constraints early (Exercises 1, 5b, 6b)
2. **Signal 2: Reservation**—capacity reservation monitoring ensures you're getting ROI on reserved capacity (Exercises 5, 5b, 6b)
3. **Signal 3: Cost**—budgets track spend against forecasts, anomaly detection surfaces unusual patterns, and dashboards drive capacity planning (Exercises 2, 3, 4, 7)
4. **Signal 4: Gate**—CI/CD pipeline gates validate quota headroom, alert coverage, reservation capacity, and budget posture before deployments proceed (Exercise 6b)

These signals feed into a closed loop: monitoring collects the four signals, dashboards visualize them, gates enforce them at deployment time, and forecasting uses them to drive capacity and budget planning. You circle back to monitoring to validate your forecasts.

Additionally:

- **Advisor suppression** reduces alert fatigue while maintaining accountability (Exercise 6)
- **Workload supply chain integration**: Monitoring data feeds the promote-through-gates model. As workloads move from dev → staging → production, each stage's deployment gates enforce the same capacity checks, ensuring consistent governance across your environment. The four signals (quota, reservation, cost, gate) align with the supply chain's enforcement points, creating a unified operational model.

The [workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain) describes this full lifecycle in detail. The monitoring layer you've built is the observability component of that chain.

Use these signals to inform your FinOps optimization strategy—cost data and quota constraints drive rate-optimization decisions. See the [FinOps rate optimization guidance](https://www.finops.org/framework/capabilities/rate-optimization/) for details.

---

## Troubleshooting

### Budget not showing spend

- Budgets require 24–48 hours for initial cost data population
- Verify the subscription has incurred costs
- Check that the budget's scope (subscription/management group) matches your intent

### Anomaly detection not firing

- Machine learning baseline takes ~10 days to establish
- Verify the scheduled action is deployed and active in the target subscription
- Check that the notification email is valid and not in spam

### Quota alert not triggering

- Alerts fire based on actual quota utilization, not on alert configuration
- Verify you've provisioned enough resources to approach the quota
- Wait 5–10 minutes after threshold is crossed for the alert to fire

### Suppression script fails with permission error

- Confirm your account has **Advisor Contributor** role at the management group scope
- Confirm your account has the [required permissions](https://learn.microsoft.com/en-us/azure/advisor/permissions)

---

## References

- [Quota monitoring and alerting](https://learn.microsoft.com/en-us/azure/quotas/monitoring-alerting)
- [Create quota usage alerts](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting)
- [Budget alerts](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending)
- [Capacity reservation overallocation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate)
- [Workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain)
- [Advisor suppression](https://learn.microsoft.com/en-us/azure/advisor/suppress-recommendations)
- [Advisor permissions](https://learn.microsoft.com/en-us/azure/advisor/permissions)
