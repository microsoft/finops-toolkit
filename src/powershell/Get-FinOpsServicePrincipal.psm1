<#
.SYNOPSIS
Returns details about current role assignments for the specified enrollment/department

.PARAMETER BillingScope
Specifies whether to grant permissions at an enrollment or department level.

.PARAMETER BillingAccountId
The billing Account ID (enrollment id) to grant permissions against.

.PARAMETER DepartmentId
The department id to grant permissions against.

.EXAMPLE

Get-FinOpsServicePrincipal -BillingScope Enrollment -BillingAccountId $BillingAccountId | ft createdOn, createdByUserEmailAddress, roleDefinition, principalName, principalType, scopentId
Returns all role assignments at for the enrollment scope

Get-FinOpsServicePrincipal -BillingScope Department -BillingAccountId $BillingAccountId -DepartmentId $DepartmentId | ft createdOn, createdByUserEmailAddress, roleDefinition, principalName, principalType, scopentId
Returns all role assignments at for the department scope

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
        
        $principalName = $roleAssignment.userEmailAddress
        if ($null -ne $roleAssignment.principalId) {
          $principal = Get-AzADServicePrincipal -Id $roleAssignment.principalId -erroraction silentlycontinue
          if ($null -ne $principal) {
            $principalType = $principal.ServicePrincipalType
            $principalName = $principal.DisplayName
          }
          else
          {
            $principal = Get-AzADUser -ObjectId $roleAssignment.principalId -erroraction silentlycontinue
            if ($null -ne $principal) {
              $principalType = $roleAssignment.userAuthenticationType
              $principalName = $principal.UserPrincipalName
            }
            else
            { 
              $principalType = 'NOT FOUND'
              $principalName = 'NOT FOUND'
            }
          }
        }
        elseif ($null -ne $roleAssignment.userEmailAddress) {
          $principalType = $roleAssignment.userAuthenticationType
          $principalName = $roleAssignment.userEmailAddress
        }
        else {
          $principalType = 'undefined'
          $principalName = 'undefined'
        }
        
        $roleAssignment | add-member -MemberType NoteProperty -Name 'name' -Value $_.name
        $roleAssignment | add-member -MemberType NoteProperty -Name 'id' -Value $_.id
        $roleAssignment | add-member -MemberType NoteProperty -Name 'roleDefinition' -Value (Get-RoleDefinition -roleDefinitionId $roleAssignment.roleDefinitionId)
        $roleAssignment | add-member -MemberType NoteProperty -Name 'principalName' -Value $principalName
        $roleAssignment | add-member -MemberType NoteProperty -Name 'principalType' -Value $principalType

        $roleAssignments += $roleAssignment
      }

      return $roleAssignments
    }
    catch {
      throw $_.Exception
    }
  }

  Export-ModuleMember -Function 'Get-FinOpsServicePrincipal'