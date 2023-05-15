# 📦 FinOps toolkit modules

All FinOps toolkit module source is available at the root of this directory. For summary details, see [public docs](../../../../docs/finops-hub/modules).

Modules:

- [hub.bicep](./hub.bicep) creates a new FinOps hub instance.

<br>

On this page:

- [🧮 Telemetry](#-telemetry)
- [🍎 About Bicep](#-about-bicep)

---

## 🧮 Telemetry

Every FinOps toolkit template includes a `defaultTelemetry` deployment. These should be enabled by default using an input parameter that callers can disable. Telemetry deployments are tracked using a specific ID made up of the FinOps toolkit prefix (`00f120b5-2007-6120-0000-`) followed by a 12-digit hexadecimal representation of the module name (e.g., `h0b000000000` for `hub.bicep`).

Include the following as the last parameter in each module and replace the `<hex-module-name>` and `<version>` placeholders:

```bicep
@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true
// The last segment of the telemetryId is used to identify this module
var telemetryId = '00f120b5-2007-6120-0000-<hex-module-name>'
var finOpsToolkitVersion = '<version>'
```

Include the following as the first resource in each module:

```bicep
// Telemetry used anonymously to count the number of times the template has been deployed.
// No information about you or your cost data is collected.
resource defaultTelemetry 'Microsoft.Resources/deployments@2022-09-01' = if (enableDefaultTelemetry) {
  name: 'pid-${telemetryId}-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      metadata: {
        _generator: {
          name: 'FinOps toolkit'
          version: finOpsToolkitVersion
        }
      }
      resources: []
    }
  }
}
```

<!--
INTERNAL ONLY: To view deployments, query ARMProd:

```kql
Deployments
| where deploymentName startswith 'pid-00f120b5-2007-6120-'
    or generatorName == 'FinOps toolkit'
```
-->

<br>

## 🍎 About Bicep

FinOps toolkit templates are comprised of [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep) modules. Bicep is a domain-specific language that uses declarative syntax to define and deploy Azure resources. For a guided learning experience, start with the [Fundamentals of Bicep](https://learn.microsoft.com/training/paths/fundamentals-bicep/).

We prefer Bicep modules published in the official [Bicep Registry](https://github.com/Azure/bicep-registry-modules), however since there are many resource types not yet available, we also use:

- [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates)
- [Common Azure Resource Module Library (CARML)](https://github.com/Azure/ResourceModules)
- [Azure Bicep and ARM templates](https://learn.microsoft.com/azure/templates)

Note the above sources are non-authoritative. You are free to use them as a starting point, but each should be validated and tested before use. Each module we bring in should be tuned to our specific scenarios and is not expected to have any traceability back to the original source.
