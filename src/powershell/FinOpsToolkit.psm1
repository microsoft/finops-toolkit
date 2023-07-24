# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Import the localized Data
$script:localizedData = Import-LocalizedData -FileName 'FinOpsToolkit.strings.psd1' -BaseDirectory $PSScriptRoot

#region Private functions
<#
    .SYNOPSIS
        Creates a directory if it does not already exist.

    .PARAMETER Path
        Path to create directory.
#>
function New-Directory {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Verbose -Message ($LocalizedData.NewDirectory -f $Path)
        $null = New-Item -ItemType 'Directory' -Path $Path
    }
}

<#
    .SYNOPSIS
        Saves a released version of the FinOps hub bicep template to local disk.

    .PARAMETER Version
        Version of the FinOps hub to download. Defaults to latest.

    .PARAMETER Destination
        Path to store the download. Defaults to env:temp.

    .EXAMPLE
        Save-FinOpsHubTemplate

        Downloads the latest version of FinOps hub template to current users' temp folder.

    .EXAMPLE
        Save-FinOpsHubTemplate -Version '1.0.0' -Destination 'C:\myHub'

        Downloads version 1.0.0 of FinOpsHub template to c:\myHub directory.
#>
function Save-FinOpsHubTemplate {
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Version = 'latest',

        [Parameter()]
        [switch]
        $Preview,

        [Parameter()]
        [string]
        $Destination = $env:temp
    )

    $progress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        New-Directory -Path $Destination
        $releases = Get-FinOpsToolkitVersion -Latest:$($Version -eq 'Latest') -Preview:$Preview

        if ($Version -eq 'Latest') {
            $release = $releases | Select-Object -First 1
        }
        else {
            $release = $releases | Where-Object -FilterScript { $_.Version -eq $Version }
        }

        foreach ($asset in $release.Assets) {
            Write-Verbose -Message ($script:localizedData.FoundAsset -f $asset.Name)
            $saveFilePath = Join-Path -Path $Destination -ChildPath $asset.Name
            if (Test-Path -Path $saveFilePath) {
                Remove-Item -Path $saveFilePath -Recurse -Force
            }

            $null = Invoke-Webrequest -Uri $asset.Url -OutFile $saveFilePath -Verbose:$false
            if ([System.IO.Path]::GetExtension($saveFilePath) -eq '.zip') {
                Write-Verbose -Message ($script:localizedData.ExpandingZip -f $saveFilePath)
                Expand-Archive -Path $saveFilePath -DestinationPath ($saveFilePath -replace '.zip', '')
                Remove-Item -Path $saveFilePath -Recurse -Force
            }
        }
    }
    catch {
        throw $_.Exception.Message
    }
    finally {
        $ProgressPreference = $progress
    }
}
#endregion Private functions

#region Public functions
<#
    .SYNOPSIS
        Retrieves available version numbers of the FinOps toolkit.

    .PARAMETER Latest
        Will only return the latest version number of the FinOps toolkit.

    .PARAMETER Preview
        Includes pre-releases.

    .EXAMPLE
        Get-FinOpsToolkitVersions

        Returns all available released version numbers of the FinOps toolkit.

    .EXAMPLE
        Get-FinOpsToolkitVersions -Latest

        Returns only the latest version number of the FinOps toolkit.
#>
function Get-FinOpsToolkitVersion {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [switch]
        $Latest,

        [Parameter()]
        [switch]
        $Preview
    )

    $progress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $releaseUri = 'https://api.github.com/repos/microsoft/finops-toolkit/releases'

    try {
        [array]$releases = Invoke-WebRequest -Uri $releaseUri | ConvertFrom-Json | Where-Object { ($Preview) -or (-not $_.prerelease) }

        if ($Latest) {
            $releases = $releases | Select-Object -First 1
            Write-Verbose -Message ($script:localizedData.FoundLatestRelease -f $releases.tag_name)
        }

        $output = @()
        foreach ($release in $releases) {
            $properties = [ordered]@{
                Name       = $release.name
                PreRelease = $release.prerelease
                Version    = $release.tag_name
                Url        = $release.url
                Assets     = @()
            }

            foreach ($asset in $release.assets) {
                $properties.Assets += @{
                    Name = $asset.name
                    Url  = $asset.browser_download_url
                }
            }

            $output += New-Object -TypeName 'PSObject' -Property $properties
        }

        return $output
    }
    catch {
        throw $_.Exception.Message
    }
    finally {
        $ProgressPreference = $progress
    }
}

<#
    .SYNOPSIS
        Deploys a FinOps hub instance.

    .PARAMETER Name
        Name of the FinOps hub instance.

    .PARAMETER ResourceGroup
        Name of the resource group to deploy to. Will be created if it doesn't exist.

    .PARAMETER Location
        Azure location to execute the deployment from.

    .PARAMETER Version
        Optional. Version of FinOps hub template to use. Defaults = "latest".

    .PARAMETER Preview
        Optional. Indicates that a pre-release version of FinOps hub can be used when -Version is "latest".

    .PARAMETER StorageSku
        Optional. Storage account SKU. Premium_LRS = Lowest cost, Premium_ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Default = "Premium_LRS".

    .PARAMETER Tags
        Optional. Tags for all resources.

    .EXAMPLE
        Deploy-FinOpsHub -Name MyHub -ResourceGroup MyExistingResourceGroup -Location westus

        Deploys a new FinOps hub instance named MyHub to an existing resource group named MyExistingResourceGroup.

    .EXAMPLE
        Deploy-FinOpsHub -Name MyHub -Location westus -Version 0.0.1

        Deploys a new FinOps hub instance named MyHub using version 0.0.1 of the template.
#>
function Deploy-FinOpsHub {
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroup,

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
        [hashtable]
        $Tags
    )

    try {
        $resourceGroupObject = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction 'SilentlyContinue'
        if (-not $resourceGroupObject) {
            if ($PSCmdlet.ShouldProcess($ResourceGroup, 'CreateResourceGroup')) {
                $resourceGroupObject = New-AzResourceGroup -Name $ResourceGroup -Location $Location
            }
        }

        $toolkitPath = Join-Path $env:temp -ChildPath 'FinOps'
        if ($PSCmdlet.ShouldProcess($toolkitPath, 'CreateDirectory')) {
            New-Directory -Path $toolkitPath
        }

        if ($PSCmdlet.ShouldProcess($Version, 'DownloadTemplate')) {
            Save-FinOpsHubTemplate -Version $Version -Preview:$Preview -Destination $toolkitPath
            $toolkitFile = Get-ChildItem -Path $toolkitPath -Include 'main.bicep' -Recurse | Where-Object -FilterScript { $_.FullName -like '*finops-hub-v*' }
            if (-not $toolkitFile) {
                throw ($LocalizedData.TemplateNotFound -f $toolkitPath)
            }

            $parameterSplat = @{
                TemplateFile            = $toolkitFile.FullName
                TemplateParameterObject = @{
                    hubName    = $Name
                    storageSku = $StorageSku
                }
            }

            if ($Tags -and $Tags.Keys.Count -gt 0) {
                $parameterSplat.TemplateParameterObject.Add('tags', $Tags)
            }
        }

        if ($PSCmdlet.ShouldProcess($ResourceGroup, 'DeployFinOpsHub')) {
            Write-Verbose -Message ($LocalizedData.DeployFinOpsHub -f $toolkitFile.FullName, $resourceGroupObject.ResourceGroupName)
            $deployment = New-AzResourceGroupDeployment @parameterSplat -ResourceGroupName $resourceGroupObject.ResourceGroupName

            return $deployment
        }
    }
    catch {
        throw $_.Exception.Message
    }
    finally {
        Remove-Item -Path $toolkitPath -Recurse -Force -ErrorAction 'SilentlyContinue'
    }
}

<#
.SYNOPSIS
Grants EA level permissions to the specified service principal or managed identity

.PARAMETER ObjectId
The object id of the service principal or managed identity.

.PARAMETER TenantId
The Azure Active Directory tenant which contains the identity.

.PARAMETER BillingScope
Specifies whether to grant permissions at an enrollment or department level.

.PARAMETER BillingAccountId
The billing Account ID (enrollment id) to grant permissions against.

.PARAMETER DepartmentId
The department id to grant permissions against.

.EXAMPLE
Add-FinOpsHubServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -BillingScope Enrollment -BillingAccountId 12345
Grants EA Reader permissions to the specified service principal or managed identity

Add-FinOpsHubServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -BillingScope Department -BillingAccountId 12345 -DepartmentId 67890
Grants department reader permissions to the specified service principal or managed identity

#>
function Add-FinOpsHubServicePrincipal {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Enrollment', 'Department')]
        [string]$BillingScope,
        [Parameter(Mandatory = $false)]
        [string]$BillingAccountId,
        [Parameter(Mandatory = $false)]
        [string]$DepartmentId
    )

    $azContext = get-azcontext
    switch ($BillingScope) {
        'Enrollment' {
            if ([string]::IsNullOrEmpty($BillingAccountId)) {
                Write-Output $LocalizedData.BillingAccountNotSpecifiedForDept
                Write-Output ''
                exit 1
            }

            $roleDefinitionId = "/providers/Microsoft.Billing/billingAccounts/{0}/billingRoleDefinitions/24f8edb6-1668-4659-b5e2-40bb5f3a7d7e" -f $BillingAccountId
            $restUri = "{0}providers/Microsoft.Billing/billingAccounts/{1}/billingRoleAssignments/{2}?api-version=2019-10-01-preview" -f $azContext.Environment.ResourceManagerUrl, $BillingAccountId, (New-Guid).Guid
            $body = '{"properties": { "PrincipalId": "{0}", "PrincipalTenantId": "{1}", "roleDefinitionId": "{2}" } }'
            $body = $body.Replace("{0}", $ObjectId)
            $body = $body.Replace("{1}", $TenantId)
            $body = $body.Replace("{2}", $roleDefinitionId)
        }
        'Department' {
            if ([string]::IsNullOrEmpty($BillingAccountId)) {
                Write-Output $LocalizedData.BillingAccountNotSpecifiedForDept
                Write-Output ''
                exit 1
            }
            if ([string]::IsNullOrEmpty($DepartmentId)) {
                Write-Output $LocalizedData.DeptIdNotSpecified
                Write-Output ''
                exit 1
            }

            $roleDefinitionId = "/providers/Microsoft.Billing/billingAccounts/{0}/departments/{1}/billingRoleDefinitions/db609904-a47f-4794-9be8-9bd86fbffd8a" -f $BillingAccountId, $DepartmentId
            $restUri = "{0}providers/Microsoft.Billing/billingAccounts/{1}/departments/{2}/billingRoleAssignments/{3}?api-version=2019-10-01-preview" -f $azContext.Environment.ResourceManagerUrl, $BillingAccountId, $DepartmentId, (New-Guid).Guid
            $body = '{"properties": { "PrincipalId": "{0}", "PrincipalTenantId": "{1}", "roleDefinitionId": "{2}" } }'
            $body = $body.Replace("{0}", $ObjectId)
            $body = $body.Replace("{1}", $TenantId)
            $body = $body.Replace("{2}", $roleDefinitionId)
        }
        default {
            throw ($LocalizedData.InvalidBillingScope -f $BillingScope)
        }
    }

    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
    $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + $token.AccessToken
    }

    try {
        Invoke-RestMethod -Uri $restUri -Method Put -Headers $authHeader -Body $body
        Write-Output ($LocalizedData.SuccessMessage1 -f $BillingScope)
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Output ($LocalizedData.AlreadyGrantedMessage1 -f $BillingScope)
        }
        else {
            $body
            throw $_.Exception
        }
    }
}

<#
.SYNOPSIS
Adds an export scope configuration to the specified Resource group.

.PARAMETER ResourceGroupName
The name of the Resource group.

.PARAMETER Scope
The Export Scope to add to the Resource group configuration.

.PARAMETER TenantId
The Azure AD Tenant linked to the export scope.

.PARAMETER Cloud
The Azure Cloud the export scope belongs to.

.EXAMPLE
Add-FinOpsHubScope -ResourceGroupName ftk-FinOps-Hub -Scope "/providers/Microsoft.Billing/billingAccounts/1234567"

Adds an export scope configuration to the specified Resource group.
#>
Function Add-FinOpsHubScope {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $ResourceGroupName,
        [Parameter()]
        [String]
        [ValidateNotNullOrEmpty()]
        $Scope
    )
    $ErrorActionPreference = 'Stop'
    [string]$operation = 'create'

    # Main
    Write-Output ''
    Write-Output ("{0}    Starting" -f (Get-Date))

    if (!$Scope.StartsWith('/')) {
        $Scope = '/' + $Scope
    }

    if ($Scope.EndsWith('/')) {
        $Scope = $Scope.Substring(0, $Scope.Length - 1)
    }

    Write-Output ("{0}    Export Scope to add: {1}" -f (Get-Date), $Scope)

    $tagSuffix = "Microsoft.Cloud/hubs/$ResourceGroupName"
    $hubResource = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts' -TagName 'cm-resource-parent' | Where-Object {$_.Tags['cm-resource-parent'].EndsWith($tagSuffix) }
    if ($null -eq $hubResource) {
        Write-Output ("{0}    Hub not found" -f (Get-Date))
        Throw ("Hub not found")
    }

    if ($hubResource.Count -gt 1) {
        Write-Output ("{0}    Multiple hubs found" -f (Get-Date))
        Throw ("Multiple hubs found")
    }

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $hubResource.ResourceGroupName -Name $hubResource.Name -ErrorAction SilentlyContinue
    if ($null -eq $storageAccount) {
        Write-Output ("{0}    Storage account not found" -f (Get-Date))
        Throw ("Storage account not found")
    }

    $storageContext = $StorageAccount.Context
    Get-AzStorageBlob -Container 'config' -Blob 'settings.json' -Context $storageContext | Get-AzStorageBlobContent -Force | Out-Null
    $settings = Get-Content 'settings.json' | ConvertFrom-Json

    # To deal with the case where there's nothing but a blank export scope in the settings.json file
    if (($settings.exportScopes.Count -eq 1) -and ([string]::IsNullOrEmpty($settings.exportScopes[0]))) {
        $settings.exportScopes = @()
        $operation = 'create'
        Write-Output ("{0}    No export scopes defined" -f (Get-Date), $Scope)
    }

    foreach ($exportScope in $settings.exportScopes) {
        if ($exportScope.scope -eq $Scope) {
            Write-Output ("{0}    Export scope {1} already exists" -f (Get-Date), $Scope)
            $operation = 'none'
        }
    }

    if ($operation -eq 'create') {
        Write-Output ("{0}    Adding export scope {1} with tenant ID {2}" -f (Get-Date), $Scope, $TenantId)
        [PSCustomObject]$ScopeToAdd = @{scope = $Scope}
        $settings.exportScopes += $ScopeToAdd
        Write-Output ("{0}    Saving settings.json" -f (Get-Date))
        $settings | ConvertTo-Json -Depth 100 | Set-Content 'settings.json' -Force | Out-Null
        Set-AzStorageBlobContent -Container 'config' -File 'settings.json' -Context $storageContext -Force | Out-Null
    }

    Write-Output ("{0}    Finished" -f (Get-Date))
    Write-Output ''
}

#endregion Public functions

Export-ModuleMember -Function 'Get-FinOpsToolkitVersions', 'Deploy-FinOpsHub', 'Add-FinOpsHubServicePrincipal', 'Add-FinOpsHubScope'
