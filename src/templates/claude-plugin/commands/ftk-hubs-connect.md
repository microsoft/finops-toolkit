# Connect to a FinOps hub cluster

## Step 1: Use the cluster identifier, if specified

If the user specified a cluster, check `.ftk/environments.local.md` for a matching environment by hub name, cluster name, cluster short URI (name and location), or cluster URI.

If the cluster has already been added to `.ftk/environments.local.md`, announce that you'll use that FinOps hub instance for the session and skip to step 4.

If the cluster was not found in `.ftk/environments.local.md`, go to step 2 to find FinOps hub instances that you can connect to.

## Step 2: Find FinOps hub instances, if not specified

If a cluster was identified and found in the previous step, skip this step.

If a cluster was not identified or was not found in the previous step, use this `Azure Resource Graph` query to find FinOps hub instances that you can connect to:

```kusto
resources
| where type =~ "microsoft.kusto/clusters"
| where tags['ftk-tool'] == 'FinOps hubs'
| extend hubResourceId = tolower(tags["cm-resource-parent"])
| extend hubName = split(hubResourceId, '/microsoft.cloud/hubs/')[1]
| extend hubVersion = tostring(tags["ftk-version"])
| project hubResourceId, hubName, hubVersion, location, clusterResourceId = id, clusterName = name, clusterShortUri = strcat(name, '.', location), clusterUri = properties.uri, resourceGroup, subscriptionId
```

Filter this list based on the user's input, if provided.

Notes about the columns:

- Use the `clusterShortUri` to refer to the FinOps hub instance.
- Also accept the `hubName`, `clusterName`, or `resourceGroup` to refer to the FinOps hub instance as long as they are unique. If there are multiple FinOps hub instances with the same identifier, list them and ask which the user should use.
- Use the `clusterUri` to connect to the cluster using `#azmcp-kusto-query`.
- The `hubVersion` is the version of the FinOps hub instance. Format this value is a string using Semantic Versioning (SemVer) format (e.g., `major.minor` or `major.minor.patch` or `major.minor-prerelease`).

Tell the user how many FinOps hub instances you found that matched their inputs, if provided. If there is only one FinOps hub instance, announce that you will use that FinOps hub instance for this session and skip to step 4. If there are multiple FinOps hub instances, list them with the following details:

- `hubName`
- `hubVersion`
- `clusterShortUri`
- Subscription name

If you don't find any FinOps hub instances, inform the user that you couldn't find any FinOps hubs and ask them to provide a subscription or cluster URI to connect. If they provide a subscription, repeat step 2 with that subscriptioin name or ID. If they provide a cluster URI, use that for the session and skip to step 4.

## Step 3: Ask which FinOps hub instance to use

If a FinOps hub instance was identified in the previous steps, skip this step.

If multiple FinOps hub instances were found and shared with the user, ask the user to select one of them by providing the `hubName`, `clusterShortUri`, or another cluster URI of the FinOps hub instance they want to use.

## Step 4: Validate the FinOps hub instance

If a FinOps hub instance was identified in a previous step, run the following query with the #azmcp-kusto-query command to validate the FinOps hub instance:

```kusto
let version = toscalar(database('Ingestion').HubSettings | project version);
Costs
| summarize
    Cost = numberstring(sum(EffectiveCost)),
    Months = dcount(startofmonth(ChargePeriodStart)),
    DataLastUpdated = daterange(max(ChargePeriodStart))
    by
        HubVersion = version,
        BillingCurrency
```

Announce the name and version of the FinOps hub instance you are connecting to, when data was last updated, and how much cost is covered over how many months. Format the cost using the billing currency. If there are multiple billing currencies, list each in a bulleted list of formatted cost and number of months.

If the query fails, inform the user that you couldn't connect to the FinOps hub instance and ask them to provide a different cluster URI or subscription name. If they provide a cluster URI, repeat step 4 with that URI. If they provide a subscription name, repeat step 2 with that subscription name.

## Step 5: Save the environment

After validating the FinOps hub instance, save the connection details to `.ftk/environments.local.md`:

1. Read the existing file if it exists to preserve other environments
2. Add or update the environment entry using the `clusterShortUri` as the environment name
3. Include `cluster-uri`, `tenant`, `subscription`, and `resource-group` values
4. Set `default` to this environment if no default exists or if this is the only environment

Example format:

```markdown
---
default: myhub.eastus
environments:
  myhub.eastus:
    cluster-uri: https://myhub.eastus.kusto.windows.net
    tenant: 00000000-0000-0000-0000-000000000000
    subscription: my-subscription
    resource-group: rg-finops
---
```

See `references/settings-format.md` for the complete file format documentation.

## Step 6: Run a health check

After connecting to the FinOps hub instance, inform the user they can use the `/ftk-hubs-healthCheck` prompt to run a health check.
