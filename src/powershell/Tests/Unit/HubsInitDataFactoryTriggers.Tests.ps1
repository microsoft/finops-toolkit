# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for #1995: Init-DataFactory.ps1 -StartTriggers started every stopped trigger,
    including leftover v0.7 triggers with an invalid time zone. Only the hub's own triggers may start.
#>

Describe 'Init-DataFactory.ps1 -StartTriggers (#1995)' {
    BeforeAll {
        $script:Script = Join-Path (Resolve-Path "$PSScriptRoot/../../../..").Path 'src/templates/finops-hub/modules/fx/scripts/Init-DataFactory.ps1'
        # Stubs so Pester can mock Az cmdlets that may not be installed
        function Get-AzDataFactoryV2Trigger { param($ResourceGroupName, $DataFactoryName, $Name) }
        function Start-AzDataFactoryV2Trigger { param($ResourceGroupName, $DataFactoryName, $Name, [switch]$Force) }
        function Stop-AzDataFactoryV2Trigger { param($ResourceGroupName, $DataFactoryName, $Name, [switch]$Force) }
        function Add-AzDataFactoryV2TriggerSubscription { param($ResourceGroupName, $DataFactoryName, $Name) }
        function Remove-AzDataFactoryV2TriggerSubscription { param($ResourceGroupName, $DataFactoryName, $Name) }
        function Get-AzDataFactoryV2TriggerSubscriptionStatus { param($ResourceGroupName, $DataFactoryName, $Name) }
        function New-FakeTrigger($Name, $State) { [pscustomobject]@{ Name = $Name; Properties = [pscustomobject]@{ RuntimeState = $State; BlobPathBeginsWith = $null } } }

        Mock Get-AzDataFactoryV2Trigger {
            if ($Name) { return New-FakeTrigger $Name ($global:FtkStarted -contains $Name ? 'Started' : 'Stopped') }
            @(
                New-FakeTrigger 'config_DailySchedule' 'Stopped'
                New-FakeTrigger 'msexports_ManifestAdded' 'Stopped'
                New-FakeTrigger 'queries_DailySchedule' 'Stopped'
                New-FakeTrigger 'msexports_ExecuteETL' 'Stopped'
                New-FakeTrigger 'LegacyV07Trigger' 'Stopped'
            )
        }
        Mock Start-AzDataFactoryV2Trigger { $global:FtkStarted += $Name }
        Mock Stop-AzDataFactoryV2Trigger { }
        Mock Start-Sleep { }
    }

    BeforeEach { $global:FtkStarted = @() }

    It 'starts only the hub triggers' {
        & $script:Script -DataFactoryResourceGroup rg -DataFactoryName adf -StartTriggers | Out-Null
        $global:FtkStarted | Sort-Object | Should -Be @('config_DailySchedule', 'msexports_ManifestAdded', 'queries_DailySchedule')
    }

    It 'still stops every trigger' {
        Mock Get-AzDataFactoryV2Trigger {
            if ($Name) { return New-FakeTrigger $Name 'Stopped' }
            @(New-FakeTrigger 'config_DailySchedule' 'Started'; New-FakeTrigger 'LegacyV07Trigger' 'Started')
        }
        & $script:Script -DataFactoryResourceGroup rg -DataFactoryName adf -StopTriggers | Out-Null
        Should -Invoke Stop-AzDataFactoryV2Trigger -Times 2 -Exactly
    }
}
