# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Static regression harness for the FinOps hub FOCUS schema setup scripts (Analytics/scripts/*.kql).

    Covers the four D6 check categories from the FOCUS 1.4 plan, each mapped to a v1_2-era regression:
    1. Registration completeness - every versioned setup script is registered in .build.config (Fabric
       bundle) and loaded in Analytics/app.bicep (prevents #1777: v1_2 script missing from Fabric build).
    2. Version-string consistency - versioned files only reference other schema versions through
       allowlisted patterns, and no conflict markers or phantom versions exist (prevents stale
       cross-version copy/paste references and committed merge conflict markers).
    3. Exactly one enabled update policy version - all enabled update policies live in the current
       (highest) schema version; older versions are fully disabled (prevents double ingestion).
    4. Column and conversion contracts - v1_4 tables carry the FOCUS 1.4 columns, hub functions union
       every schema version, and the provider column rename round-trips without inversion.

    All checks are static text analysis; no Azure Data Explorer connection is needed.
#>

Describe 'HubsFocusSchemas' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scriptsPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'

        # Discover versioned setup scripts dynamically so new files (e.g., a future v1_5 or another
        # size-limit split file) are covered without updating this test.
        $ingestionSetupFiles = @(Get-ChildItem -Path $scriptsPath -Filter 'IngestionSetup_v1_*.kql' | ForEach-Object {
                @{ Name = $_.Name; FullName = $_.FullName; Version = $(if ($_.Name -match '_v1_(\d+)') { $Matches[1] }) }
            })
        $hubSetupFiles = @(Get-ChildItem -Path $scriptsPath -Filter 'HubSetup_v1_*.kql' | ForEach-Object {
                @{ Name = $_.Name; FullName = $_.FullName; Version = $(if ($_.Name -match '_v1_(\d+)') { $Matches[1] }) }
            })
        $versionedSetupFiles = $ingestionSetupFiles + $hubSetupFiles
        $registeredSetupFiles = $versionedSetupFiles + @(Get-ChildItem -Path $scriptsPath -Filter 'HubSetup_Latest.kql' | ForEach-Object {
                @{ Name = $_.Name; FullName = $_.FullName; Version = $null }
            })

        # Files that define the FOCUS 1.4 side of the provider column rename (up-conversion).
        $v14SetupFiles = @($versionedSetupFiles | Where-Object { $_.Version -eq '4' })

        # Managed datasets that existed before FOCUS 1.4 (unioned across v1_0, v1_2, and v1_4).
        $managedDatasets = @('CommitmentDiscountUsage', 'Costs', 'Prices', 'Recommendations', 'Transactions')

        # Supplemental datasets introduced with FOCUS 1.4 (v1_4 final tables only).
        $v14OnlyDatasets = @('BillingPeriods', 'ContractCommitments', 'InvoiceDetails')

        $allDatasets = @($managedDatasets + $v14OnlyDatasets | Sort-Object)
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $hubRoot = Join-Path $repoRoot 'src/templates/finops-hub'
        $scriptsPath = Join-Path $hubRoot 'modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $rawTablesContent = Get-Content -Path (Join-Path $scriptsPath 'IngestionSetup_RawTables.kql') -Raw

        $ingestionFiles = @{
            v1_0 = Get-Content -Path (Join-Path $scriptsPath 'IngestionSetup_v1_0.kql') -Raw
            v1_2 = Get-Content -Path (Join-Path $scriptsPath 'IngestionSetup_v1_2.kql') -Raw
            # FOCUS 1.4 ingestion setup is split across two files to stay under the Bicep
            # loadTextContent() 131 KB limit (D9); combine them for schema-level assertions.
            v1_4 = @(Get-ChildItem -Path $scriptsPath -Filter 'IngestionSetup_v1_4*.kql' | ForEach-Object { Get-Content -Path $_.FullName -Raw }) -join "`n"
        }

        $hubFiles = @{
            v1_0   = Get-Content -Path (Join-Path $scriptsPath 'HubSetup_v1_0.kql') -Raw
            v1_2   = Get-Content -Path (Join-Path $scriptsPath 'HubSetup_v1_2.kql') -Raw
            v1_4   = Get-Content -Path (Join-Path $scriptsPath 'HubSetup_v1_4.kql') -Raw
            Latest = Get-Content -Path (Join-Path $scriptsPath 'HubSetup_Latest.kql') -Raw
        }

        $appBicep = Get-Content -Path (Join-Path $hubRoot 'modules/Microsoft.FinOpsHubs/Analytics/app.bicep') -Raw
        $buildConfig = Get-Content -Path (Join-Path $hubRoot '.build.config') -Raw | ConvertFrom-Json
        $combineKqlFiles = @($buildConfig.combineKql | ForEach-Object { $_.files })

        # Allowlist of legitimate cross-version reference patterns. Any other reference to a schema
        # version different from the file's own version fails the version-string consistency check.
        # Add new entries deliberately - each one is an explicit exception, not a convenience.
        $crossVersionAllowlist = @(
            @{
                Pattern = "database\('Ingestion'\)\.\w+_final_v1_\d"
                Reason  = 'Hub setup functions union final tables from every schema version by design.'
            }
            @{
                Pattern = "docstring\s*=?\s*'DEPRECATED:.*Use \w+_v1_\d\(\) instead"
                Reason  = 'Deprecation docstrings point to the successor version function.'
            }
            @{
                Pattern = 'TODO: Remove x_SourceChanges in v1_3 \(or later\)'
                Reason  = 'Known benign TODO in IngestionSetup_v1_2.kql; v1_3 was skipped as a hub schema version.'
            }
        )

        # Returns cross-version reference violations for one file: every identifier ending in _v1_<N>
        # where N is not the file's own version and the line matches no allowlist pattern.
        function Get-CrossVersionViolation([string]$FilePath, [string]$OwnVersion)
        {
            $violations = @()
            $lineNumber = 0
            foreach ($line in [System.IO.File]::ReadAllLines($FilePath))
            {
                $lineNumber++
                foreach ($token in [regex]::Matches($line, '[A-Za-z0-9]\w*_v1_(\d+)'))
                {
                    if ($token.Groups[1].Value -eq $OwnVersion) { continue }
                    $isAllowed = $false
                    foreach ($rule in $crossVersionAllowlist)
                    {
                        if ($line -match $rule.Pattern) { $isAllowed = $true; break }
                    }
                    if (-not $isAllowed)
                    {
                        $violations += "$(Split-Path -Leaf $FilePath):${lineNumber}: '$($token.Value)' -- $($line.Trim())"
                    }
                }
            }
            return $violations
        }

        # Parse every update policy from the ingestion setup scripts:
        # ".alter table <target> policy update" followed by a fenced JSON array.
        $updatePolicies = @()
        foreach ($file in (Get-ChildItem -Path $scriptsPath -Filter 'IngestionSetup_v1_*.kql'))
        {
            $fileVersion = if ($file.Name -match '_v1_(\d+)') { [int]$Matches[1] } else { $null }
            $content = Get-Content -Path $file.FullName -Raw
            foreach ($match in [regex]::Matches($content, '(?ms)^\.alter table (?<target>\S+) policy update[ \t]*\r?\n```[ \t]*\r?\n(?<json>.*?)```'))
            {
                foreach ($policy in ($match.Groups['json'].Value | ConvertFrom-Json))
                {
                    $updatePolicies += @{
                        File      = $file.Name
                        Version   = $fileVersion
                        Target    = $match.Groups['target'].Value
                        Source    = $policy.Source
                        IsEnabled = $policy.IsEnabled
                    }
                }
            }
        }

        # Derive the current schema version instead of hardcoding it so this test survives v1_5.
        $currentSchemaVersion = ($updatePolicies | ForEach-Object { $_.Version } | Measure-Object -Maximum).Maximum
    }

    Context 'Registration completeness (D6 check 1)' {

        It 'Discovers versioned setup scripts via glob' {
            # Guard against a broken glob silently green-washing the -ForEach tests below.
            @(Get-ChildItem -Path $scriptsPath -Filter 'IngestionSetup_v1_*.kql').Count | Should -BeGreaterOrEqual 3
            @(Get-ChildItem -Path $scriptsPath -Filter 'HubSetup_v1_*.kql').Count | Should -BeGreaterOrEqual 3
        }

        It '<Name> is registered in .build.config combineKql' -ForEach $registeredSetupFiles {
            $combineKqlFiles | Should -Contain "modules/Microsoft.FinOpsHubs/Analytics/scripts/$Name" -Because "every setup script must ship in the Fabric KQL bundle (regression #1777: IngestionSetup_v1_2.kql was missing from .build.config)"
        }

        It '<Name> is loaded via loadTextContent in app.bicep' -ForEach $registeredSetupFiles {
            $appBicep | Should -Match ([regex]::Escape("loadTextContent('scripts/$Name')")) -Because "every setup script must be embedded in the Data Explorer deployment"
        }

        It 'Lists versioned HubSetup files before HubSetup_Latest.kql in .build.config' {
            $hubBundle = @($buildConfig.combineKql | Where-Object { $_.files -match 'HubSetup_Latest\.kql' })
            $hubBundle.Count | Should -Be 1
            $files = @($hubBundle[0].files)
            $latestIndex = $files.IndexOf('modules/Microsoft.FinOpsHubs/Analytics/scripts/HubSetup_Latest.kql')
            $latestIndex | Should -BeGreaterOrEqual 0
            foreach ($file in ($files -match 'HubSetup_v1_\d+\.kql$'))
            {
                $files.IndexOf($file) | Should -BeLessThan $latestIndex -Because "unversioned aliases in HubSetup_Latest.kql depend on the versioned functions being created first"
            }
        }
    }

    Context 'Version-string consistency (D6 check 2)' {

        It '<Name> only references other schema versions via allowlisted patterns' -ForEach $versionedSetupFiles {
            $violations = Get-CrossVersionViolation -FilePath $FullName -OwnVersion $Version
            ($violations -join "`n") | Should -BeNullOrEmpty -Because 'cross-version identifiers outside the allowlist are usually copy/paste defects from cloning the previous version file'
        }

        It 'Does not reference v1_3 anywhere in Analytics scripts' {
            # v1_3 was never a hub schema version; any reference is a typo or bad copy/paste.
            $violations = @()
            foreach ($file in (Get-ChildItem -Path $scriptsPath -Filter '*.kql'))
            {
                $lineNumber = 0
                foreach ($line in [System.IO.File]::ReadAllLines($file.FullName))
                {
                    $lineNumber++
                    if ($line -notmatch 'v1_3') { continue }
                    $isAllowed = $false
                    foreach ($rule in $crossVersionAllowlist)
                    {
                        if ($line -match $rule.Pattern) { $isAllowed = $true; break }
                    }
                    if (-not $isAllowed)
                    {
                        $violations += "$($file.Name):${lineNumber}: $($line.Trim())"
                    }
                }
            }
            ($violations -join "`n") | Should -BeNullOrEmpty
        }

        It 'Has no git conflict markers in finops-hub KQL or Bicep files' {
            $violations = @()
            foreach ($file in (Get-ChildItem -Path $hubRoot -Recurse -Include '*.kql', '*.bicep'))
            {
                $lineNumber = 0
                foreach ($line in [System.IO.File]::ReadAllLines($file.FullName))
                {
                    $lineNumber++
                    if ($line -match '^(<{7} |={7}$|>{7} )')
                    {
                        $violations += "$($file.Name):${lineNumber}: $($line.Trim())"
                    }
                }
            }
            ($violations -join "`n") | Should -BeNullOrEmpty -Because 'conflict markers have been committed to these files before; they break the ADX database script'
        }
    }

    Context 'Update policies: exactly one enabled schema version (D6 check 3)' {

        It 'Parses update policies from <Name>' -ForEach $ingestionSetupFiles {
            @($updatePolicies | Where-Object { $_.File -eq $Name }).Count | Should -BeGreaterThan 0 -Because 'every ingestion setup script defines update policies; zero parsed policies means the parser regex no longer matches the file format'
        }

        It 'Enables update policies in exactly one schema version (the current one)' {
            $enabledVersions = @($updatePolicies | Where-Object { $_.IsEnabled } | ForEach-Object { $_.Version } | Sort-Object -Unique)
            $enabledVersions | Should -Be @($currentSchemaVersion) -Because 'enabled update policies in more than one schema version cause double ingestion; older versions must be fully disabled when a new version ships'
        }

        It '<Name> has zero enabled update policies (superseded version)' -ForEach ($ingestionSetupFiles | Where-Object { [int]$_.Version -lt (@($ingestionSetupFiles | ForEach-Object { [int]$_.Version }) | Measure-Object -Maximum).Maximum }) {
            $enabled = @($updatePolicies | Where-Object { $_.File -eq $Name -and $_.IsEnabled })
            ($enabled | ForEach-Object { "$($_.Source) -> $($_.Target)" }) -join "`n" | Should -BeNullOrEmpty
        }

        It 'Every raw source table has an enabled update policy in the current schema version' {
            # Union of Source tables across all versions = every raw table that ever fed a transform.
            # Each must still be wired to the current version (counts are flexible: Costs_raw is fed by
            # ActualCosts_raw and AmortizedCosts_raw in addition to its own transform, per C360 support).
            $allSources = @($updatePolicies | ForEach-Object { $_.Source } | Sort-Object -Unique)
            $enabledSources = @($updatePolicies | Where-Object { $_.IsEnabled -and $_.Version -eq $currentSchemaVersion } | ForEach-Object { $_.Source } | Sort-Object -Unique)
            foreach ($source in $allSources)
            {
                $enabledSources | Should -Contain $source -Because "data ingested into $source would silently stop flowing without an enabled update policy in the current schema version"
            }
        }
    }

    Context 'FOCUS 1.4 columns in Costs_raw' {

        BeforeAll {
            # Extract just the Costs_raw alter block (not Costs_final or any other table).
            $script:costsRawBlock = if ($rawTablesContent -match '(?ms)\.alter table Costs_raw \(\r?\n(.*?)\r?\n\)') { $Matches[1] } else { '' }
        }

        It 'Costs_raw block was extracted' {
            $costsRawBlock | Should -Not -BeNullOrEmpty
        }

        It 'Adds <_> to Costs_raw' -ForEach @(
            'AllocatedMethodId', 'AllocatedMethodDetails', 'AllocatedResourceId',
            'AllocatedResourceName', 'AllocatedTags', 'ContractApplied',
            'ServiceProviderName', 'HostProviderName',
            'CommitmentProgramEligibilityDetails', 'InvoiceDetailId',
            'ContractCommitmentBenefitCategory', 'ContractCommitmentCreated',
            'ContractCommitmentDiscountPercentage', 'ContractCommitmentDurationType',
            'ContractCommitmentFulfillmentInterval', 'ContractCommitmentLastUpdated',
            'ContractCommitmentLifecycleStatus', 'ContractCommitmentModel',
            'ContractCommitmentOfferCategory', 'ContractCommitmentPaymentInterval',
            'ContractCommitmentPaymentModel', 'ContractCommitmentPaymentUpfrontPercentage'
        ) {
            $costsRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }

        It 'Keeps deprecated <_> for back compat' -ForEach @(
            'ProviderName', 'PublisherName', 'Region'
        ) {
            $costsRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }
    }

    Context 'ContractCommitments_raw exists with all FOCUS 1.4 columns' {

        BeforeAll {
            # The Redefine-all-columns alter-table block is the second occurrence; match all and pick it.
            $allBlocks = [regex]::Matches($rawTablesContent, '(?ms)\.alter table ContractCommitments_raw \(\r?\n(.*?)\r?\n\)')
            $script:contractCommitmentsRawBlock = if ($allBlocks.Count -ge 1) { $allBlocks[$allBlocks.Count - 1].Groups[1].Value } else { '' }
        }

        It 'Defines ContractCommitments_raw (plural)' {
            $rawTablesContent | Should -Match '\.alter table ContractCommitments_raw \('
        }

        It 'Does NOT define singular ContractCommitment_raw' {
            $rawTablesContent | Should -Not -Match '\.alter table ContractCommitment_raw \('
        }

        It 'ContractCommitments_raw column block was extracted' {
            $contractCommitmentsRawBlock | Should -Not -BeNullOrEmpty
        }

        It 'Includes base column <_>' -ForEach @(
            'BillingCurrency', 'ContractCommitmentCategory', 'ContractCommitmentCost',
            'ContractCommitmentDescription', 'ContractCommitmentId', 'ContractCommitmentPeriodEnd',
            'ContractCommitmentPeriodStart', 'ContractCommitmentQuantity', 'ContractCommitmentType',
            'ContractCommitmentUnit', 'ContractId', 'ContractPeriodEnd', 'ContractPeriodStart',
            'InvoiceIssuerName', 'PricingCurrency'
        ) {
            $contractCommitmentsRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }

        It 'Includes FOCUS 1.4 column <_>' -ForEach @(
            'ContractCommitmentApplicability', 'ContractCommitmentBenefitCategory',
            'ContractCommitmentCreated', 'ContractCommitmentDiscountPercentage',
            'ContractCommitmentDurationType', 'ContractCommitmentFulfillmentInterval',
            'ContractCommitmentLastUpdated', 'ContractCommitmentLifecycleStatus',
            'ContractCommitmentModel', 'ContractCommitmentOfferCategory',
            'ContractCommitmentPaymentInterval', 'ContractCommitmentPaymentModel',
            'ContractCommitmentPaymentUpfrontPercentage', 'PricingCurrencyContractCommitmentCost',
            'ServiceProviderName'
        ) {
            $contractCommitmentsRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }

        It 'Does NOT include unprefixed column <_>' -ForEach @(
            'BenefitCategory', 'Created', 'DiscountPercentage', 'DurationType',
            'FulfillmentInterval', 'LastUpdated', 'LifecycleStatus', 'Model', 'OfferCategory',
            'PaymentInterval', 'PaymentModel', 'PaymentUpfrontPercentage'
        ) {
            $contractCommitmentsRawBlock | Should -Not -Match "(?m)^\s+$_\s*:"
        }

        It 'Defines exactly 30 FOCUS columns' {
            ([regex]::Matches($contractCommitmentsRawBlock, '(?m)^\s+(?!x_)\w+\s*:')).Count | Should -Be 30
        }
    }

    Context 'BillingPeriods_raw exists with FOCUS 1.4 columns' {

        BeforeAll {
            $allBlocks = [regex]::Matches($rawTablesContent, '(?ms)\.alter table BillingPeriods_raw \(\r?\n(.*?)\r?\n\)')
            $script:billingPeriodsRawBlock = if ($allBlocks.Count -ge 1) { $allBlocks[$allBlocks.Count - 1].Groups[1].Value } else { '' }
        }

        It 'Defines BillingPeriods_raw' {
            $rawTablesContent | Should -Match '\.alter table BillingPeriods_raw \('
        }

        It 'Includes column <_>' -ForEach @(
            'BillingPeriodCreated', 'BillingPeriodEnd', 'BillingPeriodLastUpdated',
            'BillingPeriodStart', 'BillingPeriodStatus', 'InvoiceIssuerName'
        ) {
            $billingPeriodsRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }
    }

    Context 'InvoiceDetails_raw exists with FOCUS 1.4 columns' {

        BeforeAll {
            $allBlocks = [regex]::Matches($rawTablesContent, '(?ms)\.alter table InvoiceDetails_raw \(\r?\n(.*?)\r?\n\)')
            $script:invoiceDetailsRawBlock = if ($allBlocks.Count -ge 1) { $allBlocks[$allBlocks.Count - 1].Groups[1].Value } else { '' }
        }

        It 'Defines InvoiceDetails_raw' {
            $rawTablesContent | Should -Match '\.alter table InvoiceDetails_raw \('
        }

        It 'Includes column <_>' -ForEach @(
            'BilledCost', 'BillingAccountId', 'BillingCurrency', 'BillingPeriodEnd',
            'BillingPeriodStart', 'ChargeCategory', 'InvoiceDetailCreated', 'InvoiceDetailDescription',
            'InvoiceDetailGrain', 'InvoiceDetailId', 'InvoiceDetailLastUpdated', 'InvoiceId',
            'InvoiceIssueDate', 'InvoiceIssueStatus', 'InvoiceIssuerName', 'PaymentCurrency',
            'PaymentCurrencyBilledCost', 'PaymentCurrencyInvoiceDetailId', 'PaymentDueDate',
            'PaymentTerms', 'PurchaseOrderNumber', 'ReferenceInvoiceId'
        ) {
            $invoiceDetailsRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }
    }

    Context 'IngestionSetup v1_4 transforms and final tables' {

        BeforeAll {
            $script:costsFinalV14Block = if ($ingestionFiles.v1_4 -match '(?ms)\.create-merge table Costs_final_v1_4 \(\r?\n(.*?)\r?\n\)') { $Matches[1] } else { '' }
            $script:contractCommitmentsFinalV14Block = if ($ingestionFiles.v1_4 -match '(?ms)\.create-merge table ContractCommitments_final_v1_4 \(\r?\n(.*?)\r?\n\)') { $Matches[1] } else { '' }
        }

        It 'Defines <_>_transform_v1_4()' -ForEach @(
            'BillingPeriods', 'ContractCommitments', 'Costs', 'InvoiceDetails', 'Prices'
        ) {
            $ingestionFiles.v1_4 | Should -Match "$($_)_transform_v1_4\(\)"
        }

        It 'Defines <_>_final_v1_4 table' -ForEach @(
            'BillingPeriods', 'ContractCommitments', 'Costs', 'InvoiceDetails', 'Prices'
        ) {
            $ingestionFiles.v1_4 | Should -Match "\.create-merge table $($_)_final_v1_4"
        }

        It 'Does NOT define singular ContractCommitment_final_v1_4' {
            $ingestionFiles.v1_4 | Should -Not -Match '\.create-merge table ContractCommitment_final_v1_4'
        }

        It 'Costs_final_v1_4 block was extracted' {
            $costsFinalV14Block | Should -Not -BeNullOrEmpty
        }

        It 'Costs_final_v1_4 does NOT include removed <_>' -ForEach @(
            'ProviderName', 'PublisherName'
        ) {
            $costsFinalV14Block | Should -Not -Match "(?m)^\s+$_\s*:"
        }

        It 'Costs_final_v1_4 includes new FOCUS 1.4 column <_>' -ForEach @(
            'CommitmentProgramEligibilityDetails', 'InvoiceDetailId',
            'ContractCommitmentBenefitCategory', 'ContractCommitmentCreated',
            'ContractCommitmentDiscountPercentage', 'ContractCommitmentDurationType',
            'ContractCommitmentFulfillmentInterval', 'ContractCommitmentLastUpdated',
            'ContractCommitmentLifecycleStatus', 'ContractCommitmentModel',
            'ContractCommitmentOfferCategory', 'ContractCommitmentPaymentInterval',
            'ContractCommitmentPaymentModel', 'ContractCommitmentPaymentUpfrontPercentage'
        ) {
            $costsFinalV14Block | Should -Match "(?m)^\s+$_\s*:"
        }

        It 'ContractCommitments_final_v1_4 includes FOCUS 1.4 column <_>' -ForEach @(
            'ContractCommitmentApplicability', 'ContractCommitmentBenefitCategory',
            'ContractCommitmentCreated', 'ContractCommitmentDescription',
            'ContractCommitmentDiscountPercentage', 'ContractCommitmentDurationType',
            'ContractCommitmentFulfillmentInterval', 'ContractCommitmentLastUpdated',
            'ContractCommitmentLifecycleStatus', 'ContractCommitmentModel',
            'ContractCommitmentOfferCategory', 'ContractCommitmentPaymentInterval',
            'ContractCommitmentPaymentModel', 'ContractCommitmentPaymentUpfrontPercentage',
            'PricingCurrencyContractCommitmentCost', 'ServiceProviderName'
        ) {
            $contractCommitmentsFinalV14Block | Should -Match "(?m)^\s+$_\s*:"
        }

        It 'ContractCommitments_final_v1_4 defines exactly 30 FOCUS columns' {
            ([regex]::Matches($contractCommitmentsFinalV14Block, '(?m)^\s+(?!x_)\w+\s*:')).Count | Should -Be 30
        }
    }

    Context 'HubSetup_v1_4.kql' {

        It 'Defines <_>_v1_4()' -ForEach $allDatasets {
            $hubFiles.v1_4 | Should -Match "$($_)_v1_4\(\)"
        }

        It 'Does NOT define singular ContractCommitment_v1_4' {
            $hubFiles.v1_4 | Should -Not -Match 'ContractCommitment_v1_4\(\)'
        }

        It 'Unions <_> final tables from all three schema versions exactly once each' -ForEach $managedDatasets {
            foreach ($version in @('v1_0', 'v1_2', 'v1_4'))
            {
                [regex]::Matches($hubFiles.v1_4, "database\('Ingestion'\)\.$($_)_final_$version\b").Count | Should -Be 1 -Because "$_ data ingested under the $version schema must surface exactly once in the v1_4 hub function"
            }
        }

        It 'Reads <_> (new in FOCUS 1.4) from the v1_4 final table only' -ForEach $v14OnlyDatasets {
            [regex]::Matches($hubFiles.v1_4, "database\('Ingestion'\)\.$($_)_final_v1_4\b").Count | Should -Be 1
            $hubFiles.v1_4 | Should -Not -Match "$($_)_final_v1_0"
            $hubFiles.v1_4 | Should -Not -Match "$($_)_final_v1_2"
        }
    }

    Context 'HubSetup_v1_0.kql / HubSetup_v1_2.kql back-compat arms' {

        It 'HubSetup_v1_0.kql unions <_>_final_v1_4 (down-converted for old reports)' -ForEach $managedDatasets {
            [regex]::Matches($hubFiles.v1_0, "database\('Ingestion'\)\.$($_)_final_v1_4\b").Count | Should -Be 1 -Because "data ingested under the v1_4 schema must remain visible to consumers still on the v1_0 functions"
        }

        It 'HubSetup_v1_2.kql unions <_>_final_v1_4 (down-converted for old reports)' -ForEach $managedDatasets {
            [regex]::Matches($hubFiles.v1_2, "database\('Ingestion'\)\.$($_)_final_v1_4\b").Count | Should -Be 1 -Because "data ingested under the v1_4 schema must remain visible to consumers still on the v1_2 functions"
        }
    }

    Context 'Provider column rename round trip (D3)' {

        # FOCUS 1.3 renamed ProviderName -> HostProviderName and repurposed PublisherName ->
        # ServiceProviderName. Down-conversion (v1_4 data through v1_0/v1_2 functions) must map back:
        # ProviderName = HostProviderName, PublisherName = ServiceProviderName.
        It 'HubSetup_<Key>.kql down-converts the provider columns in its v1_4 arm' -ForEach @(
            @{ Key = 'v1_0' }
            @{ Key = 'v1_2' }
        ) {
            $hubFiles[$Key] | Should -Match 'ProviderName\s*=\s*HostProviderName' -Because 'the deprecated ProviderName maps back from HostProviderName'
            $hubFiles[$Key] | Should -Match 'PublisherName\s*=\s*ServiceProviderName' -Because 'the deprecated PublisherName maps back from ServiceProviderName'
        }

        # The inverse guard is scoped to DIRECT single assignments (HostProviderName = PublisherName /
        # ServiceProviderName = ProviderName) because the up-conversion in IngestionSetup_v1_4.kql and
        # HubSetup_v1_4.kql legitimately uses the deprecated ProviderName as a *later fallback* inside
        # case()/iff() expressions when deriving ServiceProviderName. A direct assignment is only ever
        # the swapped-mapping defect this test exists to catch (PR #2126 review finding C1).
        It '<Name> does not invert the provider column mapping' -ForEach $v14SetupFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Not -Match '(?<![\w.])HostProviderName\s*=\s*PublisherName\b'
            $content | Should -Not -Match '(?<![\w.])ServiceProviderName\s*=\s*ProviderName\b'
        }
    }

    Context 'Recommendations taxonomy (W9)' {

        BeforeDiscovery {
            $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
            $recommendationQueriesPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/queries'
            # AdvisorCost passes Azure Advisor's per-row category through and has no single subcategory;
            # every other hub-native query targets one recommendation type and must declare one.
            $recommendationQueryFiles = @(Get-ChildItem -Path $recommendationQueriesPath -Filter 'Recommendations-*.json' |
                    Where-Object { $_.Name -ne 'Recommendations-Microsoft-AdvisorCost.json' } |
                    ForEach-Object { @{ Name = $_.Name; FullName = $_.FullName } })
        }

        BeforeAll {
            $script:recommendationsTransformV14 = if ($ingestionFiles.v1_4 -match '(?ms)Recommendations_transform_v1_4\(\)\s*\{(.*?)\n\}') { $Matches[1] } else { '' }
            $script:recommendationsFinalV14Block = if ($ingestionFiles.v1_4 -match '(?ms)\.create-merge table Recommendations_final_v1_4 \(\r?\n(.*?)\r?\n\)') { $Matches[1] } else { '' }

            # Canonical (subcategory -> parent category) taxonomy. This is the test's source of truth;
            # the KQL datatable and the data-model.md docs are both validated against it.
            $script:canonicalTaxonomy = [ordered]@{
                # Cost
                'Autoscaling'                        = 'Cost'
                'Commitment Discount Coverage'       = 'Cost'
                'Commitment Discount Utilization'    = 'Cost'
                'Idle Resources'                     = 'Cost'
                'License Optimization'               = 'Cost'
                'Low Utilization'                    = 'Cost'
                'Negotiated Discounts'               = 'Cost'
                'Region Placement'                   = 'Cost'
                'Right-Sizing'                       = 'Cost'
                'Scheduling'                         = 'Cost'
                'Service Selection and Architecture' = 'Cost'
                'SKU Modernization'                  = 'Cost'
                'Spot Eligibility'                   = 'Cost'
                'Storage Tiering'                    = 'Cost'
                # Operational Excellence
                'Automation and Process'             = 'Operational Excellence'
                'Best Practices'                     = 'Operational Excellence'
                'Governance and Policy'              = 'Operational Excellence'
                'Observability'                      = 'Operational Excellence'
                'Operational Hygiene'                = 'Operational Excellence'
                'Quotas and Limits'                  = 'Operational Excellence'
                'Resource Consistency'               = 'Operational Excellence'
                # Performance
                'Performance Tuning'                 = 'Performance'
                'Resource Configuration'             = 'Performance'
                'Resource Sizing'                    = 'Performance'
                'Scaling and Capacity'               = 'Performance'
                'Throughput and Latency'             = 'Performance'
                'Workload Placement'                 = 'Performance'
                # Reliability
                'Backup Configuration'               = 'Reliability'
                'Capacity'                           = 'Reliability'
                'Disaster Recovery'                  = 'Reliability'
                'High Availability'                  = 'Reliability'
                'Service Retirement'                 = 'Reliability'
                'Zone Resiliency'                    = 'Reliability'
                # Security
                'Compliance Alignment'               = 'Security'
                'Data Protection'                    = 'Security'
                'Identity and Access'                = 'Security'
                'Network Security'                   = 'Security'
                'Threat Detection'                   = 'Security'
                'Vulnerability Exposure'             = 'Security'
            }

            # Parse the (subcategory, parent) pairs out of the SubcategoryTaxonomy datatable in the transform.
            $script:kqlTaxonomy = [ordered]@{}
            $datatableBlock = if ($recommendationsTransformV14 -match "(?ms)let SubcategoryTaxonomy = datatable[^\[]+\[(.*?)\];") { $Matches[1] } else { '' }
            foreach ($pair in [regex]::Matches($datatableBlock, "(?m)^\s*'([^']+)',\s*'([^']+)',?\s*$"))
            {
                $kqlTaxonomy[$pair.Groups[1].Value] = $pair.Groups[2].Value
            }

            $script:dataModelContent = Get-Content -Path (Join-Path $repoRoot 'docs-mslearn/toolkit/hubs/data-model.md') -Raw
        }

        It 'Recommendations_transform_v1_4 block was extracted' {
            $recommendationsTransformV14 | Should -Not -BeNullOrEmpty
        }

        It 'Recommendations_final_v1_4 block was extracted' {
            $recommendationsFinalV14Block | Should -Not -BeNullOrEmpty
        }

        It 'Recommendations_final_v1_4 includes column <_>' -ForEach @(
            'x_RecommendationCategory', 'x_RecommendationSubcategory'
        ) {
            $recommendationsFinalV14Block | Should -Match "(?m)^\s+$_\s*:"
        }

        It 'Recommendations_transform_v1_4 projects <_>' -ForEach @(
            'x_RecommendationCategory', 'x_RecommendationSubcategory'
        ) {
            $recommendationsTransformV14 | Should -Match "(?m)^\s+$_\s*,?\s*(//.*)?$"
        }

        It 'Recommendations_v1_4 hub function projects <_>' -ForEach @(
            'x_RecommendationCategory', 'x_RecommendationSubcategory'
        ) {
            $recommendationsV14Block = if ($hubFiles.v1_4 -match '(?ms)Recommendations_v1_4\(\)\s*\{(.*?)\n\}') { $Matches[1] } else { '' }
            $recommendationsV14Block | Should -Match "(?m)^\s+$_\s*,?\s*$"
        }

        It 'Recommendations_transform_v1_4 normalizes category to <_>' -ForEach @(
            "'Cost'", "'Operational Excellence'", "'Performance'", "'Reliability'", "'Security'"
        ) {
            $recommendationsTransformV14 | Should -Match ([regex]::Escape($_))
        }

        It 'Recommendations_transform_v1_4 maps Advisor HighAvailability to Reliability' {
            $recommendationsTransformV14 | Should -Match "x_RecommendationCategory =~ 'HighAvailability', 'Reliability'"
        }

        It 'SubcategoryTaxonomy datatable matches the canonical taxonomy exactly' {
            $kqlTaxonomy.Count | Should -Be $canonicalTaxonomy.Count -Because 'the KQL datatable and the canonical taxonomy must not drift'
            foreach ($subcategory in $canonicalTaxonomy.Keys)
            {
                $kqlTaxonomy[$subcategory] | Should -Be $canonicalTaxonomy[$subcategory] -Because "subcategory '$subcategory' must map to '$($canonicalTaxonomy[$subcategory])' in the SubcategoryTaxonomy datatable"
            }
        }

        It 'data-model.md documents every canonical subcategory' {
            foreach ($subcategory in $canonicalTaxonomy.Keys)
            {
                $dataModelContent | Should -Match ([regex]::Escape($subcategory)) -Because "docs must list canonical subcategory '$subcategory'"
            }
        }

        It 'Backfills an unknown category from the subcategory parent (coherence rule)' {
            # An empty category with a valid subcategory must resolve to the subcategory's parent so a
            # specific subcategory can never pair with an unclassified category.
            $recommendationsTransformV14 | Should -Match "(?m)^\s*isnotempty\(tmp_SubcategoryParent\),\s*tmp_SubcategoryParent,"
        }

        It 'Only passes a subcategory through when its parent matches the resolved category (coherence rule)' {
            $recommendationsTransformV14 | Should -Match ([regex]::Escape("tmp_SubcategoryParent == x_RecommendationCategory"))
        }

        It 'Defaults both columns to Other when unmapped' {
            # Category fallback: the backfill case ends with 'Other'.
            $recommendationsTransformV14 | Should -Match "(?ms)x_RecommendationCategory = case\((?:(?!\)\r?\n).)*'Other'\r?\n\s*\)"
            # Subcategory fallback: the subcategory case ends with 'Other'.
            $recommendationsTransformV14 | Should -Match "(?ms)x_RecommendationSubcategory = case\((?:(?!\)\r?\n).)*'Other'\r?\n\s*\)"
        }

        It 'Defaults reservation recommendations to Commitment Discount Coverage' {
            $recommendationsTransformV14 | Should -Match ([regex]::Escape("x_SourceType == 'ReservationRecommendations', 'Commitment Discount Coverage'"))
        }

        It '<Name> declares a canonical Cost subcategory' -ForEach $recommendationQueryFiles {
            $query = (Get-Content -Path $FullName -Raw | ConvertFrom-Json).query
            $query -match "'x_RecommendationSubcategory',\s*'([^']+)'" | Should -BeTrue -Because 'every hub-native recommendation query must declare a subcategory in x_RecommendationDetails'
            $subcategory = $Matches[1]
            $canonicalTaxonomy.Keys | Should -Contain $subcategory -Because "subcategory '$subcategory' in '$Name' must be a canonical taxonomy value"
            $canonicalTaxonomy[$subcategory] | Should -Be 'Cost' -Because "hub-native queries hardcode x_RecommendationCategory='Cost', so the declared subcategory must be a Cost subcategory or ingestion will coerce it to 'Other'"
        }
    }

    Context 'HubSetup_Latest.kql aliases' {

        It 'Aliases <_>() to <_>_v1_4() (latest GA)' -ForEach $allDatasets {
            $hubFiles.Latest | Should -Match "(?ms)$($_)\(\)\s*\{\s*$($_)_v1_4\(\)\s*\}"
        }

        It 'Does NOT alias to singular ContractCommitment' {
            $hubFiles.Latest | Should -Not -Match '(?m)^ContractCommitment\(\)'
        }

        It 'Does NOT alias to v1_2 or older' {
            $hubFiles.Latest | Should -Not -Match '_v1_2\(\)'
            $hubFiles.Latest | Should -Not -Match '_v1_0\(\)'
        }

        It 'Points all 8 unversioned functions at _v1_4()' {
            [regex]::Matches($hubFiles.Latest, '_v1_4\(\)').Count | Should -Be 8 -Because 'every unversioned dataset function aliases exactly one _v1_4 function'
        }
    }
}
