<#
.SYNOPSIS
Grants permissions neccesary to save cost management exports to the specified storage account

.PARAMETER ObjectId
The Object ID of the Service Principal or Managed Identoty.

.PARAMETER storageAccountId
The resource id of the storage account to grant permissions against.

.PARAMETER BillingAccountId

.EXAMPLE
Add-ExportContainerPermissions -ObjectId '00000000-0000-0000-0000-000000000000' -storageAccountId (Get-AzStorageAccount -ResourceGroupName $ResourceGroup).Id

Grants EA Reader permissions to the specified Service Principal or Managed Identity
#>
function Add-ExportContainerPermissions {
  param(
    [Parameter(Mandatory=$true)]
    [string]$ObjectId,
    [Parameter(Mandatory=$true)]
    [string]$storageAccountId
  )

  try {
    New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName 'Reader' -Scope $storageAccountId | Out-Null
  }
  catch {
    Write-Output $_.Exception.Message
  }

  try {
    New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName 'Storage Account Contributor' -Scope $storageAccountId | Out-Null
  }
  catch {
    Write-Output $_.Exception.Message
  }
  
  
}

Export-ModuleMember -Function 'Add-ExportContainerPermissions'