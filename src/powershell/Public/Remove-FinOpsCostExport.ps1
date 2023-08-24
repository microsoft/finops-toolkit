# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
        Delete a Cost Management Export and optionally data associated with the export.

    .PARAMETER Name
        Name of the Cost Management Export.

    .PARAMETER Scope
        The scope associated with export operations. This includes '/subscriptions/{subscriptionId}/' for subscription scope,
        '/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}' for resourceGroup scope,
        '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}' for Billing Account scope and '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/departments/{departmentId}' for Department scope,
        '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/enrollmentAccounts/{enrollmentAccountId}' for EnrollmentAccount scope,
        '/providers/Microsoft.Management/managementGroups/{managementGroupId} for Management Group scope, '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}' for billingProfile scope,
        '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}/invoiceSections/{invoiceSectionId}' for invoiceSection scope,
        and '/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/customers/{customerId}' specific for partners.

    .PARAMETER RemoveData
        Optional. Indicates that all cost data associated with the Export scope should be deleted.
        This will delete all data in the storage account associated with the export scope (billing, subscription, management group, resource group).

    .PARAMETER APIVersion
        Optional. Specify an alternative API version. Default is 2023-04-01-preview.

    .EXAMPLE
        Remove-FinOpsCostExport -Name MyExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -RemoveData

        Deletes a Cost Management Export named MyExport scoped to /subscriptions/00000000-0000-0000-0000-000000000000, and deletes all data associated with that scope.
#>

function Remove-FinOpsCostExport
{
  [CmdletBinding(SupportsShouldProcess)]
  param
  (
    [Parameter(Mandatory = $true)]
    [string]
    $Name,

    [Parameter(Mandatory = $true)]
    [string]
    $Scope,

    [Parameter()]
    [switch]
    $RemoveData,

    [Parameter()]
    [string]
    $APIVersion = '2023-04-01-preview'
  )

  try
  {
    $additionalParamaters = @{
      scope = $scope
    }
    $payload = ConvertTo-Json -InputObject $additionalParamaters -Depth 100

    # TODO : Validate parameters and resources before proceeding
    $httpResponse = Invoke-AzRestMethod `
      -ResourceProviderName "Microsoft.CostManagement" `
      -ResourceType "exports" `
      -Name $Name `
      -ApiVersion $ApiVersion `
      -Method "GET" `
      -Payload $payload

    if ($httpResponse.StatusCode -eq 200)
    {
      # Export deleted successfully
    }
    elseif ($httpResponse.StatusCode -eq 404)
    {
      # Not found
    }
    else
    {
      # Error response describing why the operation failed.
      throw "Not Exists: Cost Management Export operation failed with message: '$($httpResponse.Content)'"
    }

    if ($PSCmdlet.ShouldProcess($Name, 'DeleteCostExport'))
    {

      # Using the REST API to delete the export as requested as PS modules are outdated?
      $httpResponse = Invoke-AzRestMethod `
        -ResourceProviderName "Microsoft.CostManagement" `
        -ResourceType "exports" `
        -Name $Name `
        -ApiVersion $ApiVersion `
        -Method "DELETE" `
        -Payload $payload

      if ($httpResponse.StatusCode -eq 200)
      {
        # Export deleted successfully
      }
      elseif ($httpResponse.StatusCode -eq 404)
      {
        # Not found
      }
      else
      {
        # Error response describing why the operation failed.
        throw "Delete Cost Management Export operation failed with message: '$($httpResponse.Content)'"
      }
    }

    # Delete associated ingestion data from storage account
    if ($RemoveData)
    {
      # Using the REST API to get the export as requested as PS modules are outdated?
      $httpResponse = Invoke-AzRestMethod `
        -ResourceProviderName "Microsoft.CostManagement" `
        -ResourceType "exports" `
        -Name $Name `
        -ApiVersion $ApiVersion `
        -Method "GET" `
        -Payload $payload

      if ($httpResponse.StatusCode -eq 200)
      {

        # Export details retreived
        $exportDetails = ConvertFrom-Json -InputObject $httpResponse.Content
        $storageAccountID = $exportDetails.properties.deliveryInfo.destination.resourceId

        # Get-AzStorageAccount -resourcegroupname alz-finopstk -name finopshub255k7ov6asado | Get-AzDataLakeGen2ChildItem -FileSystem "ingestion" -Path "/" -Recurse -FetchProperty | Where-Object IsDirectory -ne false | Select-Object Path
        $resourceGroupName = $storageAccountID.Split('/')[4]
        $storageAccountName = $storageAccountID.Split('/')[8]

        #Hold on to your hats, deleting all the files in the ingestion scope. Using Az PS module as this should be current.
        if ($PSCmdlet.ShouldProcess($scope, 'DeleteCostReports'))
        {
          Write-Verbose "Resourace Group: $resourceGroupName"
          Write-Verbose "Storage Account: $storageAccountName"
          Write-Verbose "Scope: $scope"

          $getFiles = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName | Get-AzDataLakeGen2ChildItem -FileSystem "ingestion" -Path $scope -Recurse -FetchProperty
          if ($getFiles.Count -gt 0)
          {
            $getFiles | Remove-AzDataLakeGen2Item -Force
          }
        }
      }
      elseif ($httpResponse.StatusCode -eq 404)
      {
        # Not found
      }
      else
      {
        # Error response describing why the operation failed.
        throw "Delete ingestion data operation failed with message: '$($httpResponse.Content)'"
      }
    }

  }
  catch
  {
    throw $_.Exception.Message
  }
  finally
  {
    # Nothing to do here
  }
}
