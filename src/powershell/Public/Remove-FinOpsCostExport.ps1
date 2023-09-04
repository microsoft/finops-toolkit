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

    Deletes a Cost Management export named MyExport scoped to /subscriptions/00000000-0000-0000-0000-000000000000, and deletes all exported data from the related storage account.
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
    $path = "/{0}/providers/Microsoft.CostManagement/exports/{1}?api-version={2}" -f $Scope, $Name, $ApiVersion

    # Switch to use the Get-FinOpsCostExport function once it is available
    $httpResponse = Invoke-AzRestMethod -Path $path -Method "GET"

    if ($httpResponse.StatusCode -eq 404) {
      Write-Verbose -Message "Cost Management export not found."
      break
    }
    elseif ($httpResponse.StatusCode -ne 200)
    {
      $errorResponse = ConvertFrom-Json -InputObject $httpResponse.Content
      throw ($script:localizedData.GetCostExportNotFound -f $($errorResponse.error.message), $($errorResponse.error.code))
    }
    else
    {
      # Delete associated data from storage account
      if ($RemoveData)
      {
        # Export details retreived
        $exportDetails = ConvertFrom-Json -InputObject $httpResponse.Content
        $storageAccountId = $exportDetails.properties.deliveryInfo.destination.resourceId
        $resourceGroupName = $storageAccountID.Split('/')[4]
        $storageAccountName = $storageAccountID.Split('/')[8]
        $path = $exportDetails.properties.deliveryInfo.destination.rootFolderPath + "/" + $Name

        if ($PSCmdlet.ShouldProcess($path, 'DeleteCostReports'))
        {
          Write-Verbose "Resource group: $resourceGroupName"
          Write-Verbose "Storage account: $storageAccountName"
          Write-Verbose "Scope: $scope"

          $getSta = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
          if ($getSta -and $getSta.EnableHierarchicalNamespace)
          {
            $getSta | Remove-AzDataLakeGen2Item -FileSystem $exportDetails.properties.deliveryInfo.destination.container -Path $path -Force
          }
        }
      }
    }

    if ($PSCmdlet.ShouldProcess($Name, 'DeleteCostExport'))
    {
      $httpResponse = Invoke-AzRestMethod -Path $path -Method "DELETE"

      if ($httpResponse.StatusCode -eq 404) {
        Write-Verbose -Message "Cost Management export folder not found in storage account."
        break
      }
      elseif ($httpResponse.StatusCode -ne 200)
      {
        $errorResponse = ConvertFrom-Json -InputObject $httpResponse.Content
        throw ($script:localizedData.DeleteCostExportFailed -f $($errorResponse.Content), $($errorResponse.StatusCode))
      }
    }
  }
  catch
  {
    throw $_.Exception
  }
}
