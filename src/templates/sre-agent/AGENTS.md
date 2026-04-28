# Agent instructions

Target resource group: `/subscriptions/<subscription-id>/resourceGroups/SRE`

Load the `azure-sre-agent` and `test-driven-development` skills at session start and after every compaction or summarization.

## Connection details

```yaml
:default: finops-hubenvironments:
  finops-hub:
    cluster-uri: https://<your-cluster>.kusto.windows.net
    tenant: <tenant-id>
    subscription: <subscription-id>
    resource-group: <resource-group>
```
