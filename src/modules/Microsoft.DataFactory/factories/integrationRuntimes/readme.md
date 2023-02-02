# Data Factory Integration RunTimes `[Microsoft.DataFactory/factories/integrationRuntimes]`

<sup>Copied from [Microsoft.DataFactory/factories/integrationRuntimes](https://github.com/Azure/ResourceModules/tree/main/modules/Microsoft.DataFactory/factories/integrationRuntimes) - **CARML v0.9** (Feb 2, 2023>)</sup>

<!-- markdownlint-disable -->
<!-- spell-checker:disable -->

This module deploys a Managed or Self-Hosted Integration Runtime for an Azure Data Factory

## Navigation

- [Navigation](#navigation)
- [Resource types](#resource-types)
- [Parameters](#parameters)
- [Outputs](#outputs)
- [Cross-referenced modules](#cross-referenced-modules)

## Resource types

| Resource Type                                         | API Version                                                                                                                   |
| :---------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------- |
| `Microsoft.DataFactory/factories/integrationRuntimes` | [2018-06-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.DataFactory/2018-06-01/factories/integrationRuntimes) |

## Parameters

**Required parameters**

| Parameter Name | Type   | Allowed Values          | Description                          |
| :------------- | :----- | :---------------------- | :----------------------------------- |
| `name`         | string |                         | The name of the Integration Runtime. |
| `type`         | string | `[Managed, SelfHosted]` | The type of Integration Runtime.     |

**Conditional parameters**

| Parameter Name    | Type   | Description                                                                                             |
| :---------------- | :----- | :------------------------------------------------------------------------------------------------------ |
| `dataFactoryName` | string | The name of the parent Azure Data Factory. Required if the template is used in a standalone deployment. |

**Optional parameters**

| Parameter Name              | Type   | Default Value | Description                                                         |
| :-------------------------- | :----- | :------------ | :------------------------------------------------------------------ |
| `enableDefaultTelemetry`    | bool   | `True`        | Enable telemetry via a Globally Unique Identifier (GUID).           |
| `managedVirtualNetworkName` | string | `''`          | The name of the Managed Virtual Network if using type "Managed" .   |
| `typeProperties`            | object | `{object}`    | Integration Runtime type properties. Required if type is "Managed". |

### Parameter Usage: [`typeProperties`](https://docs.microsoft.com/en-us/azure/templates/microsoft.datafactory/factories/integrationruntimes?tabs=bicep#integrationruntime-objects)

<details>

<summary>Parameter JSON format</summary>

```json
"typeProperties": {
    "value": {
        "computeProperties": {
            "location": "AutoResolve"
        }
    }
}
```

<details>

<summary>Bicep format</summary>

```bicep
typeProperties: {
    computeProperties: {
        location: 'AutoResolve'
    }
}
```

<details>
<p>

## Outputs

| Output Name         | Type   | Description                                                            |
| :------------------ | :----- | :--------------------------------------------------------------------- |
| `name`              | string | The name of the Integration Runtime.                                   |
| `resourceGroupName` | string | The name of the Resource Group the Integration Runtime was created in. |
| `resourceId`        | string | The resource ID of the Integration Runtime.                            |

## Cross-referenced modules

_None_
