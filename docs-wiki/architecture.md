<!-- markdownlint-disable MD041 -->

FinOps toolkit uses Azure Bicep templates and PowerShell scripts to deploy Azure resources. Each solution utilizes different Azure services to meet specific requirements.

Starter templates that are optimized for customization will be customizable and may offer multiple deployment options. Advanced solutions, like [FinOps hubs](templates/finops-hub), may have fewer options to ensure the highest quality and completeness.

On this page:

- [📂 Folder structure](#-folder-structure)
- [🍎 About Bicep](#-about-bicep)
- [🧮 Telemetry](#-telemetry)

---

## 📂 Folder structure

| Name                                                                 | Description                      |
| -------------------------------------------------------------------- | -------------------------------- |
| [docs](../docs)                                                      | Public-facing toolkit docs.      |
| [docs-wiki](../docs-wiki)                                            | Repo wiki for internal dev docs. |
| [src](../src)                                                        | Source code and dev docs.        |
| ├─ [bicep-registry](../src/bicep-registry)                           | Bicep registry modules.          |
| ├─ [open-data](../src/open-data)                                     | Open data.                       |
| ├─ [power-bi](../src/power-bi)                                       | Power BI reports.                |
| ├─ [powershell](../src/powershell)                                   | PowerShell module functions.     |
| ├─ [templates](../src/templates)                                     | ARM deployment templates.        |
| │ &nbsp;&nbsp; └─ [finops-hub](../src/templates/finops-hub)          | FinOps hub template.             |
| └─ [workbooks](../src/workbooks)                                     | Azure Monitor workbooks.         |
| &nbsp; &nbsp;&nbsp; ├─ [governance](../src/templates/governance)     | Governance workbook.             |
| &nbsp; &nbsp;&nbsp; └─ [optimization](../src/templates/optimization) | Optimization workbook.           |

Files and folders should use kebab casing (for example, `this-is-my-folder`). The only exception is for RP namespaces in module paths.

<br>

## 🍎 About Bicep

FinOps toolkit templates are comprised of [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep) modules. Bicep is a domain-specific language that uses declarative syntax to define and deploy Azure resources. For a guided learning experience, start with the [Fundamentals of Bicep](https://learn.microsoft.com/training/paths/fundamentals-bicep/).

We prefer Bicep modules published in the official [Bicep Registry](https://github.com/Azure/bicep-registry-modules), however since there are many resource types not yet available, we also use:

- [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates)
- [Common Azure Resource Module Library (CARML)](https://github.com/Azure/ResourceModules)
- [Azure Bicep and ARM templates](https://learn.microsoft.com/azure/templates)

Note the above sources are non-authoritative. You are free to use them as a starting point, but each should be validated and tested before use. Each module we bring in should be tuned to our specific scenarios and is not expected to have any traceability back to the original source.

<br>

## 🧮 Telemetry

Every FinOps toolkit template includes a `defaultTelemetry` deployment. These should be enabled by default using an input parameter that callers can disable. Telemetry deployments are tracked using a specific ID made up of the FinOps toolkit prefix (`00f120b5-2007-6120-0000-`) followed by a 12-digit hexadecimal representation of the solution (for example, `h0b000000000` for FinOps "hubs").

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

```kusto
Deployments
| where deploymentName startswith 'pid-00f120b5-2007-6120-'
    or generatorName == 'FinOps toolkit'
```
-->

<br>
