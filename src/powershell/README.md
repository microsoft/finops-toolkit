# FinOps Toolkit PowerShell Module

**FinOpsToolkit** is a PowerShell module that can deploy and manage resusable FinOps solutions in Azure.

## Functions

### Deploy-FinOpsHub

#### Syntax

`Deploy-FinOpsHub [-Name] <String> [-ResourceGroup] <String> [-Location] <String> [[-Version] <String>] [-Preview] [[-StorageSku] <String>] [[-Tags] <Hashtable>] [-WhatIf] [-Confirm] [<CommonParameters>]
`

#### Parameters

|      Name     |   Type    | Description                                                                                        | Required? | Default Value |
|:-------------:|-----------|----------------------------------------------------------------------------------------------------|-----------|---------------|
|      Name     |  string   | Name of the FinOps hub instance.                                                                   | true      |               |
| ResourceGroup |  string   | Name of the resource group to deploy to. Will be created if it doesn't exist.                      | true      |               |
|    Location   |  string   | Azure location to execute the deployment from.                                                     | true      |               |
|    Version    |  string   | Optional. Version of FinOps hub template to use. Defaults = "latest".                              | false     | latest        |
|    Preview    |  switch   | Optional. Indicates that a pre-release version of FinOps hub can be used when -Version is "latest".| false     |               |
|   StorageSku  |  string   | Optional. Storage account SKU. Premium_LRS = Lowest cost, Premium_ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Default = "Premium_LRS".                                                                                           | false     | Premium_LRS   |
|      Tags     | hashtable | Optional. Tags for all resources.                                                                  | false     |               |

#### Example 1

`Deploy-FinOpsHub -Name MyHub -ResourceGroup MyExistingResourceGroup -Location westus`

Deploys a new FinOps hub instance named MyHub to an existing resource group named MyExistingResourceGroup.

#### Example 2

`Deploy-FinOpsHub -Name MyHub -Location westus -Version 0.0.1`

Deploys a new FinOps hub instance named MyHub using version 0.0.1 of the template.

### Get-FinOpsToolkitVersions

#### Syntax

`Get-FinOpsToolkitVersion [-Latest] [-Preview] [<CommonParameters>]`

#### Parameters

|      Name     | Type   | Description                                               | Required? | Default Value  |
|:-------------:|--------|-----------------------------------------------------------|-----------|----------------|
|    Latest     | switch | Will only return the latest version number of the FinOps. |   false   |                |
|   Preview     | switch | Includes pre-releases.                                    |   false   |                |

##### Example 1

`Get-FinOpsToolkitVersion`

Returns all available released version numbers of the FinOps toolkit.

##### Example 2

`Get-FinOpsToolkitVersion -Latest`

Returns only the latest version number of the FinOps toolkit.
