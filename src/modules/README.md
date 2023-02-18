# FinOps toolkit modules

All FinOps toolkit module source is available at the root of this directory. For summary details, see [public docs](../../docs/templates/modules).

Modules:

- [hub.bicep](./hub.bicep) creates a new FinOps hub instance.

<br>

On this page:

- [Telemetry](#telemetry)
- [About dependencies](#about-dependencies)
- [About Bicep](#about-bicep)

---

## Telemetry

Every FinOps toolkit module includes a `defaultTelemetry` deployment. These should be enabled by default using an input parameter that callers can disable. Telemetry deployments are tracked using a specific ID made up of the FinOps toolkit prefix (`00f120b5-2007-6120-0000-`) followed by a 12-digit hexadecimal representation of the module name (e.g., `h0b000000000` for `hub.bicep`).

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

## About dependencies

FinOps toolkit modules utilize publicly shared modules from the [Common Azure Resource Module Library (CARML)](https://github.com/Azure/ResourceModules). Each dependency is stored in this directory in folders per resource provider with nested resource types.

> _**NOTE:** Each the readme file in each folder is not updated and may have broken links. They are kept for reference only._

- [Microsoft.DataFactory/factories](./Microsoft.DataFactory/factories)
- [Microsoft.Storage/storageAccounts](./Microsoft.Storage/storageAccounts)

### Adding and updating modules

1. Download the latest [CARML release](https://github.com/Azure/ResourceModules/releases).
2. Extract the ZIP file and copy the folders for each resource type you need.
3. Remove any unnecessary folders like `.bicep` and `.test`.
4. Add the following under the first header for each README.md file:

   ```markdown
   <sup>Copied from [<resource-type>](https://github.com/Azure/ResourceModules/tree/main/modules/<resource-type>) - **CARML v<version>** (<copy-date:Mmm d, yyyy>)</sup>

   <!-- markdownlint-disable -->
   <!-- spell-checker:disable -->
   ```

   <!-- The next 2 lines re-enable MDlint and the spell checker for the rest of the file -->
   <!-- markdownlint-restore -->
   <!-- spell-checker:enable -->

5. Add the following at the top of each deploy.bicep file:

   ```bicep
   // Source: https://github.com/Azure/ResourceModules/blob/main/modules/<resource-type>/deploy.bicep
   // Date: <copy-date:yyyy-MM-dd>
   // Version: <version>
   ```

6. Review the deploy.bicep file and remove all unneeded settings and nested resource types.

<br>

## About Bicep

FinOps toolkit templates are comprised of [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep) modules. Bicep is a domain-specific language that uses declarative syntax to define and deploy Azure resources. For a guided learning experience, start with the [Fundamentals of Bicep](https://learn.microsoft.com/training/paths/fundamentals-bicep/).
