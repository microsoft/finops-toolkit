# Agent Instructions

Target resource group: `/subscriptions/cab7feeb-759d-478c-ade6-9326de0651ff/resourceGroups/SRE`

Load the `azure-sre-agent` and `test-driven-development` skills at session start and after every compaction or summarization.

## Connection details

```yaml
:default: finops-hubenvironments:
  finops-hub:
    cluster-uri: https://msbw-finops-hub.westus.kusto.windows.net
    tenant: 16b3c013-d300-468d-ac64-7eda0820b6d3
    subscription: cab7feeb-759d-478c-ade6-9326de0651ff
    resource-group: finops-hub
```
