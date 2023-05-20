<#
.SYNOPSIS
Grants EA Reader permissions to the specified Service Principal or Managed Identity

.PARAMETER PrincipalId
The Object ID of the Service Principal or Managed Identoty.

.PARAMETER PrincipalTenantId
The Azure Active Directory Tenant which contains the identity.

.PARAMETER BillingAccountId
The Billing Account ID (Enrollment ID) to grant permissions against.

.EXAMPLE
Add-EAReader -principalId 00000000-0000-0000-0000-000000000000 -principalTenantId 00000000-0000-0000-0000-000000000000 -billingAccountId 1234567

Grants EA Reader permissions to the specified Service Principal or Managed Identity
#>
function Add-EAReader {
  param(
    [Parameter(Mandatory=$true)]
    [string]$PrincipalId,
    [Parameter(Mandatory=$true)]
    [string]$PrincipalTenantId,
    [Parameter(Mandatory=$true)]
    [string]$BillingAccountId
  )

  $azContext = get-azcontext
  $restUri = "{0}providers/Microsoft.Billing/billingAccounts/{1}/billingRoleAssignments/{2}?api-version=2019-10-01-preview" -f $azContext.Environment.ResourceManagerUrl, $BillingAccountId, (New-Guid).Guid
  $body = '{"properties": { "PrincipalId": "{0}", "PrincipalTenantId": "{1}", "roleDefinitionId": "/providers/Microsoft.Billing/billingAccounts/{2}/billingRoleDefinitions/24f8edb6-1668-4659-b5e2-40bb5f3a7d7e" } }'
  $body = $body.Replace("{0}", $PrincipalId)
  $body = $body.Replace("{1}", $PrincipalTenantId)
  $body = $body.Replace("{2}", $BillingAccountId)

  $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
  $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
  $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
  $authHeader = @{
    'Content-Type'='application/json'
    'Authorization'='Bearer ' + $token.AccessToken
  }

  $body
  try {
    Invoke-RestMethod -Uri $restUri -Method Put -Headers $authHeader -Body $body
  }
  catch {
    Write-Host $_.Exception.Message
  }
  
}

Export-ModuleMember -Function 'Add-EAReader'