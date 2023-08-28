# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Delete a Cost Management export and optionally data associated with the export.

    .PARAMETER Name
    Name of the Cost Management export.

    .PARAMETER Scope
    Required. Resource ID of the scope to export data for.

    .PARAMETER RemoveData
    Optional. Indicates that all cost data associated with the Export scope should be deleted.

    .PARAMETER APIVersion
    Optional. API version to use when calling the Cost Management Exports API. Default = 2023-03-01.

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
    $ApiVersion = '2023-03-01'
  )

  $context = Get-AzContext
  if (-not $context)
  {
      throw $script:localizedData.ContextNotFound
  }

  try
  {
    $additionalParamaters = @{
      scope = $scope
    }
    $payload = ConvertTo-Json -InputObject $additionalParamaters -Depth 100

    $invokeAzRestMethodParams = @{
      ResourceProviderName = "Microsoft.CostManagement"
      ResourceType = "exports"
      Name = $Name
      ApiVersion = $ApiVersion
      Method = "GET"
      Payload = $payload
    }

    # TODO : Validate parameters and resources before proceeding
    $httpResponse = Invoke-AzRestMethod @invokeAzRestMethodParams

    if ($httpResponse.StatusCode -eq 404) { break }
    elseif ($httpResponse.StatusCode -ne 200)
    {
      throw ($script:localizedData.GetCostExportNotFound -f $($httpResponse.Content))
    }

    if ($PSCmdlet.ShouldProcess($Name, 'DeleteCostExport'))
    {
      # Using the REST API to delete the export as requested as PS modules are outdated?
      $httpResponse = Invoke-AzRestMethod @invokeAzRestMethodParams -Method "DELETE"

      if ($httpResponse.StatusCode -eq 404) { break }
      elseif ($httpResponse.StatusCode -ne 200)
      {
        # Error response describing why the operation failed.
        throw ($script:localizedData.DeleteCostExportFailed -f $($httpResponse.Content))
      }
    }

    # Delete associated ingestion data from storage account
    if ($RemoveData)
    {
      # Using the REST API to get the export as requested as PS modules are outdated?
      $httpResponse = Invoke-AzRestMethod @invokeAzRestMethodParams

      if ($httpResponse.StatusCode -eq 200)
      {
        # Export details retreived
        $exportDetails = ConvertFrom-Json -InputObject $httpResponse.Content
        $storageAccountId = $exportDetails.properties.deliveryInfo.destination.resourceId

        # Get-AzStorageAccount -resourcegroupname alz-finopstk -name finopshub255k7ov6asado | Get-AzDataLakeGen2ChildItem -FileSystem "ingestion" -Path "/" -Recurse -FetchProperty | Where-Object IsDirectory -ne false | Select-Object Path
        $resourceGroupName = $storageAccountID.Split('/')[4]
        $storageAccountName = $storageAccountID.Split('/')[8]

        # Hold on to your hats, deleting all the files in the ingestion scope. Using Az PS module as this should be current.
        if ($PSCmdlet.ShouldProcess($scope, 'DeleteCostReports'))
        {
          Write-Verbose "Resource group: $resourceGroupName"
          Write-Verbose "Storage account: $storageAccountName"
          Write-Verbose "Scope: $scope"

          $getFiles = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName | Get-AzDataLakeGen2ChildItem -FileSystem "ingestion" -Path $scope -Recurse -FetchProperty # TODO: verify folder/files to delete (ingestion or msexports)
          if ($getFiles.Count -gt 0)
          {
            $getFiles | Remove-AzDataLakeGen2Item -Force
          }
        }
      }
      # elseif ($httpResponse.StatusCode -eq 404)
      # {
      #   # Not found - Nothing to delete
      # }
      else
      {
        # Error response describing why the operation failed.
        throw ($script:localizedData.DeleteCostExportFilesFailed -f $($httpResponse.Content))
      }
    }
  }
  catch
  {
    throw $_.Exception
  }
}
