# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for hub app storage role assignments (issue #2253):

    Hub apps declare the roles their Data Factory identity needs on the publisher storage account
    via the storageRoles parameter of fx/hub-app.bicep. Managed exports requests Role Based Access
    Control Administrator there, because Cost Management exports are created with a system-assigned
    identity that Cost Management must grant access to the export destination. Without it, every
    export creation fails with:
      {"error":{"code":"Unauthorized","message":"The user does not have authorization to perform
      'Microsoft.Authorization/roleAssignments/write' action on specified storage account, ..."}}

    The role assignment loop used to be gated on the "Storage" feature, which apps only declare when
    they create the publisher storage account. Managed exports uses the storage account created by
    Microsoft.CostManagement.Exports, so it doesn't declare the feature, and every role it requested
    was silently dropped at build time.

    These tests parse the app registrations and fx/hub-app.bicep and verify:
    1. Roles requested via storageRoles always flow into the assignment loop.
    2. The assignment loop isn't gated on the "Storage" feature.
    3. Every app that requests storage roles declares the "DataFactory" feature, since the roles are
       assigned to the Data Factory identity and are otherwise dropped.
    4. Managed exports still requests Role Based Access Control Administrator.
#>

Describe 'HubsAppStorageRoles' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $modulesPath = Join-Path $repoRoot 'src/templates/finops-hub/modules'

        # Extract the features and storageRoles passed to fx/hub-app.bicep from every app registration.
        $appRegistrations = @(Get-ChildItem -Path $modulesPath -Recurse -Filter 'app.bicep' -File | ForEach-Object {
                $content = Get-Content -Path $_.FullName -Raw
                if ($content -notmatch 'hub-app\.bicep') { return }

                $getValues = {
                    param([string]$Name)
                    $match = [regex]::Match($content, "(?ms)^\s*$Name\s*:\s*\[(.*?)^\s*\]")
                    if (-not $match.Success) { return @() }
                    return @([regex]::Matches($match.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
                }

                @{
                    Name         = (Split-Path -Path $_.DirectoryName -Leaf)
                    Path         = $_.FullName
                    Features     = @(& $getValues 'features')
                    StorageRoles = @(& $getValues 'storageRoles')
                }
            })

        $appsWithStorageRoles = @($appRegistrations | Where-Object { $_.StorageRoles.Count -gt 0 })
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $hubAppPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/fx/hub-app.bicep'
        $hubAppContent = Get-Content -Path $hubAppPath -Raw

        # Role definition ID for Role Based Access Control Administrator
        # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator
        $rbacAdministratorRoleId = 'f58310d9-a9f6-439a-9e8d-f62e7b41a168'

        $managedExportsPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.CostManagement/ManagedExports/app.bicep'
        $managedExportsContent = Get-Content -Path $managedExportsPath -Raw

        # The variable the role assignment loop iterates over
        $factoryStorageRoles = [regex]::Match($hubAppContent, '(?ms)^var factoryStorageRoles\s*=.*?^\]\)').Value

        # The condition on the storage role assignment loop
        $storageRoleAssignmentCondition = [regex]::Match($hubAppContent, "(?ms)resource storageRoleAssignments\s+'Microsoft\.Authorization/roleAssignments@[^']+'\s*=\s*\[\s*for\s+\w+\s+in\s+(?<roles>\w+)\s*:\s*if\s*\((?<condition>[^)]*(?:\([^)]*\)[^)]*)*)\)")
    }

    Context 'fx/hub-app.bicep' {

        It 'Should iterate over a role list that always includes the requested storageRoles' {
            $factoryStorageRoles | Should -Match 'union\(\s*storageRoles\s*,'
        }

        It 'Should assign storage roles without requiring the Storage feature' {
            $storageRoleAssignmentCondition.Success | Should -BeTrue -Because 'the storage role assignment loop should be parseable'
            $storageRoleAssignmentCondition.Groups['roles'].Value | Should -Be 'factoryStorageRoles'
            $storageRoleAssignmentCondition.Groups['condition'].Value | Should -Not -Match 'usesStorage' -Because 'apps that request storage roles do not necessarily create the publisher storage account (issue #2253)'
        }

        It 'Should still require the Data Factory feature to assign storage roles' {
            $storageRoleAssignmentCondition.Groups['condition'].Value | Should -Match 'usesDataFactory' -Because 'the roles are assigned to the Data Factory identity'
        }
    }

    Context 'App registrations' {

        It 'Should find at least one app that requests storage roles' -ForEach @{ Count = 0 } {
            # Recomputed here so the assertion runs even if discovery found nothing
            $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
            $modulesPath = Join-Path $repoRoot 'src/templates/finops-hub/modules'
            $requesting = @(Get-ChildItem -Path $modulesPath -Recurse -Filter 'app.bicep' -File | Where-Object {
                    (Get-Content -Path $_.FullName -Raw) -match '(?ms)hub-app\.bicep.*^\s*storageRoles\s*:\s*\[\s*\r?\n\s*[^\]]'
                })
            $requesting.Count | Should -BeGreaterThan 0
        }

        It 'Should declare the DataFactory feature when requesting storage roles: <Name>' -ForEach $appsWithStorageRoles {
            $Features | Should -Contain 'DataFactory' -Because 'storage roles are assigned to the Data Factory identity and are dropped when the app has no Data Factory'
        }
    }

    Context 'Managed exports' {

        It 'Should request the Role Based Access Control Administrator role' {
            $managedExportsContent | Should -Match $rbacAdministratorRoleId -Because 'Cost Management requires the caller to grant the export identity access to the destination storage account'
        }
    }
}
