# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Lint rule: Data Factory settings that compile and deploy but fail at runtime.

    Both rules below were found by deploying the AWS FOCUS connector to a live hub. Neither is
    caught by `bicep build`, and the first is not even caught by the ARM deployment of the
    trigger itself - it only surfaces when the trigger is started, which happens in a separate
    deployment script at the end of the hub deployment. A failure there aborts the whole
    deployment and leaves every other trigger stopped.

    1. Schedule trigger start times
       When `timeZone` is 'UTC', Data Factory requires the zone designator on `startTime`:
       'yyyy-MM-ddTHH:mm:ssZ'. Without it the trigger deploys successfully but fails to start
       with InvalidWorkflowTriggerRecurrence. Named Windows time zones (the timeZones module)
       take the opposite form and must not carry the designator.

    2. quoteAllText
       Data Factory rejects `quoteAllText: false` on a Copy activity sink with
       DelimitedTextInvalidSettings ("QuoteAllText cannot set to false for Copy activity
       currently"). To write unquoted text, leave the property unset and set an empty
       `quoteChar` on the dataset instead.
#>

Describe 'DataFactorySettings' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path

        $scanFiles = @(
            Get-ChildItem -Path (Join-Path $repoRoot 'src/templates') -Filter '*.bicep' -Recurse -File -ErrorAction SilentlyContinue |
                Sort-Object FullName -Unique |
                ForEach-Object {
                    @{ FullName = $_.FullName; RelPath = $_.FullName.Substring($repoRoot.Length + 1).Replace('\', '/') }
                }
        )
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path

        $scanFileCount = @(Get-ChildItem -Path (Join-Path $repoRoot 'src/templates') -Filter '*.bicep' -Recurse -File -ErrorAction SilentlyContinue).Count

        # A startTime literal plus whatever follows it up to the next property, so the paired
        # timeZone can be read. Data Factory always emits the two adjacent within recurrence.
        $startTimePattern = [regex]"startTime:\s*'([^']*)'\s*\r?\n\s*timeZone:\s*(.+)"

        $quoteAllTextPattern = [regex]'quoteAllText:\s*false'
    }

    It 'Should scan the template tree' {
        $scanFileCount | Should -BeGreaterThan 20
    }

    It 'Should use the zone designator on UTC schedule trigger start times: <RelPath>' -ForEach $scanFiles {
        $content = Get-Content -Path $FullName -Raw

        $offenders = @(
            foreach ($match in $startTimePattern.Matches($content))
            {
                $startTime = $match.Groups[1].Value
                $timeZone = $match.Groups[2].Value.Trim()

                if ($timeZone -eq "'UTC'" -and -not $startTime.EndsWith('Z'))
                {
                    "startTime '$startTime' with timeZone $timeZone"
                }
                elseif ($timeZone -ne "'UTC'" -and $timeZone.StartsWith("'") -and $startTime.EndsWith('Z'))
                {
                    "startTime '$startTime' with timeZone $timeZone"
                }
            }
        )

        $offenders -join '; ' | Should -BeNullOrEmpty -Because ("Data Factory requires the 'yyyy-MM-ddTHH:mm:ssZ' form when timeZone is UTC, and the form without a designator for a named time zone. The wrong form deploys successfully but fails to start the trigger with InvalidWorkflowTriggerRecurrence, which aborts the hub deployment and leaves every trigger stopped.")
    }

    It 'Should not set quoteAllText to false: <RelPath>' -ForEach $scanFiles {
        $content = Get-Content -Path $FullName -Raw

        @($quoteAllTextPattern.Matches($content)).Count | Should -Be 0 -Because ('Data Factory rejects quoteAllText: false with DelimitedTextInvalidSettings ("QuoteAllText cannot set to false for Copy activity currently"). Leave the property unset and set an empty quoteChar on the dataset to write unquoted text.')
    }
}
