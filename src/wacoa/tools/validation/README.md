# Validation tools for cost optimization assessments

Two read-only scripts that complement the Azure Cost Recommendations script (ACORL). They answer two questions that come up when the recommendations are turned into a savings estimate:

1. **Are the savings calculated at the price the customer pays?** Azure Advisor estimates right-sizing and shutdown savings from retail prices and its own look-back period. Customers with negotiated prices, reservations or savings plans, or virtual machines that do not run all month, are billed a different amount.
2. **Is the virtual machine series still a good target for a commitment?** Several VM size series have an announced retirement date. A reservation recommendation for one of those series may not be purchasable or renewable, and the workloads need a modernization plan.

Both scripts only read data. They do not change anything in the environment.

## Requirements

- PowerShell 7 or later.
- `Az.Accounts` (both scripts) and `Az.ResourceGraph` (`Get-VmLifecycleStatus.ps1`).
- An active `Connect-AzAccount` session.
- Reader access on the subscriptions. `Get-VmBilledRates.ps1` also needs access to cost data (for example Cost Management Reader).

## Get-VmBilledRates.ps1

Returns, for each virtual machine, the compute hours, retail cost, price sheet cost, billed cost, discount against retail and billed hourly rate for a period. It uses the Cost Details API (`generateCostDetailsReport`).

```powershell
# All virtual machines in two subscriptions, last 30 days
./Get-VmBilledRates.ps1 -SubscriptionIds '<subscription-id-1>', '<subscription-id-2>'

# Only the virtual machines in the right-sizing recommendations (one resource ID per line)
./Get-VmBilledRates.ps1 -SubscriptionIds '<subscription-id>' -VmListPath ./rightsizing-vms.txt

# Fixed period, amortized cost
./Get-VmBilledRates.ps1 -SubscriptionIds '<subscription-id>' -StartDate 2026-10-01 -EndDate 2026-10-31 -Metric AmortizedCost

# Offline: process cost details files that were already downloaded or exported
./Get-VmBilledRates.ps1 -CostDetailsPath ./exports
```

| Output | Content |
|---|---|
| `vm-billed-rates.csv` | One row per virtual machine. |
| `vm-billed-rates-raw.csv` | The cost detail rows behind each virtual machine. |
| `vm-billed-rates-log.txt` | What happened, per subscription. |

How to use the result to restate a right-sizing estimate:

1. Take `BilledComputeHourlyRate` and `ComputeHours` of the current size from `vm-billed-rates.csv`.
2. Apply the price ratio between the target size and the current size to the billed rate.
3. Multiply the difference by the billed hours and project it to a year.

Notes:

- With `ActualCost`, usage covered by a reservation or a savings plan has a cost of zero. A virtual machine that is fully covered by a reservation shows no direct saving from right-sizing. Use `AmortizedCost` to see the commitment cost spread over the usage.
- `RetailCost`, `PriceSheetCost` and `BilledCost` include all meters charged to the virtual machine resource (for example license meters). The hourly rates only use the `Virtual Machines` meter category.
- The Cost Details API accepts up to one month per request and can take several minutes for large subscriptions.
- Column names in cost details differ between agreement types. The script reads each value from the first column that has it.

## Get-VmLifecycleStatus.ps1

Lists virtual machines and scale sets and flags the ones that run on a series with an announced retirement, with the retirement date and the days left.

```powershell
# Virtual machines and scale sets in the subscriptions of the current context
./Get-VmLifecycleStatus.ps1

# Specific subscriptions
./Get-VmLifecycleStatus.ps1 -SubscriptionIds '<subscription-id-1>', '<subscription-id-2>'

# Offline: classify the sizes in a CSV file, for example the SKUs of reservation recommendations
./Get-VmLifecycleStatus.ps1 -InputPath ./reservation-recommendations.csv -SizeColumn sku
```

| Output | Content |
|---|---|
| `vm-lifecycle-inventory.csv` | One row per resource, with series, retirement status, retirement date and days to retirement. |
| `vm-lifecycle-summary.csv` | One row per series, with the number of resources, running VMs and instances. |

### Retirement table

The series and dates are in `vm-series-retirements.csv`, so they can be updated without changing the script. Each row has a regular expression (`SizePattern`) that is matched against the VM size name.

The table was built from [VM size series retirements, capacity growth restrictions, and modernization guidance](https://learn.microsoft.com/azure/virtual-machines/migration/sizes/previous-gen-series-capacity-limitations) as last updated on September 25, 2026. Retirement dates change, so confirm them on that page before sharing results. The same page describes the reservation purchase, renewal and exchange rules for the affected series.

Sizes that do not match any row are reported as `Not listed`. This does not mean the series is current. It only means the series is not in the table.

Not covered: confidential computing series with the `_cc_` suffix and Azure Dedicated Host types.
