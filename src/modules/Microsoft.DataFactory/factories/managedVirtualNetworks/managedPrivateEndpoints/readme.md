# DataFactory Factories ManagedVirtualNetwork ManagedPrivateEndpoints `[Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints]`

<sup>Copied from [Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints](https://github.com/Azure/ResourceModules/tree/main/modules/Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints) - **CARML v0.9** (Feb 2, 2023>)</sup>

<!-- markdownlint-disable -->
<!-- spell-checker:disable -->

This module deploys a Managed Private Endpoint in a Managed Virtual Network for an Azure Data Factory

## Navigation

- [Navigation](#navigation)
- [Resource Types](#resource-types)
- [Parameters](#parameters)
- [Outputs](#outputs)
- [Cross-referenced modules](#cross-referenced-modules)

## Resource Types

| Resource Type                                                                    | API Version                                                                                                                                              |
| :------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints` | [2018-06-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.DataFactory/2018-06-01/factories/managedVirtualNetworks/managedPrivateEndpoints) |

## Parameters

**Required parameters**

| Parameter Name              | Type   | Description                                                                           |
| :-------------------------- | :----- | :------------------------------------------------------------------------------------ |
| `fqdns`                     | array  | Fully qualified domain names.                                                         |
| `groupId`                   | string | The groupId to which the managed private endpoint is created.                         |
| `managedVirtualNetworkName` | string | The name of the parent managed virtual network.                                       |
| `name`                      | string | The managed private endpoint resource name.                                           |
| `privateLinkResourceId`     | string | The ARM resource ID of the resource to which the managed private endpoint is created. |

**Conditional parameters**

| Parameter Name    | Type   | Description                                                                                       |
| :---------------- | :----- | :------------------------------------------------------------------------------------------------ |
| `dataFactoryName` | string | The name of the parent data factory. Required if the template is used in a standalone deployment. |

**Optional parameters**

| Parameter Name           | Type | Default Value | Description                                               |
| :----------------------- | :--- | :------------ | :-------------------------------------------------------- |
| `enableDefaultTelemetry` | bool | `True`        | Enable telemetry via a Globally Unique Identifier (GUID). |

## Outputs

| Output Name         | Type   | Description                                                  |
| :------------------ | :----- | :----------------------------------------------------------- |
| `name`              | string | The name of the deployed managed private endpoint.           |
| `resourceGroupName` | string | The resource group of the deployed managed private endpoint. |
| `resourceId`        | string | The resource ID of the deployed managed private endpoint.    |

## Cross-referenced modules

_None_
