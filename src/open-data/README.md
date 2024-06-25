# 📇 Open data

Our open data solutions are pretty straightforward. Nothing to deploy. Just use them as needed. Below you will find internal notes about data sources and how to update the data, as appropriate.

On this page:

- [📏 Pricing units](#-pricing-units)
- [🗺️ Regions](#️-regions)
- [🗺️ Resource types](#️-resource-types)
- [🎛️ Services](#️-services)

---

## 📏 Pricing units

<sup>
    📅 Updated: Jun 1, 2024<br>
    ➡️ Source: Cost Management team<br>
</sup>

The [PricingUnits.csv](./PricingUnits.csv) file contains the list of all unique `UnitOfMeasure` values. This data will need to be updated periodically.

Use the following query to update the data:

```kql
let unabbrev = (regex: string, uom: string) { tolong(replace_string(replace_string(replace_string(replace_string(extract(regex, 1, uom), 'K', '000'), 'M', '000000'), 'B', '000000000'), 'T', '000000000000')) };
Meters
| where Provider != 'AWS'
| where IsMicrosoftInternalUseOnly != 'true'
| where ProductOwnershipSellingMotion != 'Marketplace'
| where isnotempty(UnitOfMeasure)
| where UnitOfMeasure !contains 'contact us'
| summarize AccountTypes = make_set(AccountType) by UnitOfMeasure
| extend AccountTypes = replace_string(arraystring(AccountTypes), 'EA, MCA', 'MCA, EA')
//
// Parse number-only values
| extend PricingBlockSize = unabbrev(@'^(\d+[KMBT]?)$', replace_string(UnitOfMeasure, ' ', ''))
| extend DistinctUnits = iff(isnotempty(PricingBlockSize), 'Units', '')
//
// Parse all other numbers
| extend PricingBlockSize = iff(isempty(PricingBlockSize), unabbrev(@'^ *(\d+[KMBT]?)[ /]', toupper(UnitOfMeasure)), PricingBlockSize)
//
// If no number, assume 1
| extend PricingBlockSize = iff(isempty(PricingBlockSize), 1, PricingBlockSize)
//
// Parse unit after number
| extend DistinctUnits = iff(isempty(DistinctUnits), replace_regex(extract(@'^ *\d+[KMBT]? *(.*) *$', 1, UnitOfMeasure), @'^/', 'Units/'), DistinctUnits)
//
// Parse unit when no number
| extend DistinctUnits = iff(isempty(DistinctUnits), extract(@'^ *([^\d]+) *$', 1, UnitOfMeasure), DistinctUnits)
//
// Replace non-english words
| extend DistinctUnits = replace_string(DistinctUnits, '小时', 'Hour')
| extend DistinctUnits = replace_string(DistinctUnits, '月', 'Month')
| extend DistinctUnits = replace_regex(DistinctUnits, @'[Hh]ora$', 'Hour')
| extend DistinctUnits = replace_regex(DistinctUnits, @'( |/)mes$', @'\1Month')
//
// Fix abbreviations
| extend DistinctUnits = replace_regex(DistinctUnits, @'( |/)?Hr(s )?', @'\1Hour\2')
| extend DistinctUnits = replace_regex(DistinctUnits, @'^Gb( ?/ ?Month)?$', @'GB\1')
//
// Clean up units per period
| extend DistinctUnits = replace_string(DistinctUnits, ' / ', '/')  // Don't space out the slash
| extend DistinctUnits = replace_regex(DistinctUnits, @'(App|Border|Call|Certificate|Connection|Day|Device|Domain|Hour|Key|Machine|Meter|Minute|Month|Node|Pack|Pipeline|Plan|Request|Resource|Second|Subscription|Unit|User|Website|Zone)(/.*)?$', @'\1s\2') // Always plural before slash
| extend DistinctUnits = replace_regex(DistinctUnits, @'/(Second|Minute|Hour|Day|Month)s$', @'/\1') // Always singular after slash
//
// More cleanup
| extend DistinctUnits = case(
    UnitOfMeasure == '10000s' and DistinctUnits == 'S', 'Transactions',
    DistinctUnits == '1,000s', 'Transactions in Thousands',
    DistinctUnits in ('API Calls', 'print job'), 'Requests',
    DistinctUnits == 'Concurrent DVC', 'Configurations',
    DistinctUnits == 'CallingMinutes', 'Minutes',
    DistinctUnits == 'Key Use', 'Keys',
    DistinctUnits == 'Unassigned', 'Units',
    DistinctUnits == 'VM', 'Virtual Machines',
    DistinctUnits in ('MAUS', 'MAUs'), 'Users/Month',
    DistinctUnits matches regex @'^(Annual|Daily|Hourly) ', replace_regex(replace_regex(replace_regex(replace_regex(DistinctUnits, @'^(Annual|Daily|Hourly) (.*)$', @'\2/\1'), @'/Annual$', '/Year'), @'/Daily$', '/Day'), @'/Hourly$', '/Hour'),
    DistinctUnits)
//
// Prefix cleanup
| extend DistinctUnits = replace_regex(DistinctUnits, @'^1 ', '')  // Remove duplicate quantity
| extend DistinctUnits = replace_regex(DistinctUnits, @'^[\s\pZ\pC]+', '')  // Remove leading spaces
| extend DistinctUnits = iff(DistinctUnits matches regex '^[a-z]', strcat(toupper(substring(DistinctUnits, 0, 1)), substring(DistinctUnits, 1)), DistinctUnits)  // Capitalize first word
| extend DistinctUnits = replace_regex(DistinctUnits, @'^(Per|Por) ', '')  // Remove starting "per"
| extend DistinctUnits = replace_regex(DistinctUnits, @'^(Activity|Border|Content|Core|Database|Hosted|Instance|Messaging|Named|Operation|Privacy Subject Rights|Relay|Reserved|Service|Virtual User) ', '')  // Trim extra adjectives
//
// Suffix cleanup
| extend DistinctUnits = replace_regex(DistinctUnits, @'[\s\pZ\pC]+$', '')  // Remove trailing spaces
| extend DistinctUnits = replace_regex(DistinctUnits, @' \(DU\)$', '')
| extend DistinctUnits = replace_regex(DistinctUnits, @'\(s\)$', 's')  // Always plural
//
| order by UnitOfMeasure asc
// Write as a single column with quotes to maintain spaces for easy copy/paste to CSV -- 
| project ["UnitOfMeasure,AccountTypes,PricingBlockSize,DistinctUnits"] = strcat('"', UnitOfMeasure, '",', iff(AccountTypes contains ',', '"', ''), AccountTypes, iff(AccountTypes contains ',', '"', ''), ',', PricingBlockSize ,',', DistinctUnits)
```

<br>

## 🗺️ Regions

<sup>
    📅 Updated: Jun 1, 2024<br>
    ➡️ Source: Commerce Platform Data Model team<br>
</sup>

<br>

The [Regions.csv](./Regions.csv) file contains data from several internal sources. We shouldn't need to update this file as Cost Management data is standardizing on Azure regions.

> ℹ️ _Internal only: Contact the CPDM PM team for any updates._

<br>

## 🗺️ Resource types

<sup>
    📅 Updated: Jun 1, 2024<br>
    ➡️ Source: Azure portal / Azure mobile app<br>
</sup>

<br>

The [ResourceTypes.csv](./ResourceTypes.csv) file contains data from the Azure portal. The Build-OpenData script generates the fie without any additional work.

If you find a resource type is missing, add it to [ResourceTypes.Overrides.csv](./ResourceTypes.Overrides.json). The override file supports overriding names and icons.

If you run into any issues with the script that gets the data, you can look at examples from the Azure mobile app repo @ https://aka.ms/azureapp/code.

<br>

## 🎛️ Services

<sup>
    📅 Updated: Jun 1, 2024<br>
    ➡️ Source: Cost Management team<br>
</sup>

<br>

The [Services.csv](./Services.csv) file contains the list of all unique `ConsumedService` and `ResourceType` values. This data will need to be updated periodically.

Use the following query to update the data:

```kql
union cluster('<shard-cluster>').database('<shard>*').UCDD
| where UsageDate > ago(365d)
| where isnotempty(ConsumedService)
| where ConsumedService !startswith '/subscriptions/'
| extend ParsedResourceType = tostring(extract(@'/providers/([^/]+/[^/]+)', 1, tolower(InstanceName)))
| extend ResourceType = iff(isempty(ParsedResourceType), tolower(ResourceType), ParsedResourceType)
| summarize by ConsumedServiceId, ConsumedService, ResourceType
| order by ConsumedServiceId asc, ResourceType asc
```

The **ServiceModel** column is manually applied using the following logic:

- Select the service model that best describes the level of effort required to maintain the service.
- If multiple service models apply, select the one with the highest requirements.
- Supporting services, like Defender for Cloud, are aligned to the service model of the service they are in support of.
- Use the service model declared by the service owner (e.g., Microsoft), if documented on their website.

<br>
