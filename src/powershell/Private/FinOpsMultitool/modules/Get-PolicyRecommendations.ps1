# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper named for the collection it processes.')]
param()

###########################################################################
# GET-POLICYRECOMMENDATIONS.PS1
# AZURE FINOPS MULTITOOL - FinOps Policy Recommendations
###########################################################################
# Purpose: Compare the customer's existing policy assignments against a
#          curated list of Microsoft-recommended FinOps/cost governance
#          policies (Azure built-in policy definitions).
#
# Sources:
#   - Azure built-in policies (Tags, General, Compute, Storage categories)
#   - Microsoft Cloud Adoption Framework cost governance guidance
#   - AzAdvertizer.net policy catalog reference
#
# Each recommendation includes the built-in policy definition ID so
# it can be deployed directly from the GUI.
###########################################################################

function Get-PolicyRecommendations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ExistingAssignments   # Policy assignment objects from Get-PolicyInventory
    )

    # -- Curated FinOps / Cost Governance Policies ----------------------
    # These are Azure built-in policy definition IDs verified from
    # https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies
    $recommendedPolicies = @(
        # === TAGGING & NAMING (CAF: Enforce Tagging and Naming) ===
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/726aca4c-86e9-4b04-b0c5-073027359532'
            DisplayName  = 'Require a tag on resources'
            Category     = 'Tags'
            Pillar       = 'Understand'
            Priority     = 'Required'
            DefaultEffect = 'Deny'
            AllowedEffects = @('Audit','Deny','Disabled')
            Purpose      = 'Enforce tagging on all resources for cost allocation and chargeback visibility'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#tags'
            Parameters   = @(
                @{ Name = 'tagName';  Label = 'Tag name (e.g. CostCenter)'; Required = $true }
                @{ Name = 'tagValue'; Label = 'Tag value (leave blank for any value)'; Required = $false }
            )
        }
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025'
            DisplayName  = 'Require a tag on resource groups'
            Category     = 'Tags'
            Pillar       = 'Understand'
            Priority     = 'Required'
            DefaultEffect = 'Deny'
            AllowedEffects = @('Audit','Deny','Disabled')
            Purpose      = 'Enforce tagging on resource groups for cost allocation at the container level'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#tags'
            Parameters   = @(
                @{ Name = 'tagName';  Label = 'Tag name (e.g. CostCenter)'; Required = $true }
            )
        }
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/ea3f2387-9b95-492a-a190-fcdc54f7b070'
            DisplayName  = 'Inherit a tag from the resource group if missing'
            Category     = 'Tags'
            Pillar       = 'Understand'
            Priority     = 'Recommended'
            DefaultEffect = 'Modify'
            AllowedEffects = @('Modify','Disabled')
            Purpose      = 'Auto-inherit tags from resource group to child resources for consistent cost allocation'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#tags'
            Parameters   = @(
                @{ Name = 'tagName'; Label = 'Tag name to inherit (e.g. CostCenter)'; Required = $true }
            )
        }
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/40df99da-1232-49b1-a39a-6da8d878f469'
            DisplayName  = 'Inherit a tag from the subscription if missing'
            Category     = 'Tags'
            Pillar       = 'Understand'
            Priority     = 'Recommended'
            DefaultEffect = 'Modify'
            AllowedEffects = @('Modify','Disabled')
            Purpose      = 'Auto-inherit tags from subscription to resources for top-level cost allocation'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#tags'
            Parameters   = @(
                @{ Name = 'tagName'; Label = 'Tag name to inherit (e.g. CostCenter)'; Required = $true }
            )
        }

        # === ALLOWED RESOURCE LOCATIONS (CAF) ===
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
            DisplayName  = 'Allowed locations'
            Category     = 'General'
            Pillar       = 'Optimize'
            Priority     = 'Required'
            DefaultEffect = 'Deny'
            AllowedEffects = @('Audit','Deny','Disabled')
            Purpose      = 'Restrict resource deployment to authorized Azure regions for compliance and cost control'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#general'
            Parameters   = @(
                @{ Name = 'listOfAllowedLocations'; Label = 'Allowed locations (comma-separated, e.g. eastus,westus2,centralus)'; Required = $true; IsArray = $true }
            )
        }

        # === RESTRICT VM SIZES (CAF) ===
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/cccc23c7-8427-4f53-ad12-b6a63eb452b3'
            DisplayName  = 'Allowed virtual machine size SKUs'
            Category     = 'Compute'
            Pillar       = 'Optimize'
            Priority     = 'Required'
            DefaultEffect = 'Deny'
            AllowedEffects = @('Audit','Deny','Disabled')
            Purpose      = 'Restrict VM sizes to prevent over-provisioning and control compute costs'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#compute'
            Parameters   = @(
                @{ Name = 'listOfAllowedSKUs'; Label = 'Allowed VM SKUs (comma-separated, e.g. Standard_D2s_v3,Standard_B2ms)'; Required = $true; IsArray = $true }
            )
        }

        # === ALLOWED STORAGE ACCOUNT SKUS (CAF) ===
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/7433c107-6db4-4ad1-b57a-a76dce0154a1'
            DisplayName  = 'Storage accounts should be limited by allowed SKUs'
            Category     = 'Storage'
            Pillar       = 'Optimize'
            Priority     = 'Recommended'
            DefaultEffect = 'Deny'
            AllowedEffects = @('Audit','Deny','Disabled')
            Purpose      = 'Restrict storage account types to control costs and enforce standard tiers'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#storage'
            Parameters   = @(
                @{ Name = 'listOfAllowedSKUs'; Label = 'Allowed storage SKUs (comma-separated, e.g. Standard_LRS,Standard_GRS,Standard_ZRS)'; Required = $true; IsArray = $true }
            )
        }

        # === ALLOWED DISK SKUS (CAF) ===
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d'
            DisplayName  = 'Allowed managed disk SKUs'
            Category     = 'Compute'
            Pillar       = 'Optimize'
            Priority     = 'Recommended'
            DefaultEffect = 'Deny'
            AllowedEffects = @('Audit','Deny','Disabled')
            Purpose      = 'Restrict managed disk types to prevent costly Premium or Ultra disks where not needed'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#compute'
            Parameters   = @(
                @{ Name = 'listOfAllowedSKUs'; Label = 'Allowed disk SKUs (comma-separated, e.g. Standard_LRS,StandardSSD_LRS,Premium_LRS)'; Required = $true; IsArray = $true }
            )
        }

        # === DEPLOY DIAGNOSTIC SETTINGS (CAF) ===
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-583c-429a-8828-af049802c1d9'
            DisplayName  = 'Audit diagnostic setting'
            Category     = 'Monitoring'
            Pillar       = 'Understand'
            Priority     = 'Required'
            DefaultEffect = 'AuditIfNotExists'
            AllowedEffects = @('AuditIfNotExists','Disabled')
            Purpose      = 'Automatically enable logging for diagnostics - ensures visibility into resource operations and costs'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#monitoring'
            Parameters   = @(
                @{ Name = 'listOfResourceTypes'; Label = 'Resource types to audit (comma-separated, e.g. Microsoft.Compute/virtualMachines,Microsoft.Sql/servers,Microsoft.Storage/storageAccounts)'; Required = $true; IsArray = $true }
            )
        }

        # === ADDITIONAL FINOPS-ALIGNED ===
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749'
            DisplayName  = 'Not allowed resource types'
            Category     = 'General'
            Pillar       = 'Optimize'
            Priority     = 'Recommended'
            DefaultEffect = 'Deny'
            AllowedEffects = @('Audit','Deny','Disabled')
            Purpose      = 'Block expensive or unnecessary resource types to reduce cost sprawl'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#general'
            Parameters   = @(
                @{ Name = 'listOfResourceTypesNotAllowed'; Label = 'Resource types to block (comma-separated, e.g. Microsoft.Sql/servers,Microsoft.HDInsight/clusters)'; Required = $true; IsArray = $true }
            )
        }
        [PSCustomObject]@{
            PolicyDefId  = '/providers/Microsoft.Authorization/policyDefinitions/013e242c-8828-4970-87b3-ab247555486d'
            DisplayName  = 'Azure Backup should be enabled for Virtual Machines'
            Category     = 'Backup'
            Pillar       = 'Quantify'
            Priority     = 'Recommended'
            DefaultEffect = 'AuditIfNotExists'
            AllowedEffects = @('AuditIfNotExists','Disabled')
            Purpose      = 'Ensure VMs are backed up to prevent costly data loss recovery scenarios'
            Reference    = 'https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#backup'
        }
    )

    # -- Match existing assignments against recommendations ------------
    $existingDefIds = @{}
    $initiativeCache = @{}
    $initiativeErrors = [System.Collections.Generic.List[object]]::new()
    $scopePattern = '(?:(?:/subscriptions/[0-9a-fA-F-]{36})|(?:/providers/Microsoft\.Management/managementGroups/[A-Za-z0-9._()-]+))?'
    $initiativePattern = "^$scopePattern/providers/Microsoft\.Authorization/policySetDefinitions/[A-Za-z0-9._()-]+$"
    $policyPattern = "^$scopePattern/providers/Microsoft\.Authorization/policyDefinitions/[A-Za-z0-9._()-]+(?:/versions/[0-9.]+)?$"
    foreach ($assignment in $ExistingAssignments) {
        $definitionId = ([string]$assignment.PolicyDefId).TrimEnd('/')
        if (-not $definitionId) { continue }
        $isInitiative = $assignment.Origin -eq 'Initiative' -or $definitionId -match '/policySetDefinitions/'
        $memberIds = @($definitionId)
        if ($isInitiative) {
            if (-not $initiativeCache.ContainsKey($definitionId)) {
                try {
                    if ($definitionId -notmatch $initiativePattern) { throw 'The initiative ID is not a valid policy set definition resource ID.' }
                    $response = Invoke-AzRestMethodWithRetry -Path "$($definitionId)?api-version=2023-04-01" -Method GET
                    if (-not $response -or $response.StatusCode -ne 200 -or -not $response.Content) {
                        throw "Initiative membership returned HTTP $($response.StatusCode)."
                    }
                    $properties = ($response.Content | ConvertFrom-Json -ErrorAction Stop).properties
                    if (-not $properties -or $null -eq $properties.policyDefinitions -or $properties.policyDefinitions -isnot [array]) {
                        throw 'The initiative response has no valid policyDefinitions collection.'
                    }
                    $members = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                    foreach ($member in $properties.policyDefinitions) {
                        $memberId = ([string]$member.policyDefinitionId).TrimEnd('/')
                        if ($memberId -notmatch $policyPattern) { throw 'An initiative member has an invalid policy definition ID.' }
                        [void]$members.Add(($memberId -replace '/versions/[0-9.]+$', ''))
                    }
                    $initiativeCache[$definitionId] = @($members)
                }
                catch {
                    $initiativeCache[$definitionId] = @()
                    [void]$initiativeErrors.Add([pscustomobject]@{ InitiativeId = $definitionId; Error = $_.Exception.Message })
                }
            }
            $memberIds = @($initiativeCache[$definitionId])
        }
        foreach ($memberId in $memberIds) {
            $policyId = $memberId -replace '/versions/[0-9.]+$', ''
            if (-not $existingDefIds.ContainsKey($policyId)) { $existingDefIds[$policyId] = [System.Collections.Generic.List[object]]::new() }
            [void]$existingDefIds[$policyId].Add([pscustomobject]@{
                AssignmentId = $assignment.AssignmentId
                AssignmentName = $assignment.AssignmentName
                Scope = $assignment.Scope
                EnforcementMode = $assignment.EnforcementMode
                Source = if ($isInitiative) { 'Initiative' } else { 'Direct' }
                InitiativeId = if ($isInitiative) { $definitionId } else { $null }
            })
        }
    }

    $analysis = foreach ($rec in $recommendedPolicies) {
        $matchedAssignments = @($existingDefIds[$rec.PolicyDefId] | Where-Object { $null -ne $_ })
        $status = if (@($matchedAssignments | Where-Object Source -EQ 'Direct').Count -gt 0) { 'Assigned' }
        elseif ($matchedAssignments.Count -gt 0) { 'Assigned (Initiative)' }
        elseif ($initiativeErrors.Count -gt 0) { 'Unknown' }
        else { 'Missing' }

        [PSCustomObject]@{
            DisplayName    = $rec.DisplayName
            Status         = $status
            Category       = $rec.Category
            Pillar         = $rec.Pillar
            Priority       = $rec.Priority
            DefaultEffect  = $rec.DefaultEffect
            AllowedEffects = $rec.AllowedEffects
            Purpose        = $rec.Purpose
            PolicyDefId    = $rec.PolicyDefId
            Reference      = $rec.Reference
            Parameters     = if ($rec.Parameters) { $rec.Parameters } else { @() }
            MatchedAssignments = $matchedAssignments
            Note = if ($status -eq 'Unknown') { 'Initiative membership is incomplete. This policy cannot be confirmed missing.' }
                elseif ($status -eq 'Missing') { 'No matching definition ID was found in the supplied assignments or readable initiatives. Equivalent custom policies are not assessed.' }
                else { 'Assignment presence does not establish enforcement, parameter settings, exclusions, or compliance. Review the matched assignments.' }
        }
    }

    $missing  = @($analysis | Where-Object { $_.Status -eq 'Missing' })
    $assigned = @($analysis | Where-Object { $_.Status -in @('Assigned', 'Assigned (Initiative)') })
    $unknown = @($analysis | Where-Object Status -EQ 'Unknown')

    return [PSCustomObject]@{
        Analysis         = $analysis
        Missing          = $missing
        Assigned         = $assigned
        Unknown          = $unknown
        InitiativeErrors = $initiativeErrors.ToArray()
        CoverageIncomplete = ($initiativeErrors.Count -gt 0)
        CompliancePct    = if ($initiativeErrors.Count -eq 0) { [math]::Round(($assigned.Count / $analysis.Count) * 100, 0) } else { $null }
    }
}
