<#
    .SYNOPSIS
    Grants the specified service principal or managed identity access to an Enterprise Agreement billing account or department.

    .PARAMETER ObjectId
    The object ID of the service principal or managed identity.

    .PARAMETER TenantId
    The Azure Active Directory tenant which contains the identity.

    .PARAMETER BillingAccountId
    The billing account ID (enrollment number) to grant permissions against.

    .PARAMETER DepartmentId
    The department ID to grant permissions against.

    .EXAMPLE
    Add-FinOpsServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -BillingAccountId 12345

    Grants Enterprise Administrator (read only) permissions to the specified service principal or managed identity

    .EXAMPLE
    Add-FinOpsServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -BillingAccountId 12345 -DepartmentId 67890

    Grants Department Administrator (read only) permissions to the specified service principal or managed identity
#>
function Add-FinOpsServicePrincipal
{
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,
        [Parameter(Mandatory = $true)]
        [string]$BillingAccountId,
        [Parameter(Mandatory = $false)]
        [string]$DepartmentId
    )

    $apiVersion = "2019-10-01-preview" # TODO: Update to latest version
    $azContext = Get-AzContext

    if (![string]::IsNullOrEmpty($DepartmentId) -and ![string]::IsNullOrEmpty($BillingAccountId))
    {
        $BillingScope = 'Department'
    }
    elseif ([string]::IsNullOrEmpty($DepartmentId) -and ![string]::IsNullOrEmpty($BillingAccountId))
    {
        $BillingScope = 'Enrollment'
    }
    else
    {
        throw ($LocalizedData.ServicePrincipal_BillingAccountNotSpecified)
    }

    switch ($BillingScope)
    {
        'Enrollment'
        {
            if ([string]::IsNullOrEmpty($BillingAccountId))
            {
                Write-Output $LocalizedData.ServicePrincipal_BillingAccountNotSpecifiedForDept
                Write-Output ''
                exit 1
            }

            $roleDefinitionId = "/providers/Microsoft.Billing/billingAccounts/{0}/billingRoleDefinitions/24f8edb6-1668-4659-b5e2-40bb5f3a7d7e" -f $BillingAccountId
            $restUri = "{0}providers/Microsoft.Billing/billingAccounts/{1}/billingRoleAssignments/{2}?api-version={3}" -f $azContext.Environment.ResourceManagerUrl, $BillingAccountId, (New-Guid).Guid, $apiVersion
            $body = '{"properties": { "PrincipalId": "{0}", "PrincipalTenantId": "{1}", "roleDefinitionId": "{2}" } }'
            $body = $body.Replace("{0}", $ObjectId)
            $body = $body.Replace("{1}", $TenantId)
            $body = $body.Replace("{2}", $roleDefinitionId)
        }
        'Department'
        {
            if ([string]::IsNullOrEmpty($BillingAccountId))
            {
                Write-Output $LocalizedData.ServicePrincipal_BillingAccountNotSpecifiedForDept
                Write-Output ''
                exit 1
            }
            if ([string]::IsNullOrEmpty($DepartmentId))
            {
                Write-Output $LocalizedData.ServicePrincipal_DeptIdNotSpecified
                Write-Output ''
                exit 1
            }

            $roleDefinitionId = "/providers/Microsoft.Billing/billingAccounts/{0}/departments/{1}/billingRoleDefinitions/db609904-a47f-4794-9be8-9bd86fbffd8a" -f $BillingAccountId, $DepartmentId
            $restUri = "{0}providers/Microsoft.Billing/billingAccounts/{1}/departments/{2}/billingRoleAssignments/{3}?api-version={4}" -f $azContext.Environment.ResourceManagerUrl, $BillingAccountId, $DepartmentId, (New-Guid).Guid, $apiVersion
            $body = '{"properties": { "PrincipalId": "{0}", "PrincipalTenantId": "{1}", "roleDefinitionId": "{2}" } }'
            $body = $body.Replace("{0}", $ObjectId)
            $body = $body.Replace("{1}", $TenantId)
            $body = $body.Replace("{2}", $roleDefinitionId)
        }
        default
        {
            throw ($LocalizedData.ServicePrincipal_InvalidBillingScope -f $BillingScope)
        }
    }

    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
    $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + $token.AccessToken
    }

    try
    {
        # TODO: Switch to Invoke-Rest
        Invoke-RestMethod -Uri $restUri -Method Put -Headers $authHeader -Body $body
        Write-Output ($LocalizedData.ServicePrincipal_SuccessMessage -f $BillingScope)
    }
    catch
    {
        if ($_.Exception.Response.StatusCode -eq 409)
        {
            Write-Output ($LocalizedData.ServicePrincipal_AlreadyGrantedMessage -f $BillingScope)
        }
        else
        {
            $body
            throw $_.Exception
        }
    }
}
