# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'HubsFocusSchemas' {

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scriptsPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $rawTablesContent = Get-Content -Path (Join-Path $scriptsPath 'IngestionSetup_RawTables.kql') -Raw

        $ingestionFiles = @{
            v1_0 = Get-Content -Path (Join-Path $scriptsPath 'IngestionSetup_v1_0.kql') -Raw
            v1_2 = Get-Content -Path (Join-Path $scriptsPath 'IngestionSetup_v1_2.kql') -Raw
            v1_4 = Get-Content -Path (Join-Path $scriptsPath 'IngestionSetup_v1_4.kql') -Raw
        }

        $hubFiles = @{
            v1_0   = Get-Content -Path (Join-Path $scriptsPath 'HubSetup_v1_0.kql') -Raw
            v1_2   = Get-Content -Path (Join-Path $scriptsPath 'HubSetup_v1_2.kql') -Raw
            v1_4   = Get-Content -Path (Join-Path $scriptsPath 'HubSetup_v1_4.kql') -Raw
            Latest = Get-Content -Path (Join-Path $scriptsPath 'HubSetup_Latest.kql') -Raw
        }

        $appBicep = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/app.bicep') -Raw
        $buildConfig = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/.build.config') -Raw
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
            'ServiceProviderName', 'HostProviderName'
        ) {
            $costsRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }
    }

    Context 'ContractCommitment_raw exists with all FOCUS 1.4 columns' {

        BeforeAll {
            # The Redefine-all-columns alter-table block is the second occurrence; match all and pick it.
            $allBlocks = [regex]::Matches($rawTablesContent, '(?ms)\.alter table ContractCommitment_raw \(\r?\n(.*?)\r?\n\)')
            $script:contractCommitmentRawBlock = if ($allBlocks.Count -ge 1) { $allBlocks[$allBlocks.Count - 1].Groups[1].Value } else { '' }
        }

        It 'Defines ContractCommitment_raw' {
            $rawTablesContent | Should -Match '\.alter table ContractCommitment_raw \('
        }

        It 'ContractCommitment_raw column block was extracted' {
            $contractCommitmentRawBlock | Should -Not -BeNullOrEmpty
        }

        It 'Includes base column <_>' -ForEach @(
            'BillingCurrency', 'ContractCommitmentCategory', 'ContractCommitmentCost',
            'ContractCommitmentId', 'ContractCommitmentPeriodEnd', 'ContractCommitmentPeriodStart',
            'ContractCommitmentQuantity', 'ContractCommitmentType', 'ContractCommitmentUnit',
            'ContractId', 'ContractPeriodEnd', 'ContractPeriodStart', 'InvoiceIssuerName',
            'PricingCurrency'
        ) {
            $contractCommitmentRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }

        It 'Includes FOCUS 1.4 column <_>' -ForEach @(
            'BenefitCategory', 'ContractCommitmentApplicability', 'Created',
            'DiscountPercentage', 'DurationType', 'FulfillmentInterval', 'LastUpdated',
            'LifecycleStatus', 'Model', 'OfferCategory', 'PaymentInterval', 'PaymentModel',
            'PaymentUpfrontPercentage', 'PricingCurrencyContractCommitmentCost'
        ) {
            $contractCommitmentRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }
    }

    Context 'IngestionSetup_v1_4.kql' {

        BeforeAll {
            $script:costsFinalV14Block = if ($ingestionFiles.v1_4 -match '(?ms)\.create-merge table Costs_final_v1_4 \(\r?\n(.*?)\r?\n\)') { $Matches[1] } else { '' }
            $script:contractCommitmentFinalV14Block = if ($ingestionFiles.v1_4 -match '(?ms)\.create-merge table ContractCommitment_final_v1_4 \(\r?\n(.*?)\r?\n\)') { $Matches[1] } else { '' }
        }

        It 'Defines Costs_transform_v1_4' {
            $ingestionFiles.v1_4 | Should -Match 'Costs_transform_v1_4\(\)'
        }

        It 'Defines Costs_final_v1_4 table' {
            $ingestionFiles.v1_4 | Should -Match '\.create-merge table Costs_final_v1_4'
        }

        It 'Defines ContractCommitment_transform_v1_4' {
            $ingestionFiles.v1_4 | Should -Match 'ContractCommitment_transform_v1_4\(\)'
        }

        It 'Defines ContractCommitment_final_v1_4 table' {
            $ingestionFiles.v1_4 | Should -Match '\.create-merge table ContractCommitment_final_v1_4'
        }

        It 'Costs_final_v1_4 block was extracted' {
            $costsFinalV14Block | Should -Not -BeNullOrEmpty
        }

        It 'Costs_final_v1_4 does NOT include deprecated <_> (removed in FOCUS 1.4)' -ForEach @(
            'ProviderName', 'PublisherName'
        ) {
            $costsFinalV14Block | Should -Not -Match "(?m)^\s+$_\s*:"
        }

        It 'ContractCommitment_final_v1_4 includes FOCUS 1.4 column <_>' -ForEach @(
            'BenefitCategory', 'ContractCommitmentApplicability', 'Created',
            'DiscountPercentage', 'DurationType', 'FulfillmentInterval', 'LastUpdated',
            'LifecycleStatus', 'Model', 'OfferCategory', 'PaymentInterval', 'PaymentModel',
            'PaymentUpfrontPercentage', 'PricingCurrencyContractCommitmentCost'
        ) {
            $contractCommitmentFinalV14Block | Should -Match "(?m)^\s+$_\s*:"
        }
    }

    Context 'HubSetup_v1_4.kql' {

        It 'Defines <_>' -ForEach @(
            'CommitmentDiscountUsage_v1_4', 'ContractCommitment_v1_4',
            'Costs_v1_4', 'Prices_v1_4', 'Recommendations_v1_4', 'Transactions_v1_4'
        ) {
            $hubFiles.v1_4 | Should -Match "$_\(\)"
        }

        It 'Costs_v1_4 unions all prior versions' -ForEach @(
            'Costs_final_v1_0', 'Costs_final_v1_2', 'Costs_final_v1_4'
        ) {
            $hubFiles.v1_4 | Should -Match "database\('Ingestion'\)\.$_"
        }
    }

    Context 'HubSetup_Latest.kql aliases' {

        It 'Aliases <_> to v1_4 (latest GA)' -ForEach @(
            'CommitmentDiscountUsage', 'ContractCommitment', 'Costs', 'Prices', 'Recommendations', 'Transactions'
        ) {
            $hubFiles.Latest | Should -Match "(?ms)$_\(\)\s*\{\s*${_}_v1_4\(\)\s*\}"
        }

        It 'Does NOT alias to v1_2 or older' {
            $hubFiles.Latest | Should -Not -Match '_v1_2\(\)'
        }
    }

    Context 'Bicep wiring' {

        It 'app.bicep loads <_>' -ForEach @(
            'IngestionSetup_v1_4.kql', 'HubSetup_v1_4.kql'
        ) {
            $appBicep | Should -Match ([regex]::Escape($_))
        }

        It '.build.config lists <_>' -ForEach @(
            'IngestionSetup_v1_4.kql', 'HubSetup_v1_4.kql'
        ) {
            $buildConfig | Should -Match ([regex]::Escape($_))
        }
    }
}
