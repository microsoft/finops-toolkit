# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for the ADF schedule trigger time zone mappings (PR #2236):

    Data Factory schedule triggers validate the timeZone field against Windows time zone IDs
    (the registry IDs enumerated by [TimeZoneInfo]::GetSystemTimeZones() / Get-TimeZone -ListAvailable).
    A display name or IANA-style ID (e.g. 'Japan Standard Time' instead of the Windows ID
    'Tokyo Standard Time') passes deployment but fails at trigger activation with:
      ErrorCode=InvalidWorkflowTriggerRecurrence, ErrorMessage=The recurrence of trigger has an invalid time zone '...'.
    See: https://learn.microsoft.com/azure/data-factory/how-to-create-schedule-trigger#time-zone-option

    These tests parse timeZones.bicep and verify:
    1. Every mapped value resolves in the Windows time zone registry, with exact casing (Windows runners only).
    2. No value is an IANA-style ID (contains '/'), which .NET on Linux would accept but ADF rejects.
    3. Every region key matches the lookup normalization (lowercase, no spaces) and is a known Azure region.
    4. The fallback stays pinned to the valid Windows ID 'UTC' (not a display name).

    The same value checks also run against the compiled deployment templates users actually deploy from
    (docs/deploy/finops-hub-latest.json and finops-hub-preview.json), because those are regenerated at
    release time and can lag a src fix (see the #2236 review discussion). Older versioned templates are
    historical artifacts and intentionally not covered.

    Separately, regression coverage for the ADF trigger startTime Z-suffix fix (issue #2157, PR #2291):
    Data Factory requires a trailing 'Z' on a trigger's startTime whenever timeZone resolves to the 'UTC'
    fallback; without it, activation fails with the same InvalidWorkflowTriggerRecurrence error. The three
    affected triggers in ManagedExports/app.bicep and IngestionQueries/app.bicep make the 'Z' conditional
    on the resolved timeZone, and finops-hub-14.0.json carries the same fix compiled to an ARM if(equals(...))
    expression. These tests pin that pairing so it cannot silently regress. finops-hub-latest.json and
    finops-hub-preview.json are intentionally not covered here (see the #2291 review discussion) - they
    still ship the pre-fix, unconditional startTime and are expected to pick up the fix when regenerated
    at the next release.
#>

Describe 'HubsAdfTriggerTimeZones' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $bicepPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.CostManagement/ManagedExports/timeZones.bicep'
        $bicepLines = Get-Content -Path $bicepPath

        # Extract the region -> time zone entries from the timezoneobject param block.
        $mappings = @()
        $inBlock = $false
        foreach ($line in $bicepLines)
        {
            if ($line -match '^param timezoneobject object = \{') { $inBlock = $true; continue }
            if ($inBlock -and $line -match '^\}') { break }
            if ($inBlock -and $line -match "^\s*([^\s:/]+)\s*:\s*'([^']*)'")
            {
                $mappings += @{ Region = $Matches[1]; TimeZoneId = $Matches[2] }
            }
        }

        $distinctTimeZones = @($mappings | ForEach-Object { $_.TimeZoneId } | Sort-Object -Unique | ForEach-Object { @{ TimeZoneId = $_ } })

        # Extract the same mapping from the compiled deployment templates (shipped artifacts).
        # Each template embeds the timezoneobject param default in nested deployments; the blocks are
        # identical, so collapse to unique (File, Region, TimeZoneId) tuples.
        $deployTemplates = @('finops-hub-latest.json', 'finops-hub-preview.json')
        $deployMappings = @()
        $deployBlockCounts = @()
        foreach ($templateName in $deployTemplates)
        {
            $templateContent = Get-Content -Path (Join-Path $repoRoot "docs/deploy/$templateName") -Raw
            $blocks = [regex]::Matches($templateContent, '"timezoneobject"\s*:\s*\{\s*"type"\s*:\s*"object",\s*"defaultValue"\s*:\s*\{([^}]*)\}')
            $deployBlockCounts += @{ File = $templateName; BlockCount = $blocks.Count }
            $seen = @{}
            foreach ($block in $blocks)
            {
                foreach ($pair in [regex]::Matches($block.Groups[1].Value, '"([^"]+)"\s*:\s*"([^"]*)"'))
                {
                    $key = $pair.Groups[1].Value + '|' + $pair.Groups[2].Value
                    if (-not $seen.ContainsKey($key))
                    {
                        $seen[$key] = $true
                        $deployMappings += @{ File = $templateName; Region = $pair.Groups[1].Value; TimeZoneId = $pair.Groups[2].Value }
                    }
                }
            }
        }

        # Extract every trigger startTime from the two src files fixed by #2291, keyed by the raw line
        # so a failure points straight at the offending statement instead of just a file name.
        $startTimeSrcFiles = @(
            'src/templates/finops-hub/modules/Microsoft.CostManagement/ManagedExports/app.bicep'
            'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/IngestionQueries/app.bicep'
        )
        $startTimeSrcLines = @()
        foreach ($relativePath in $startTimeSrcFiles)
        {
            foreach ($line in (Get-Content -Path (Join-Path $repoRoot $relativePath)))
            {
                if ($line -match '^\s*startTime:')
                {
                    $startTimeSrcLines += @{ File = $relativePath; Line = $line.Trim() }
                }
            }
        }

        # Same pairing, compiled to the ARM if(equals(...)) form, in the one shipped deploy artifact
        # patched alongside the src fix (finops-hub-14.0.json). finops-hub-latest.json and
        # finops-hub-preview.json are excluded - they still ship the pre-fix startTime and pick up the
        # fix at the next release regen.
        $startTimeDeployFile = 'finops-hub-14.0.json'
        $startTimeDeployLines = @()
        foreach ($line in (Get-Content -Path (Join-Path $repoRoot "docs/deploy/$startTimeDeployFile")))
        {
            if ($line -match '"startTime":')
            {
                $startTimeDeployLines += @{ File = $startTimeDeployFile; Line = $line.Trim() }
            }
        }
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $bicepPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.CostManagement/ManagedExports/timeZones.bicep'
        $bicepContent = Get-Content -Path $bicepPath -Raw

        # Known Azure region IDs from toolkit open data. Loaded in BeforeAll (run phase) because
        # BeforeDiscovery variables are not visible inside It blocks at run time.
        $regionIds = @{}
        Import-Csv (Join-Path $repoRoot 'src/open-data/Regions.csv') | ForEach-Object { $regionIds[$_.RegionId] = $true }
    }

    Context 'Parsing' {
        It 'Finds the timezoneobject mappings in timeZones.bicep' -TestCases @(@{ MappingCount = @($mappings).Count }) {
            # Guards the parser itself: if the bicep layout changes, fail loudly instead of green-running zero cases.
            # Count is captured at discovery time (BeforeDiscovery variables are not visible at run time).
            $MappingCount | Should -BeGreaterThan 30
        }

        It 'Finds the timezoneobject blocks in <File>' -TestCases $deployBlockCounts {
            # Same guard for the compiled templates: layout changes must not silently drop coverage.
            $BlockCount | Should -BeGreaterThan 0
        }
    }

    Context 'Windows time zone registry' {
        It 'Maps <Region> to a Windows time zone ID that exists in the registry: <TimeZoneId>' -TestCases $mappings -Skip:(-not $IsWindows) {
            # Get-TimeZone -Id emits a non-terminating error for unknown IDs; -ErrorAction Stop makes it throw.
            $resolved = Get-TimeZone -Id $TimeZoneId -ErrorAction Stop
            # Exact casing: the registry lookup is case-insensitive, but pin the canonical ID so the
            # file never drifts from what ADF documents and the portal dropdown emits.
            $resolved.Id | Should -BeExactly $TimeZoneId
        }
    }

    Context 'Compiled deployment templates' {
        It '<File>: maps <Region> to a Windows time zone ID that exists in the registry: <TimeZoneId>' -TestCases $deployMappings -Skip:(-not $IsWindows) {
            $resolved = Get-TimeZone -Id $TimeZoneId -ErrorAction Stop
            $resolved.Id | Should -BeExactly $TimeZoneId
        }
    }

    Context 'Time zone ID format' {
        It 'Value "<TimeZoneId>" is not an IANA-style or display-name ID' -TestCases $distinctTimeZones {
            $TimeZoneId | Should -Not -BeNullOrEmpty
            # IANA IDs (Area/Location) resolve in .NET on Linux but are rejected by ADF trigger activation.
            $TimeZoneId | Should -Not -Match '/'
            # Known-bad display names that read like valid IDs but are not in the Windows registry.
            $displayNames = @('Japan Standard Time', 'Universal Coordinated Time', 'Coordinated Universal Time')
            $displayNames | Should -Not -Contain $TimeZoneId
        }
    }

    Context 'Region keys' {
        It 'Region key "<Region>" matches the toLower/no-space lookup normalization' -TestCases $mappings {
            # timeZones.bicep resolves timezoneobject[toLower(replace(location, ' ', ''))].
            $Region | Should -BeExactly $Region.ToLowerInvariant()
            $Region | Should -Not -Match '\s'
        }

        It 'Region key "<Region>" is a known Azure region' -TestCases $mappings {
            $regionIds.ContainsKey($Region) | Should -BeTrue -Because "region '$Region' should exist in src/open-data/Regions.csv"
        }
    }

    Context 'Fallback' {
        It "Pins the fallback to the valid Windows ID 'UTC'" {
            # 'UTC' is a real Windows time zone ID; the display name 'Universal Coordinated Time' is not.
            $bicepContent | Should -Match "\?\?\s*'UTC'"
        }
    }

    Context 'startTime UTC suffix' {
        It 'Pairs a Z-suffixed and bare startTime around the UTC fallback in <File>: <Line>' -TestCases $startTimeSrcLines {
            # Data Factory requires the trailing 'Z' only when timeZone resolves to the 'UTC' fallback;
            # a bare 'Z' or an unconditional literal would silently reintroduce #2157 or change scheduling
            # behavior for every mapped, non-UTC region.
            $matched = $Line -match "^startTime:\s*timeZones\.outputs\.Timezone == 'UTC' \? '([0-9T:-]+)Z' : '([0-9T:-]+)'$"
            $matched | Should -BeTrue -Because "startTime should be conditional on the UTC fallback, got: $Line"
            $Matches[1] | Should -BeExactly $Matches[2] -Because 'the UTC and non-UTC branches must use the same timestamp, differing only by the trailing Z'
        }

        It 'Pairs a Z-suffixed and bare startTime around the UTC fallback in <File>: <Line>' -TestCases $startTimeDeployLines {
            # Same invariant, compiled to the ARM if(equals(...)) form shipped in the patched deploy artifact.
            $matched = $Line -match "^`"startTime`":\s*`"\[if\(equals\(reference\('timeZones'\)\.outputs\.Timezone\.value, 'UTC'\), '([0-9T:-]+)Z', '([0-9T:-]+)'\)\]`",?$"
            $matched | Should -BeTrue -Because "startTime should be conditional on the UTC fallback, got: $Line"
            $Matches[1] | Should -BeExactly $Matches[2] -Because 'the UTC and non-UTC branches must use the same timestamp, differing only by the trailing Z'
        }
    }
}
