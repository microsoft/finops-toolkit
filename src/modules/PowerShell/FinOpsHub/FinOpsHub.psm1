data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
    DeployResourceGroupScope = Deploying hub from template '{0}' to resource group '{1}'.
    DeploySubscriptionScope = Deploying hub from template '{0}' to subscription '{1}'.
    DeployTenantScope = Deploying hub from template '{0}' to tenant '{1}'.
    NotLoggedIn = Not logged into Azure. Launching 'Login-AzAccount'.
    LoggedIn = Currently logged into subscription '{0}' '{1}'.
'@
}

<#
    .SYNOPSIS
        Gets Azure context for logged in user. Will prompt for login if not currently logged in.
#>
function Assert-AzContext
{
    [CmdletBinding()]
    param()
    $context = Get-AzContext
    if ($null -eq $context)
    {
        Write-Warning -Message ($LocalizedData.NotLoggedIn)
        $null = Login-AzAccount
        $context = Get-AzContext
    }

    Write-Verbose -Message ($LocalizedData.LoggedIn -f $context.Subscription.Name, $context.Subscription.Id)
    return $context
}

<#
    .SYNOPSIS
        Deploys a FinOpsHub instance.

    .PARAMETER Path
        Path to the .bicep template.

    .PARAMETER HubName
        Name of the FinOpsHub instance.

    .PARAMETER Scope
        Scope to deploy FinOpsHub to, either ResourceGroup, Subscription, or Tenant.

    .PARAMETER ResourceGroupName
        Name of the resource group to deploy to. Will be created if it doesn't exist. Only used for ResourceGroup scope.

    .PARAMETER Location
        Azure location to execute the deployment from.

    .PARAMETER StorageSku
        Optional. Storage account SKU. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage.

    .PARAMETER Tags
        Optional. Tags for all resources.

    .PARAMETER ExportScopes
        Optional. List of scope IDs to create exports for.

    .EXAMPLE
        Deploy-FinOpsHub -Path c:\finopshub\main.bicep -HubName MyHub -ResourceGroupName MyExistingResourceGroup -Location westus -Scope ResourceGroup
        
        Deploys a new FinOps hub instance named MyHub to an existing resource group name MyExistingResourceGroup.
    
    .EXAMPLE
        Deploy-FinOpsHub -Path c:\finopshub\main.bicep -HubName MyHub -Location westus -Scope Subscription
        
        Deploys a new FinOps hub instance named MyHub to your currently logged into Azure subscription.

    .EXAMPLE
        Deploy-FinOpsHub -Path c:\finopshub\main.bicep -HubName MyHub -Location westus -Scope Tenant
        
        Deploys a new FinOps hub instance named MyHub to your currently logged into Azure tenant.
#>
function Deploy-FinOpsHub
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path -Path $_})]
        [ValidateScript({{[System.IO.Path]::GetExtension($_) -eq '.bicep'}})]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [string]
        $HubName,

        [Parameter(Mandatory = $true)]
        [string]
        $Location,

        [Parameter()]
        [ValidateSet('ResourceGroup', 'Subscription', 'Tenant')]
        [string]
        $Scope = 'ResourceGroup',

        [Parameter()]
        [ValidateSet('Premium_LRS', 'Premium_ZRS')]
        [string]
        $StorageSku,

        [Parameter()]
        [hashtable]
        $Tags,

        [Parameter()]
        [array]
        $ExportScopes
    )

    DynamicParam
    {
        if ($Scope -eq 'ResourceGroup')
        {
            $attribute = New-Object System.Management.Automation.ParameterAttribute
            $attribute.Mandatory = $true
            $attribute.HelpMessage = 'Resource group name'
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($attribute)
            $param = New-Object System.Management.Automation.RuntimeDefinedParameter('ResourceGroupName', [string], $attributeCollection)

            $dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $dictionary.Add('ResourceGroupName', $param)
            return $dictionary
        }
    }

    begin
    {
        if ($PSBoundParameters.ContainsKey('ResourceGroupName'))
        {
            $ResourceGroupName = $PSBoundParameters['ResourceGroupName']
        }

        $subscription = Assert-AzContext

        $parameterSplat = @{
            TemplateFile            = $Path
            TemplateParameterObject = @{
                HubName = $HubName
            }
        }

        foreach ($parameter in @('StorageSku', 'Tags', 'ExportScopes'))
        {
            if ($PSBoundParameters.ContainsKey($parameter))
            {
                $parameterSplat.TemplateParameterObject.Add($parameter, $PSBoundParameters[$parameter])
            }
        }
    }
    process
    {
        switch ($Scope)
        {
            'ResourceGroup'
            {
                try
                {
                    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction 'Stop'
                }
                catch
                {
                    $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
                }
                
                Write-Verbose -Message ($LocalizedData.DeployResourceGroupScope -f $Path, $resourceGroup.ResourceGroupName)
                $deployment = New-AzResourceGroupDeployment @parameterSplat -ResourceGroupName $resourceGroup.ResourceGroupName
            }

            'Subscription'
            {
                Write-Verbose -Message ($LocalizedData.DeploySubscriptionScope -f $Path, $subscription.Name)
                $deployment = New-AzSubscriptionDeployment @parameterSplat -Location $Location
            }

            'Tenant'
            {
                Write-Verbose -Message ($LocalizedData.DeployTenantScope -f $Path, $subscription.Tenant.Id)
                $deployment = New-AzTenantDeployment @parameterSplat -Location $Location
            }
        }
    }
    end
    {
        return $deployment
    }
}

Export-ModuleMember -Function 'Deploy-FinOpsHub'
