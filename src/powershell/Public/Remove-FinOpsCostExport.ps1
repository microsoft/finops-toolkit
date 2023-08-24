
function Remove-FinOpsCostExport {
  [CmdletBinding(SupportsShouldProcess)]
  param
  (
    [Parameter(Mandatory = $true)]
    [string]
    $Name,

    [Parameter(Mandatory = $true)]
    [string]
    $Scope,

    [Parameter]
    [switch]
    $RemoveData,

    [Parameter()]
    [string]
    $ApiVersion = '2023-04-01-preview'
  )

  try {

    # TODO : Validate parameters

    $additionalParamaters = @{
      scope = $scope
    }
    $payload = ConvertTo-Json -InputObject $additionalParamaters -Depth 100

    if ($PSCmdlet.ShouldProcess($Name, 'DeleteCostExport')) {

      # Using the REST API to delete the export as requested as PS modules are outdated?
      $httpResponse = Invoke-AzRestMethod `
        -ResourceProviderName "Microsoft.CostManagement" `
        -ResourceType "exports" `
        -Name $Name `
        -ApiVersion $ApiVersion `
        -Method "DELETE" `
        -Payload $payload

      if ($httpResponse.StatusCode -eq 200) {
        # Export deleted successfully
      } else {
        # Error response describing why the operation failed.
        throw "Operation failed with message: '$($httpResponse.Content)'"
      }

    }

    if ($RemoveData) {
      # Delete associated ingestion data from storage account
      # Using the REST API to delete the export as requested as PS modules are outdated?
      $httpResponse = Invoke-AzRestMethod `
        -ResourceProviderName "Microsoft.CostManagement" `
        -ResourceType "exports" `
        -Name $Name `
        -ApiVersion $ApiVersion `
        -Method "GET" `
        -Payload $payload

      if ($httpResponse.StatusCode -eq 200) {

        # Export details retreived
        $exportDetails = ConvertFrom-Json -InputObject $httpResponse.Content
        $storageAccountID = $exportDetails.properties.deliveryInfo.destination.resourceId
        # $container = "ingestion"
        # $rootFolder = $scope
        # $type = $exportDetails.properties.definition.type

        # Get-AzStorageAccount -resourcegroupname alz-finopstk -name finopshub255k7ov6asado | Get-AzDataLakeGen2ChildItem -FileSystem "ingestion" -Path "/" -Recurse -FetchProperty | Where-Object IsDirectory -ne false | Select-Object Path
        $resourceGroupName = $storageAccountID.Split('/')[4]
        $storageAccountName = $storageAccountID.Split('/')[8]

        #Hold on to your hats, deleting all the files in the ingestion scope
        Get-AzStorageAccount -resourcegroupname $resourceGroupName -name $storageAccountName | Get-AzDataLakeGen2ChildItem -FileSystem "ingestion" -Path $scope -Recurse -FetchProperty | Remove-AzDataLakeGen2Item -Force

      } else {
        # Error response describing why the operation failed.
        throw "Operation failed with message: '$($httpResponse.Content)'"
      }
    }

  } catch {
    throw $_.Exception.Message
  } finally {
    # Nothing to do here
  }
}
