# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Grants the FinOps hub Data Factory identity admin access to the Fabric eventhouse Ingestion and Hub databases.

    .PARAMETER QueryUri
    Required. Fabric eventhouse query URI.

    .PARAMETER PrincipalId
    Required. Object ID of the Data Factory managed identity.

    .PARAMETER TenantId
    Required. Entra tenant ID.

    .EXAMPLE
    Grant-FinOpsHubFabricAccess -QueryUri 'https://xxx.kusto.fabric.microsoft.com' -PrincipalId $adfId -TenantId $tenantId
#>
function Grant-FinOpsHubFabricAccess
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $QueryUri,

        [Parameter(Mandatory = $true)]
        [string]
        $PrincipalId,

        [Parameter(Mandatory = $true)]
        [string]
        $TenantId
    )

    foreach ($database in 'Ingestion', 'Hub')
    {
        if (-not $PSCmdlet.ShouldProcess($database, 'Add Data Factory identity as database admin'))
        {
            continue
        }

        try
        {
            $token = (Get-AzAccessToken -ResourceUrl 'https://kusto.kusto.windows.net').Token
            $body = @{ db = $database; csl = ".add database $database admins ('aadapp=$PrincipalId;$TenantId')" } | ConvertTo-Json
            Invoke-RestMethod -Method Post -Uri "$($QueryUri.TrimEnd('/'))/v1/rest/mgmt" -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $body | Out-Null
        }
        catch
        {
            Write-Warning "Could not grant the Data Factory identity admin on the $database database. Run the .add database command manually (see https://aka.ms/finops/hubs/deploy#optional-configure-fabric-access). $($_.Exception.Message)"
        }
    }
}
