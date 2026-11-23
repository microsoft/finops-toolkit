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

    It 'matches every trigger name defined in Bicep' {
        $modules = Join-Path (Resolve-Path "$PSScriptRoot/../../../..").Path 'src/templates/finops-hub/modules'
        $pattern = [regex]::Match((Get-Content $script:Script -Raw), "(?m)^\`$HubTriggerPattern = '([^']+)'").Groups[1].Value
        $pattern | Should -Not -BeNullOrEmpty
        $names = @()
        foreach ($file in Get-ChildItem $modules -Recurse -Filter *.bicep)
        {
            $text = Get-Content $file.FullName -Raw
            $vars = @{}
            foreach ($m in [regex]::Matches($text, "(?m)^var (\w+) = '([^']*)'")) { $vars[$m.Groups[1].Value] = $m.Groups[2].Value }
            $raw = @()
            $raw += foreach ($m in [regex]::Matches($text, "(?m)^\s*triggerName:\s*'([^']+)'")) { $m.Groups[1].Value }
            $raw += foreach ($m in [regex]::Matches($text, "(?m)^\s*resource \w+ '(?:Microsoft\.DataFactory/factories/)?triggers(?:@[\d-]+)?'[^\r\n]*\{\s*\r?\n\s*name:\s*'([^']+)'")) { $m.Groups[1].Value }
            foreach ($n in $raw)
            {
                $names += [regex]::Replace($n, '\$\{([^}]+)\}', {
                        param($m)
                        $ref = $m.Groups[1].Value
                        if ($ref -match '^core\.containers\.(\w+)$') { $Matches[1] } elseif ($vars.ContainsKey($ref)) { $vars[$ref] } else { $ref }
                    })
            }
        }
        $names.Count | Should -BeGreaterThan 4
        foreach ($n in $names) { $n | Should -Match $pattern -Because "Bicep trigger '$n' must be matched by `$HubTriggerPattern in Init-DataFactory.ps1" }
    }
}
