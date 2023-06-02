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
Add-EAReader -principalId 00000000-0000-0000-0000-000000000000 -principalTenantId 00000000-0000-0000-0000-000000000000 -billingAccountId 1234567

Add-FinOpsServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -BillingScope Enrollment -BillingAccountId 12345
Grants EA Reader permissions to the specified service principal or managed identity

Add-FinOpsServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -BillingScope Department -BillingAccountId 12345 -DepartmentId 67890
Grants department reader permissions to the specified service principal or managed identity

#>

# private functions
function Get-RoleDefinition{
  param(
    [Parameter(Mandatory=$true)]
    [string]$roleDefinitionId
  )

  if ($roleDefinitionId.endsWith("24f8edb6-1668-4659-b5e2-40bb5f3a7d7e")) {
    return "Enrollment Reader"
  }

  if ($roleDefinitionId.endsWith("9f1983cb-2574-400c-87e9-34cf8e2280db")) {
    return "Enrollment Admin"
  }

  if ($roleDefinitionId.endsWith("da6647fb-7651-49ee-be91-c43c4877f0c4")) {
    return "Enrollment Purchaser"
  }

  if ($roleDefinitionId.endsWith("db609904-a47f-4794-9be8-9bd86fbffd8a")) {
    return "Department Reader"
  }
  
  return 'Undefined'
}

# public functions
function Get-FinOpsServicePrincipal {
    param(
      [Parameter(Mandatory=$true)]
      [ValidateSet('Enrollment', 'Department')]
      [string]$BillingScope,
      [Parameter(Mandatory=$false)]
      [string]$BillingAccountId,
      [Parameter(Mandatory=$false)]
      [string]$DepartmentId
    )

    $azContext = get-azcontext
    switch ($BillingScope) {
      'Enrollment' {
        if([string]::IsNullOrEmpty($BillingAccountId)){
            Write-Output "Billing account ID is required when billing scope = Department"
            Write-Output ''
            exit 1
        }

        $restUri = "{0}providers/Microsoft.Billing/billingAccounts/{1}/billingRoleAssignments?api-version=2019-10-01-preview" -f $azContext.Environment.ResourceManagerUrl, $BillingAccountId

      }
      'Department' {
        if([string]::IsNullOrEmpty($BillingAccountId)){
          Write-Output "Billing account ID is required when billing scope = Department"
            Write-Output ''
            exit 1
        }
        if([string]::IsNullOrEmpty($DepartmentId)){
          Write-Output "Department ID is required when billing scope = Department"
            Write-Output ''
            exit 1
        }

        $restUri = "{0}providers/Microsoft.Billing/billingAccounts/{1}/departments/{2}/billingRoleAssignments?api-version=2019-10-01-preview" -f $azContext.Environment.ResourceManagerUrl, $BillingAccountId, $DepartmentId

      }
      default {
        throw "Invalid BillingScope: $BillingScope"
      }
    }
    
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
    $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
    $authHeader = @{
      'Content-Type'='application/json'
      'Authorization'='Bearer ' + $token.AccessToken
    }
  
    try {
      $results = Invoke-RestMethod -Uri $restUri -Method get -Headers $authHeader
      $roleAssignments = @()
      $results.value | foreach  {
        $roleAssignment = $_.properties
        $roleAssignment | add-member -MemberType NoteProperty -Name 'roleDefinition' -Value (Get-RoleDefinition -roleDefinitionId $roleAssignment.roleDefinitionId)
        $principalName = $roleAssignment.userEmailAddress
        if ($null -ne $roleAssignment.principalId) {
          $principal = Get-AzADServicePrincipal -Id $roleAssignment.principalId -erroraction silentlycontinue
          if ($null -ne $principal) {
            $principalType = $principal.ServicePrincipalType
            $principalName = $principal.DisplayName
          }
          else
          {
            $principalType = 'missing or deleted'
            $principalName = '------------------'
          }
        }
        elseif ($null -ne $roleAssignment.userEmailAddress) {
          $principalType = 'User'
          $principalName = $roleAssignment.userEmailAddress
        }
        else {
          $principalType = 'undefined'
          $principalName = 'undefined'
        }
        $roleAssignment | add-member -MemberType NoteProperty -Name 'principalName' -Value $principalName
        $roleAssignment | add-member -MemberType NoteProperty -Name 'principalType' -Value $principalType
        $roleAssignment | add-member -MemberType NoteProperty -Name 'name' -Value $_.name
        $roleAssignment | add-member -MemberType NoteProperty -Name 'id' -Value $_.id
        $roleAssignments += $roleAssignment
      }

      return $roleAssignments
    }
    catch {
      throw $_.Exception
    }
  }

  Export-ModuleMember -Function 'Get-FinOpsServicePrincipal'