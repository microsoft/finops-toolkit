# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Deploys a FinOps hub instance.

    .DESCRIPTION
    The Deploy-FinOpsHub command either creates a new or updates an existing FinOps hub instance by deploying an Azure Resource Manager deployment template. The FinOps hub template is downloaded from GitHub.

    Deploy-FinOpsHub calls Initialize-FinOpsHubDeployment before deploying the template.

    .PARAMETER Name
    Required. Name of the hub. Used to ensure unique resource names.

    .PARAMETER ResourceGroupName
    Required. Name of the resource group to deploy to. Will be created if it doesn't exist.

    .PARAMETER Location
    Required. Azure location where all resources should be created. See https://aka.ms/azureregions.

    .PARAMETER Version
    Optional. Version of the FinOps hub template to use. Default = "latest".

    .PARAMETER Preview
    Optional. Indicates that preview releases should also be included. Default = false.

    .PARAMETER StorageSku
    Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: Premium_LRS, Premium_ZRS. Default: Premium_LRS.

    .PARAMETER EnableInfrastructureEncryption
    Optional. Enable infrastructure encryption on the storage account. Default = false.

    .PARAMETER EnablePurgeProtection
    Optional. Enable purge protection for the Key Vault. Default = false.

    .PARAMETER RemoteHubStorageUri
    Optional. Storage account to push data to for ingestion into a remote hub.

    .PARAMETER RemoteHubStorageKey
    Optional. Storage account key to use when pushing data to a remote hub.

    .PARAMETER EnableManagedExports
    Optional. Enable managed exports where your FinOps hub instance creates and runs Cost Management exports on your behalf. Not supported for Microsoft Customer Agreement (MCA) billing profiles. Default = false.

    .PARAMETER DataExplorerName
    Optional. Name of the Azure Data Explorer cluster to use for advanced analytics. If empty, Azure Data Explorer will not be deployed. Required to use with Power BI if you have more than $2-5M/mo in costs being monitored. Default: "" (do not use).

    .PARAMETER DataExplorerSku
    Optional. Name of the Azure Data Explorer SKU. Default: "Dev(No SLA)_Standard_E2a_v4".

    .PARAMETER DataExplorerCapacity
    Optional. Number of nodes to use in the cluster. Allowed values: 1 for the Basic SKU tier and 2-1000 for Standard. Default: 1 for dev/test SKUs, 2 for standard SKUs.

    .PARAMETER FabricQueryUri
    Optional. Microsoft Fabric eventhouse query URI. Default: "" (do not use).

    .PARAMETER FabricCapacityUnits
    Optional. Number of capacity units for the Microsoft Fabric capacity. This is the number in your Fabric SKU (e.g., Trial = 1, F2 = 2, F64 = 64). Allowed values: 1-2048. Default: 2.

    .PARAMETER Tags
    Optional. Tags to apply to all resources. We will also add the cm-resource-parent tag for improved cost roll-ups in Cost Management.

    .PARAMETER TagsByResource
    Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.

    .PARAMETER ScopesToMonitor
    Optional. Array of scope IDs to monitor and ingest cost for. Used with managed exports to automatically create Cost Management exports. Scope ID formats:
    - EA billing account: /providers/Microsoft.Billing/billingAccounts/{enrollment-number}
    - MCA billing profile: /providers/Microsoft.Billing/billingAccounts/{billing-account-id}/billingProfiles/{billing-profile-id}
    - Subscription: /subscriptions/{subscription-id}
    - Resource group: /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}
    Example: @('/subscriptions/00000000-0000-0000-0000-000000000000', '/subscriptions/11111111-1111-1111-1111-111111111111')

    .PARAMETER ExportRetentionInDays
    Optional. Number of days of data to retain in the msexports container. Default: 0.

    .PARAMETER IngestionRetentionInMonths
    Optional. Number of months of data to retain in the ingestion container. Default: 13.

    .PARAMETER DataExplorerRawRetentionInDays
    Optional. Number of days of data to retain in the Data Explorer *_raw tables. Default: 0.

    .PARAMETER DataExplorerFinalRetentionInMonths
    Optional. Number of months of data to retain in the Data Explorer *_final_v* tables. Default: 13.

    .PARAMETER EnablePublicAccess
    Optional. Enable public access to the data lake.  Default: true.

    .PARAMETER VirtualNetworkAddressPrefix
    Optional. Address space for the workload. A /26 is required for the workload. Default: "10.20.30.0/26".

    .EXAMPLE
    Deploy-FinOpsHub -Name MyHub -ResourceGroupName MyNewResourceGroup -Location westus -DataExplorerName MyFinOpsHubCluster

    Deploys a FinOps hub instance named MyHub to the MyNewResourceGroup resource group with a new MyFinOpsHubCluster Data Explorer cluster. If the resource group does not exist, it will be created. If the hub already exists, it will be updated to the latest version.

    .EXAMPLE
    Deploy-FinOpsHub -Name MyHub -ResourceGroupName MyExistingResourceGroup -Location westus -Version 0.1.1

    Deploys a FinOps hub instance named MyHub to the MyExistingResourceGroup resource group using version 0.1.1 of the template. This version is required for Microsoft Online Services Agreement (MOSA) subscriptions since FOCUS exports aren't available from Cost Management. If the resource group does not exist, it will be created. If the hub already exists, it will be updated to version 0.1.1.

    .LINK
    https://aka.ms/ftk/Deploy-FinOpsHub
#>
function Deploy-FinOpsHub
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "")]
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]
        $Location,

        [Parameter()]
        [string]
        $Version = 'latest',

        [Parameter()]
        [switch]
        $Preview,

        [Parameter()]
        [ValidateSet('Premium_LRS', 'Premium_ZRS')]
        [string]
        $StorageSku = 'Premium_LRS',

        [Parameter()]
        [switch]
        $EnableInfrastructureEncryption,

        [Parameter()]
        [switch]
        $EnablePurgeProtection,

        [Parameter()]
        [string]
        $RemoteHubStorageUri,

        [Parameter()]
        [string]
        $RemoteHubStorageKey,

        [Parameter()]
        [switch]
        $EnableManagedExports,

        [Parameter()]
        [string]
        $DataExplorerName,

        [Parameter()]
        [ValidateSet('Dev(No SLA)_Standard_E2a_v4', 'Dev(No SLA)_Standard_D11_v2', 'Standard_D11_v2', 'Standard_D12_v2', 'Standard_D13_v2', 'Standard_D14_v2', 'Standard_D16d_v5', 'Standard_D32d_v4', 'Standard_D32d_v5', 'Standard_DS13_v2+1TB_PS', 'Standard_DS13_v2+2TB_PS', 'Standard_DS14_v2+3TB_PS', 'Standard_DS14_v2+4TB_PS', 'Standard_E2a_v4', 'Standard_E2ads_v5', 'Standard_E2d_v4', 'Standard_E2d_v5', 'Standard_E4a_v4', 'Standard_E4ads_v5', 'Standard_E4d_v4', 'Standard_E4d_v5', 'Standard_E8a_v4', 'Standard_E8ads_v5', 'Standard_E8as_v4+1TB_PS', 'Standard_E8as_v4+2TB_PS', 'Standard_E8as_v5+1TB_PS', 'Standard_E8as_v5+2TB_PS', 'Standard_E8d_v4', 'Standard_E8d_v5', 'Standard_E8s_v4+1TB_PS', 'Standard_E8s_v4+2TB_PS', 'Standard_E8s_v5+1TB_PS', 'Standard_E8s_v5+2TB_PS', 'Standard_E16a_v4', 'Standard_E16ads_v5', 'Standard_E16as_v4+3TB_PS', 'Standard_E16as_v4+4TB_PS', 'Standard_E16as_v5+3TB_PS', 'Standard_E16as_v5+4TB_PS', 'Standard_E16d_v4', 'Standard_E16d_v5', 'Standard_E16s_v4+3TB_PS', 'Standard_E16s_v4+4TB_PS', 'Standard_E16s_v5+3TB_PS', 'Standard_E16s_v5+4TB_PS', 'Standard_E64i_v3', 'Standard_E80ids_v4', 'Standard_EC8ads_v5', 'Standard_EC8as_v5+1TB_PS', 'Standard_EC8as_v5+2TB_PS', 'Standard_EC16ads_v5', 'Standard_EC16as_v5+3TB_PS', 'Standard_EC16as_v5+4TB_PS', 'Standard_L4s', 'Standard_L8as_v3', 'Standard_L8s', 'Standard_L8s_v2', 'Standard_L8s_v3', 'Standard_L16as_v3', 'Standard_L16s', 'Standard_L16s_v2', 'Standard_L16s_v3', 'Standard_L32as_v3', 'Standard_L32s_v3')]
        [string]
        $DataExplorerSku = 'Dev(No SLA)_Standard_D11_v2',

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]
        $DataExplorerCapacity = 1,

        [Parameter()]
        [string]
        $FabricQueryUri,

        [Parameter()]
        [ValidateRange(1, 2048)]
        [int]
        $FabricCapacityUnits = 2,

        [Parameter()]
        [ValidateRange(0, 9999)]
        [int]
        $DataExplorerRawRetentionInDays = 0,

        [Parameter()]
        [ValidateRange(0, 999)]
        [int]
        $DataExplorerFinalRetentionInMonths = 13,

        [Parameter()]
        [switch]
        $DisablePublicAccess,

        [Parameter()]
        [string]
        $VirtualNetworkAddressPrefix = '10.20.30.0/26',

        [Parameter()]
        [hashtable]
        $Tags,

        [Parameter()]
        [hashtable]
        $TagsByResource,

        [Parameter()]
        [string[]]
        $ScopesToMonitor = @(),

        [Parameter()]
        [ValidateRange(0, 9999)]
        [int]
        $ExportRetentionInDays = 0,

        [Parameter()]
        [ValidateRange(0, 999)]
        [int]
        $IngestionRetentionInMonths = 13
    )

    # Initialize toolkitPath before try block to ensure cleanup works even if early failure occurs
    # Fixes issue #665: If an error occurred before $toolkitPath was set, the finally block failed
    # with 'Cannot bind argument to parameter Path because it is null', masking the real error
    $toolkitPath = $null

    try
    {
        # Ensure TEMP environment variable is set for Linux/Mac/Cloud Shell compatibility
        # Bicep CLI requires TEMP to be set for intermediate file operations
        if (-not $env:TEMP)
        {
            $env:TEMP = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar)
        }

        # Create resource group if it doesn't exist
        $resourceGroupObject = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction 'SilentlyContinue'
        if (-not $resourceGroupObject -and (Test-ShouldProcess $PSCmdlet $ResourceGroupName 'CreateResourceGroup'))
        {
            $resourceGroupObject = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        }

        # Create folder for download
        $toolkitPath = Join-Path ([System.IO.Path]::GetTempPath()) -ChildPath 'FinOpsToolkit'
        if (Test-ShouldProcess $PSCmdlet $toolkitPath 'CreateTempDirectory')
        {
            New-Directory -Path $toolkitPath
        }

        # Init deployment (register providers)
        Initialize-FinOpsHubDeployment -WhatIf:$WhatIfPreference

        # Download template
        if (Test-ShouldProcess $PSCmdlet $Version 'DownloadTemplate')
        {
            Save-FinOpsHubTemplate -Version $Version -Preview:$Preview -Destination $toolkitPath
            $bicepFile = Get-ChildItem -Path $toolkitPath -Include 'main.bicep' -Recurse | Where-Object -FilterScript { $_.FullName -like '*finops-hub-v*' }
            if (-not $bicepFile)
            {
                throw ($LocalizedData.Hub_Deploy_TemplateNotFound -f $toolkitPath)
            }

            $parameterSplat = @{
                TemplateFile            = $bicepFile.FullName
                TemplateParameterObject = @{
                    hubName    = $Name
                    storageSku = $StorageSku
                }
            }

            if ($Version -eq 'latest' -or [version]$Version -ge '0.4')
            {
                $parameterSplat.TemplateParameterObject.Add('remoteHubStorageUri', $RemoteHubStorageUri)
                $parameterSplat.TemplateParameterObject.Add('remoteHubStorageKey', $RemoteHubStorageKey)
            }

            if ($Version -eq 'latest' -or [version]$Version -ge '0.7')
            {
                $parameterSplat.TemplateParameterObject.Add('enableInfrastructureEncryption', $EnableInfrastructureEncryption.IsPresent)
                $parameterSplat.TemplateParameterObject.Add('dataExplorerName', $DataExplorerName)
                $parameterSplat.TemplateParameterObject.Add('dataExplorerSku', $DataExplorerSku)
                $parameterSplat.TemplateParameterObject.Add('dataExplorerCapacity', $DataExplorerCapacity)
                $parameterSplat.TemplateParameterObject.Add('dataExplorerRawRetentionInDays', $DataExplorerRawRetentionInDays)
                $parameterSplat.TemplateParameterObject.Add('dataExplorerFinalRetentionInMonths', $DataExplorerFinalRetentionInMonths)
                $parameterSplat.TemplateParameterObject.Add('enablePublicAccess', -not $DisablePublicAccess)
                $parameterSplat.TemplateParameterObject.Add('virtualNetworkAddressPrefix', $VirtualNetworkAddressPrefix)
                $parameterSplat.TemplateParameterObject.Add('exportRetentionInDays', $ExportRetentionInDays)
                $parameterSplat.TemplateParameterObject.Add('ingestionRetentionInMonths', $IngestionRetentionInMonths)
                $parameterSplat.TemplateParameterObject.Add('scopesToMonitor', $ScopesToMonitor)
            }

            if ($Version -eq 'latest' -or [version]$Version -ge '0.10')
            {
                $parameterSplat.TemplateParameterObject.Add('fabricQueryUri', $FabricQueryUri)
                $parameterSplat.TemplateParameterObject.Add('fabricCapacityUnits', $FabricCapacityUnits)
            }

            if ($Version -eq 'latest' -or [version]$Version -ge '12.0')
            {
                $parameterSplat.TemplateParameterObject.Add('enableManagedExports', $EnableManagedExports)
            }

            if ($Version -eq 'latest' -or [version]$Version -ge '13.0')
            {
                $parameterSplat.TemplateParameterObject.Add('enablePurgeProtection', $EnablePurgeProtection.IsPresent)
            }

            if ($Tags -and $Tags.Keys.Count -gt 0)
            {
                $parameterSplat.TemplateParameterObject.Add('tags', $Tags)
            }

            if ($TagsByResource -and $TagsByResource.Keys.Count -gt 0)
            {
                $parameterSplat.TemplateParameterObject.Add('tagsByResource', $TagsByResource)
            }
        }

        # Run the deployment
        if (Test-ShouldProcess $PSCmdlet $ResourceGroupName 'DeployFinOpsHub')
        {
            Write-Verbose -Message ($LocalizedData.Hub_Deploy_Deploy -f $bicepFile.FullName, $resourceGroupObject.ResourceGroupName)
            return New-AzResourceGroupDeployment @parameterSplat -ResourceGroupName $resourceGroupObject.ResourceGroupName
        }
    }
    catch
    {
        throw $_.Exception.Message
    }
    finally
    {
        # Clean up downloaded files
        if ($toolkitPath)
        {
            Remove-Item -Path $toolkitPath -Recurse -Force -ErrorAction 'SilentlyContinue'
        }
    }
}
