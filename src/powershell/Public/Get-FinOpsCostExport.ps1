# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
        Get list of Cost Management Exports.

    .PARAMETER Name
        Name of the Cost Management Export.

    .PARAMETER Scope
        The scope associated with export operations. 
        This includes '/subscriptions/{subscriptionId}/' for subscription scope, 
        '/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}' for resourceGroup scope, 
        '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}' for Billing Account scope and 
        '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/departments/{departmentId}' for Department scope, 
        '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/enrollmentAccounts/{enrollmentAccountId}' for EnrollmentAccount scope, 
        '/providers/Microsoft.Management/managementGroups/{managementGroupId} for Management Group scope,
        '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}' for billingProfile scope, 
        '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}/invoiceSections/{invoiceSectionId}' for invoiceSection scope, and 
        '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/customers/{customerId}' specific for partners.

    .PARAMETER DataSet
        Optional. Dataset to get exports for. Allowed values = "ActualCost", "AmortizedCost", "Usage". Default = null (all exports).

    .PARAMETER StorageAccountId
        Optional. Resource ID of the storage account to get exports for. Default = null (all exports).

    .PARAMETER StorageContainer
        Optional. Name of the container to get exports for. Default = null (all exports).

    .PARAMETER ApiVersion
        Optional. API version to use when calling the Cost Management Exports API. Default = 2023-03-01.

    .EXAMPLE

        Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"
        Get-FinOpsCostExport -Name MyExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"
        Get-FinOpsCostExport -Name MyExport* -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"
        Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -DataSet "AmortizedCost"
        Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageAccountId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MyResourceGroup/providers/Microsoft.Storage/storageAccounts/MyStorageAccount"
        Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageContainer "MyContainer"
        Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageContainer "mtd*" -apiVersion "2023-08-01"
        
#>
function Get-FinOpsCostExport
{
    param
    (
        [Parameter()]
        [SupportsWildcards()][string]
        $Name = $null,

        [Parameter(Mandatory = $true)]
        [string]
        $Scope,

        [Parameter()]
        [ValidateSet("ActualCost", "AmortizedCost", "Usage")]
        [string]
        $DataSet = $null,

        [Parameter()]
        [string]
        $StorageAccountId = $null,

        [Parameter()]
        [SupportsWildcards()][string]
        $StorageContainer = $null,

        [Parameter()]
        [string]
        $APIVersion = '2023-08-01'
    )

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:localizedData.ContextNotFound
    }
 
    # Get operation does not allow wildcards. Fetching all exports using list operation and then filtering in script
    # https://learn.microsoft.com/en-us/rest/api/cost-management/exports/list?tabs=HTTP


    $uri = "https://management.azure.com/$scope/providers/Microsoft.CostManagement/exports?api-version=$APIVersion"
  
    Write-Verbose "connecting to $uri and fetching all exports for scope: $scope"
    $httpResponse = Invoke-AzRestMethod -Uri $uri

    Write-Verbose "response received with status code $($httpResponse.StatusCode)"

    if ($httpResponse.StatusCode -eq 200)
    {
      
        $content = $(ConvertFrom-Json -InputObject $httpResponse.Content -Depth 20).Value
        Write-Verbose "found $($content.count) export items for the scope $scope"

        # Name parameter received
        if (-not [System.String]::IsNullOrEmpty($Name))
        {
            $content = $content | Where-Object { $_.name -like $Name }
            Write-Verbose "$($content.count) items left after filtering for Name $Name"
        }
        if (-not [System.String]::IsNullOrEmpty($DataSet)) 
        {
            $content = $content | Where-Object { $_.properties.definition.type -like $DataSet }
            Write-Verbose "$($content.count) items left after filtering for DataSet $DataSet"
        }
        if (-not [System.String]::IsNullOrEmpty($StorageAccountId))
        {    
            $content = $content | Where-Object { $_.properties.deliveryInfo.destination.resourceId.tostring() -eq $StorageAccountId }
            Write-Verbose "found $($content.count) items after filtering for storageaccountid $StorageAccountId"
        }
        if (-not [System.String]::IsNullOrEmpty($StorageContainer))
        {    
            $content = $content | Where-Object { $_.properties.deliveryInfo.destination.container.tostring() -like $StorageContainer }
            Write-Verbose "found $($content.count) items after filtering for StorageContainer $StorageContainer"
        }
        $exportdetails = @()
        $content | ForEach-Object {
 
            $item = [PSCustomObject]@{

                Id                   = $_.id
                Name                 = $_.name
                Type                 = $_.type
                eTag                 = $_.eTag
                ScheduledStatus      = $_.properties.schedule.status
                ScheduleRecurrence   = $_.properties.schedule.recurrence
                RecurrencePeriodFrom = $_.properties.schedule.recurrencePeriod.from
                RecurrencePeriodTo   = $_.properties.schedule.recurrencePeriod.to
                NextRuntimeEstimate  = $_.properties.nextRunTimeEstimate
                Format               = $_.properties.format
                StorageAccountId     = $_.properties.deliveryInfo.destination.resourceId
                StorageContainer     = $_.properties.deliveryInfo.destination.container
                RootFolderPath       = $_.properties.deliveryInfo.destination.rootfolderpath
                DefinitionType       = $_.properties.definition.type
                DefinitionTimeFrame  = $_.properties.definition.timeframe
                DatasetGranularity   = $_.properties.definition.dataset.granularity        
            }
            $exportdetails += $item
            return $exportdetails
        }    
    }
    else
    {
        Write-Error "Failed to fetch export data: '$($httpResponse.Content)'"
    }
}