###########################################################################
# DEPLOY-POLICYASSIGNMENT.PS1
# AZURE FINOPS MULTITOOL - Deploy Azure Policy Assignments
###########################################################################
# Purpose: Create a policy assignment at a given scope (management group,
#          subscription, or resource group) for a built-in policy
#          definition with a user-selected effect.
#
# Uses ARM REST API PUT to create policy assignments.
###########################################################################

function Deploy-PolicyAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Scope,              # /subscriptions/xxx or /subscriptions/xxx/resourceGroups/yyy

        [Parameter(Mandatory)]
        [string]$PolicyDefinitionId, # Full built-in policy def resource ID

        [Parameter(Mandatory)]
        [string]$Effect,             # Audit, Deny, Disabled, etc.

        [string]$DisplayName = '',

        [hashtable]$AdditionalParameters = @{}
    )

    # Input validation
    if ($Scope -notmatch '^/subscriptions/[a-f0-9-]+') {
        throw "Invalid scope format. Must start with /subscriptions/{guid}."
    }
    if ($Effect -notin @('Audit','Deny','Disabled','AuditIfNotExists','DeployIfNotExists','Modify','Append')) {
        throw "Invalid effect: $Effect. Must be one of: Audit, Deny, Disabled, AuditIfNotExists, DeployIfNotExists, Modify, Append"
    }
    $isInitiative = $PolicyDefinitionId -match '/policySetDefinitions/'
    if ($PolicyDefinitionId -notmatch '^/providers/Microsoft\.Authorization/policy(Set)?Definitions/') {
        throw "Invalid policy definition ID format."
    }

    # Generate a unique assignment name (max 128 chars, alphanumeric + hyphens)
    $defGuid = ($PolicyDefinitionId -split '/')[-1]
    $scopeHash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($Scope)
        )
    ).Replace('-','').Substring(0,8).ToLower()
    $assignName = "finops-$scopeHash-$defGuid"
    if ($assignName.Length -gt 128) { $assignName = $assignName.Substring(0, 128) }

    $assignDisplayName = if ($DisplayName) { "FinOps: $DisplayName" } else { "FinOps Policy Assignment" }

    Write-Host "  Deploying policy assignment '$assignDisplayName' to scope: $Scope" -ForegroundColor Cyan
    Write-Host "  Effect: $Effect | Definition: $defGuid" -ForegroundColor Cyan

    # Query the policy definition to discover which parameters it actually accepts
    $validParamNames = @()
    try {
        $defPath = "$($PolicyDefinitionId)?api-version=2021-06-01"
        $defResp = Invoke-AzRestMethodWithRetry -Path $defPath -Method GET
        if ($defResp.StatusCode -eq 200) {
            $defObj = $defResp.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($defObj.properties.parameters) {
                $validParamNames = @($defObj.properties.parameters.PSObject.Properties.Name)
                Write-Host "  Valid parameters: $($validParamNames -join ', ')" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "  Could not query policy definition parameters, sending all." -ForegroundColor Yellow
    }

    # Build parameters - only include params the definition accepts
    $policyParams = @{}
    # Include effect only if the definition has an effect parameter
    if ($validParamNames.Count -eq 0 -or $validParamNames -contains 'effect') {
        $policyParams['effect'] = @{ value = $Effect }
    }
    foreach ($key in $AdditionalParameters.Keys) {
        if ($validParamNames.Count -eq 0 -or $validParamNames -contains $key) {
            $policyParams[$key] = @{ value = $AdditionalParameters[$key] }
        } else {
            Write-Host "  Skipping parameter '$key' - not defined in policy definition." -ForegroundColor Yellow
        }
    }

    $body = @{
        properties = @{
            displayName        = $assignDisplayName
            description        = "Deployed by Azure FinOps Multitool"
            policyDefinitionId = $PolicyDefinitionId
            parameters         = $policyParams
            enforcementMode    = 'Default'
        }
    } | ConvertTo-Json -Depth 10

    $assignPath = "$Scope/providers/Microsoft.Authorization/policyAssignments/$($assignName)?api-version=2022-06-01"

    try {
        $response = Invoke-AzRestMethodWithRetry -Path $assignPath -Method PUT -Payload $body
        if ($response.StatusCode -in @(200, 201)) {
            Write-Host "    Policy assignment created successfully." -ForegroundColor Green
            return [PSCustomObject]@{
                Success        = $true
                Message        = "Policy '$assignDisplayName' assigned with effect '$Effect' to $Scope"
                StatusCode     = $response.StatusCode
                AssignmentName = $assignName
            }
        } else {
            $errBody = ($response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue)
            $errMsg = if ($errBody.error) { $errBody.error.message } else { "HTTP $($response.StatusCode)" }
            Write-Warning "    Policy assignment failed: $errMsg"
            return [PSCustomObject]@{
                Success    = $false
                Message    = $errMsg
                StatusCode = $response.StatusCode
            }
        }
    } catch {
        Write-Warning "    Policy assignment error: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success    = $false
            Message    = $_.Exception.Message
            StatusCode = 0
        }
    }
}

function Remove-PolicyAssignment {
    <#
    .SYNOPSIS
    Deletes a policy assignment by its full ARM assignment ID.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AssignmentId   # Full ARM resource ID of the assignment
    )

    Write-Host "  Removing policy assignment: $AssignmentId" -ForegroundColor Cyan

    $deletePath = "$($AssignmentId)?api-version=2022-06-01"

    try {
        $response = Invoke-AzRestMethodWithRetry -Path $deletePath -Method DELETE
        if ($response.StatusCode -in @(200, 204)) {
            Write-Host "    Policy assignment removed successfully." -ForegroundColor Green
            return [PSCustomObject]@{
                Success    = $true
                Message    = "Policy assignment removed"
                StatusCode = $response.StatusCode
            }
        } else {
            $errBody = ($response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue)
            $errMsg = if ($errBody.error) { $errBody.error.message } else { "HTTP $($response.StatusCode)" }
            Write-Warning "    Policy removal failed: $errMsg"
            return [PSCustomObject]@{
                Success    = $false
                Message    = $errMsg
                StatusCode = $response.StatusCode
            }
        }
    } catch {
        Write-Warning "    Policy removal error: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success    = $false
            Message    = $_.Exception.Message
            StatusCode = 0
        }
    }
}

function Get-PolicyScopes {
    <#
    .SYNOPSIS
    Returns available scopes (subscriptions + resource groups) for policy assignment.
    Identical pattern to Get-TagScopes but for policy deployment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    $scopes = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($sub in $Subscriptions) {
        [void]$scopes.Add([PSCustomObject]@{
            DisplayName = "[Sub] $($sub.Name)"
            Scope       = "/subscriptions/$($sub.Id)"
            Type        = 'Subscription'
        })

        try {
            $rgPath = "/subscriptions/$($sub.Id)/resourcegroups?api-version=2021-04-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $rgPath -Method GET
            if ($resp.StatusCode -eq 200) {
                $rgs = ($resp.Content | ConvertFrom-Json).value
                foreach ($rg in $rgs) {
                    [void]$scopes.Add([PSCustomObject]@{
                        DisplayName = "  [RG] $($sub.Name) / $($rg.name)"
                        Scope       = "/subscriptions/$($sub.Id)/resourceGroups/$($rg.name)"
                        Type        = 'ResourceGroup'
                    })
                }
            }
        } catch {
            Write-Warning "  Could not list RGs for $($sub.Name): $($_.Exception.Message)"
        }
    }

    return $scopes
}
