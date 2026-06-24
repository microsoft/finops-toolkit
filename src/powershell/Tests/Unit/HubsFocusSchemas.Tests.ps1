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
            'ContractCommitmentId', 'ContractCommitmentPeriodEnd', 'ContractCommitmentPeriodStart',
            'ContractCommitmentQuantity', 'ContractCommitmentType', 'ContractCommitmentUnit',
            'ContractId', 'ContractPeriodEnd', 'ContractPeriodStart', 'InvoiceIssuerName',
            'PricingCurrency'
        ) {
            $contractCommitmentsRawBlock | Should -Match "(?m)^\s+$_\s*:"
        }

        It 'Includes FOCUS 1.4 column <_>' -ForEach @(
            'BenefitCategory', 'ContractCommitmentApplicability', 'Created',
            'DiscountPercentage', 'DurationType', 'FulfillmentInterval', 'LastUpdated',
            'LifecycleStatus', 'Model', 'OfferCategory', 'PaymentInterval', 'PaymentModel',
            'PaymentUpfrontPercentage', 'PricingCurrencyContractCommitmentCost'
        ) {
            $contractCommitmentsRawBlock | Should -Match "(?m)^\s+$_\s*:"
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

    Context 'IngestionSetup_v1_4.kql' {

        BeforeAll {
            $script:costsFinalV14Block = if ($ingestionFiles.v1_4 -match '(?ms)\.create-merge table Costs_final_v1_4 \(\r?\n(.*?)\r?\n\)') { $Matches[1] } else { '' }
            $script:contractCommitmentsFinalV14Block = if ($ingestionFiles.v1_4 -match '(?ms)\.create-merge table ContractCommitments_final_v1_4 \(\r?\n(.*?)\r?\n\)') { $Matches[1] } else { '' }
        }

        It 'Defines Costs_transform_v1_4' {
            $ingestionFiles.v1_4 | Should -Match 'Costs_transform_v1_4\(\)'
        }

        It 'Defines Costs_final_v1_4 table' {
            $ingestionFiles.v1_4 | Should -Match '\.create-merge table Costs_final_v1_4'
        }

        It 'Defines ContractCommitments_transform_v1_4 (plural)' {
            $ingestionFiles.v1_4 | Should -Match 'ContractCommitments_transform_v1_4\(\)'
        }

        It 'Defines ContractCommitments_final_v1_4 table (plural)' {
            $ingestionFiles.v1_4 | Should -Match '\.create-merge table ContractCommitments_final_v1_4'
        }

        It 'Defines BillingPeriods_transform_v1_4' {
            $ingestionFiles.v1_4 | Should -Match 'BillingPeriods_transform_v1_4\(\)'
        }

        It 'Defines BillingPeriods_final_v1_4 table' {
            $ingestionFiles.v1_4 | Should -Match '\.create-merge table BillingPeriods_final_v1_4'
        }

        It 'Defines InvoiceDetails_transform_v1_4' {
            $ingestionFiles.v1_4 | Should -Match 'InvoiceDetails_transform_v1_4\(\)'
        }

        It 'Defines InvoiceDetails_final_v1_4 table' {
            $ingestionFiles.v1_4 | Should -Match '\.create-merge table InvoiceDetails_final_v1_4'
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
            'BenefitCategory', 'ContractCommitmentApplicability', 'Created',
            'DiscountPercentage', 'DurationType', 'FulfillmentInterval', 'LastUpdated',
            'LifecycleStatus', 'Model', 'OfferCategory', 'PaymentInterval', 'PaymentModel',
            'PaymentUpfrontPercentage', 'PricingCurrencyContractCommitmentCost'
        ) {
            $contractCommitmentsFinalV14Block | Should -Match "(?m)^\s+$_\s*:"
        }
    }

    Context 'HubSetup_v1_4.kql' {

        It 'Defines <_>' -ForEach @(
            'BillingPeriods_v1_4', 'CommitmentDiscountUsage_v1_4', 'ContractCommitments_v1_4',
            'Costs_v1_4', 'InvoiceDetails_v1_4', 'Prices_v1_4', 'Recommendations_v1_4', 'Transactions_v1_4'
        ) {
            $hubFiles.v1_4 | Should -Match "$_\(\)"
        }

        It 'Does NOT define singular ContractCommitment_v1_4' {
            $hubFiles.v1_4 | Should -Not -Match 'ContractCommitment_v1_4\(\)'
        }

        It 'Costs_v1_4 unions all prior versions' -ForEach @(
            'Costs_final_v1_0', 'Costs_final_v1_2', 'Costs_final_v1_4'
        ) {
            $hubFiles.v1_4 | Should -Match "database\('Ingestion'\)\.$_"
        }

        It 'Recommendations_v1_4 projects <_>' -ForEach @(
            'x_RecommendationCategory', 'x_RecommendationSubcategory'
        ) {
            $script:recommendationsV14Block = if ($hubFiles.v1_4 -match '(?ms)Recommendations_v1_4\(\)\s*\{(.*?)\n\}') { $Matches[1] } else { '' }
            $recommendationsV14Block | Should -Match "(?m)^\s+$_\s*,?\s*$"
        }
    }

    Context 'Recommendations enrichment in IngestionSetup_v1_4.kql' {

        BeforeAll {
            $script:recommendationsTransformV14 = if ($ingestionFiles.v1_4 -match '(?ms)Recommendations_transform_v1_4\(\)\s*\{(.*?)\n\}') { $Matches[1] } else { '' }
            $script:recommendationsFinalV14Block = if ($ingestionFiles.v1_4 -match '(?ms)\.create-merge table Recommendations_final_v1_4 \(\r?\n(.*?)\r?\n\)') { $Matches[1] } else { '' }
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

        It 'Recommendations_transform_v1_4 normalizes category to <_>' -ForEach @(
            "'Cost'", "'Operational Excellence'", "'Performance'", "'Reliability'", "'Security'"
        ) {
            $recommendationsTransformV14 | Should -Match ([regex]::Escape($_))
        }

        It 'Recommendations_transform_v1_4 maps Advisor HighAvailability to Reliability' {
            $recommendationsTransformV14 | Should -Match "HighAvailability"
            $recommendationsTransformV14 | Should -Match "'Reliability'"
        }

        It 'Recommendations_transform_v1_4 falls back subcategory to Other' {
            $recommendationsTransformV14 | Should -Match "'Other'"
        }
    }

    Context 'HubSetup_Latest.kql aliases' {

        It 'Aliases <_> to v1_4 (latest GA)' -ForEach @(
            'BillingPeriods', 'CommitmentDiscountUsage', 'ContractCommitments',
            'Costs', 'InvoiceDetails', 'Prices', 'Recommendations', 'Transactions'
        ) {
            $hubFiles.Latest | Should -Match "(?ms)$_\(\)\s*\{\s*${_}_v1_4\(\)\s*\}"
        }

        It 'Does NOT alias to singular ContractCommitment' {
            $hubFiles.Latest | Should -Not -Match '(?m)^ContractCommitment\(\)'
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
