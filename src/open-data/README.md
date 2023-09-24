# 📇 Open data

Our open data solutions are pretty straightforward. Nothing to deploy. Just use them as needed. Below you will find internal notes about data sources and how to update the data, as appropriate.

On this page:

- [📏 Pricing units](#-pricing-units)
- [🗺️ Regions](#️-regions)

---

## 📏 Pricing units

<sup>
    📅 Updated: Sep 24, 2023_<br>
    ➡️ Source: Cost Management team<br>
</sup>

The [PricingUnits.csv](./PricingUnits.csv) file contains the list of all unique `UnitOfMeasure` values. This data will need to be updated periodically.

Use the following query to update the data:

```kql
let unabbrev = (regex: string, uom: string) { tolong(replace_string(replace_string(replace_string(replace_string(extract(regex, 1, uom), 'K', '000'), 'M', '000000'), 'B', '000000000'), 'T', '000000000000')) };
cluster('<aci-prod>').database('ACI').vwMeterAll
| where Provider != 'AWS'
| where isnotempty(UnitOfMeasure)
| summarize MeterCount = count()
    // DEBUG: , make_set(MeterName)
    by
    // DEBUG: Provider,
    UnitOfMeasure
    // DEBUG: , strlen(UnitOfMeasure)
//
// Parse number-only values
| extend UsageToPricingRate = unabbrev(@'^(\d+[KMBT]?)$', replace_string(UnitOfMeasure, ' ', ''))
| extend DistinctUnits = iff(isnotempty(UsageToPricingRate), 'Count', '')
//
// Parse all other numbers
| extend UsageToPricingRate = iff(isnotempty(UsageToPricingRate), UsageToPricingRate, unabbrev(@'^ *(\d+[KMBT]?)[ /]', toupper(UnitOfMeasure)))
//
// If no number, assume 1
| extend UsageToPricingRate = iff(isnotempty(UsageToPricingRate), UsageToPricingRate, 1)
//
// Parse unit after number
| extend DistinctUnits = iff(isnotempty(DistinctUnits), DistinctUnits, replace_regex(extract(@'^ *\d+[KMBT]? *(.*) *$', 1, UnitOfMeasure), @'^/', 'Count/'))
//
// Parse unit when no number
| extend DistinctUnits = iff(isnotempty(DistinctUnits), DistinctUnits, extract(@'^ *([^\d]+) *$', 1, UnitOfMeasure))
//
// Cleanup...
| extend DistinctUnits = iff(DistinctUnits matches regex '^[a-z]', strcat(toupper(substring(DistinctUnits, 0, 1)), substring(DistinctUnits, 1)), DistinctUnits)
| extend DistinctUnits = replace_regex(DistinctUnits, @'( )?Hr(s )?', @'\1Hour\2')
| extend DistinctUnits = replace_regex(DistinctUnits, @'(App|Call|Certificate|Connection|Day|Device|Domain|Hour|Key|Machine|Meter|Minute|Month|Node|Pack|Pipeline|Plan|Resource|Second|Subscription|Unit|User|Website)(/.*)?$', @'\1s\2')
| extend DistinctUnits = replace_regex(DistinctUnits, @'/(Second|Minute|Hour|Day|Month)s$', @'/\1')
| extend DistinctUnits = case(
    DistinctUnits startswith '1 ', substring(DistinctUnits, 2),
    DistinctUnits startswith 'Annual ', strcat(replace_string(DistinctUnits, 'Annual ', ''), '/Year'),
    DistinctUnits startswith 'Daily ', strcat(replace_string(DistinctUnits, 'Daily ', ''), '/Day'),
    DistinctUnits startswith 'Hourly ', strcat(replace_string(DistinctUnits, 'Hourly ', ''), '/Hour'),
    DistinctUnits startswith 'Per ', replace_regex(DistinctUnits, @'^Per ', ''),
    DistinctUnits endswith '(s)', replace_regex(DistinctUnits, @'\(s\)$', 's'),
    DistinctUnits endswith ' (DU)', replace_regex(DistinctUnits, @' \(DU\)$', ''),
    DistinctUnits == 'Activity Runs', 'Runs',
    DistinctUnits == 'API Calls', 'Requests',
    DistinctUnits == 'CallingMinutes', 'Minutes',
    DistinctUnits == 'Concurrent DVC', 'Configurations',
    DistinctUnits matches regex @'^(Virtual User) Minutes$', 'Minutes',
    DistinctUnits matches regex @'^(Content|Core|Instance|Relay) Hours$', 'Hours',
    DistinctUnits matches regex @'^(MAUS|MAUs)$', 'Users/Month',
    DistinctUnits matches regex @'^(Named) Users$', 'Users',
    DistinctUnits == '1,000s', 'Transactions in Thousands',
    DistinctUnits == 'Key Use', 'Keys',
    DistinctUnits == 'VM', 'Virtual Machines',
    DistinctUnits)
| order by UnitOfMeasure asc
// Output with quotes to avoid spaces being lost, then replace '"""' with '"'
| extend UnitOfMeasure = strcat('"', UnitOfMeasure, '"')
```

<br>

## 🗺️ Regions

<sup>
    📅 Updated: Sep 16, 2023_<br>
    ➡️ Source: Commerce Platform Data Model team<br>
</sup>

<br>

The [Regions.csv](./Regions.csv) file contains data from several internal sources. We shouldn't need to update this file as Cost Management data is standardizing on Azure regions.

> ℹ️ _Internal only: Contact the CPDM PM team for any updates._

<br>
