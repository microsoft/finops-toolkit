# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Grants the managed identity of a Cost Management export write access to the export storage container.

    .DESCRIPTION
    The Grant-FinOpsCostExportStorageAccess command assigns the Storage Blob Data Contributor role to the system-assigned managed identity of a Cost Management export on the destination storage container.

    The role assignment name is derived from the scope, principal, and role, so running the command again updates the same assignment. If an equivalent assignment already exists under another name, for example, one that Cost Management created, the command treats it as success.

    The command uses Azure Resource Manager directly and sets principalType to ServicePrincipal, so it doesn't need Microsoft Graph permissions. If the new identity hasn't replicated yet, the command retries a few times.

    .PARAMETER PrincipalId
    Required. Object ID of the export's system-assigned managed identity.

    .PARAMETER StorageAccountId
    Required. Resource ID of the storage account the export writes to.

    .PARAMETER StorageContainer
    Required. Name of the storage container the export writes to.

    .PARAMETER RetryCount
    Optional. Number of times to retry while the managed identity isn't available yet. Default = 8.

    .PARAMETER RetryDelaySeconds
    Optional. Number of seconds to wait between retries. Default = 15.

    .PARAMETER CommandName
    Optional. Name of the public command that called this command. Used for telemetry. Default = "Grant-FinOpsCostExportStorageAccess".

    .OUTPUTS
    $true if the managed identity has the role assignment; otherwise, $false.

    .EXAMPLE
    Grant-FinOpsCostExportStorageAccess -PrincipalId $principalId -StorageAccountId $storageId -StorageContainer 'msexports'

    Assigns Storage Blob Data Contributor on the msexports container to the specified export identity.
#>
function Grant-FinOpsCostExportStorageAccess
{
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $PrincipalId,

        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountId,

        [Parameter(Mandatory = $true)]
        [string]
        $StorageContainer,

        [Parameter()]
        [int]
        $RetryCount = 8,

        [Parameter()]
        [int]
        $RetryDelaySeconds = 15,

        [Parameter()]
        [string]
        $CommandName = 'Grant-FinOpsCostExportStorageAccess'
    )

    # Storage Blob Data Contributor
    $roleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

    $storageAccountId = '/' + $StorageAccountId.Trim('/')
    $subscriptionId = $storageAccountId.Split('/')[2]
    $containerScope = "$storageAccountId/blobServices/default/containers/$($StorageContainer.ToLower())"

    # Deterministic name so re-running updates the same assignment instead of creating duplicates
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $seed = [System.Text.Encoding]::UTF8.GetBytes("$containerScope|$PrincipalId|$roleId".ToLower())
    $assignmentName = [guid]::new($md5.ComputeHash($seed)).ToString()
    $md5.Dispose()

    $uri = "$containerScope/providers/Microsoft.Authorization/roleAssignments/$assignmentName`?api-version=2022-04-01"
    $body = @{
        properties = @{
            roleDefinitionId = "/subscriptions/$subscriptionId/providers/Microsoft.Authorization/roleDefinitions/$roleId"
            principalId      = $PrincipalId
            principalType    = 'ServicePrincipal'
        }
    }

    if (-not $PSCmdlet.ShouldProcess($containerScope, "Assign Storage Blob Data Contributor to $PrincipalId"))
    {
        return $false
    }

    for ($attempt = 0; $attempt -le $RetryCount; $attempt++)
    {
        # Errors are evaluated below, so don't let Invoke-Rest stop the caller
        $prevErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        try
        {
            $response = Invoke-Rest -Method PUT -Uri $uri -Body $body -CommandName $CommandName
        }
        catch
        {
            $response = @{ Failure = $true; Content = @{ error = @{ code = 'Unknown'; message = $_.Exception.Message } } }
        }
        finally
        {
            $ErrorActionPreference = $prevErrorActionPreference
        }

        $errorCode = $response.Content.error.code
        if ($response.Success -or $errorCode -eq 'RoleAssignmentExists')
        {
            Write-Verbose "Managed identity $PrincipalId has Storage Blob Data Contributor on $containerScope."
            return $true
        }

        if ($errorCode -eq 'PrincipalNotFound' -and $attempt -lt $RetryCount)
        {
            Write-Verbose "Managed identity $PrincipalId isn't available yet. Retrying in $RetryDelaySeconds seconds ($($attempt + 1)/$RetryCount)."
            Start-Sleep -Seconds $RetryDelaySeconds
            continue
        }

        Write-Warning ($script:LocalizedData.CostExport_Identity_RoleAssignmentFailedFormat -f $PrincipalId, $containerScope, $response.Content.error.message, $errorCode)
        return $false
    }

    return $false
}
