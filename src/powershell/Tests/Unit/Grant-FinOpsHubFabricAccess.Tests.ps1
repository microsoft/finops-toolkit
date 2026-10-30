# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Grant-FinOpsHubFabricAccess' {
        BeforeAll {
            function Get-AzAccessToken { param($ResourceUrl, $AsSecureString) }
            Mock -CommandName 'Get-AzAccessToken' { [pscustomobject]@{ Token = 'token' } }
            Mock -CommandName 'Invoke-RestMethod' { }
        }

        It 'Should grant admin on both databases to the Data Factory identity' {
            Grant-FinOpsHubFabricAccess -QueryUri 'https://x.kusto.fabric.microsoft.com/' -PrincipalId 'p-id' -TenantId 't-id' -Confirm:$false

            Should -Invoke -CommandName 'Invoke-RestMethod' -Times 2
            Should -Invoke -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter {
                $Uri -eq 'https://x.kusto.fabric.microsoft.com/v1/rest/mgmt' -and $Body -like "*.add database Ingestion admins ('aadapp=p-id;t-id')*" }
            Should -Invoke -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter { $Body -like "*.add database Hub admins ('aadapp=p-id;t-id')*" }
        }

        It 'Should send a plain-text bearer token when Get-AzAccessToken returns a SecureString' {
            Mock -CommandName 'Get-AzAccessToken' { [pscustomobject]@{ Token = (ConvertTo-SecureString 'secret' -AsPlainText -Force) } }

            Grant-FinOpsHubFabricAccess -QueryUri 'https://x/' -PrincipalId 'p' -TenantId 't' -Confirm:$false

            Should -Invoke -CommandName 'Invoke-RestMethod' -Times 2 -ParameterFilter { $Headers.Authorization -eq 'Bearer secret' }
        }

        It 'Should not call the eventhouse with -WhatIf' {
            Grant-FinOpsHubFabricAccess -QueryUri 'https://x/' -PrincipalId 'p' -TenantId 't' -WhatIf

            Should -Invoke -CommandName 'Invoke-RestMethod' -Times 0
        }

        It 'Should warn and not throw when the grant fails' {
            Mock -CommandName 'Invoke-RestMethod' { throw 'denied' }

            { Grant-FinOpsHubFabricAccess -QueryUri 'https://x/' -PrincipalId 'p' -TenantId 't' -Confirm:$false -WarningVariable w -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
}
