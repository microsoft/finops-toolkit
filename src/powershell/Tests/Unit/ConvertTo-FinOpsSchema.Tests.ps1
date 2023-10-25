# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName "$PSScriptRoot/../../FinOpsToolkit.psm1"

InModuleScope 'FinOpsToolkit' {
    BeforeAll {
        function Get-MockCostDetails {
            return @(
                @{
                    # EA actual cost row
                    BillingAccountId       = "8611537"
                    BillingAccountName     = "Billing Account"
                    BillingPeriodStartDate = "09/01/2023"
                    _BillingPeriodStart    = Get-Date "2023-09-01Z" -AsUTC
                    BillingPeriodEndDate   = "09/30/2023"
                    _BillingPeriodEnd      = Get-Date "2023-10-01Z" -AsUTC
                    BillingProfileId       = "8611537"
                    BillingProfileName     = "Billing Account"
                    AccountOwnerId         = "ftk@treyresearch.com"
                    AccountName            = "FTK Test"
                    SubscriptionId         = [Guid]::NewGuid()
                    SubscriptionName       = "Subscription Name"
                    Date                   = "09/04/2023"
                    _ChargePeriodEnd       = Get-Date "2023-09-05Z" -AsUTC
                    _ChargePeriodStart     = Get-Date "2023-09-04Z" -AsUTC
                    Product                = "Tiered Block Blob - GRS - List and Create Container Operations - US East 2"
                    PartNumber             = "AAD-37090"
                    MeterId                = "aaaef613-418a-4a5f-af72-d224d7dee2c6"
                    ServiceFamily          = "Storage"
                    MeterCategory          = "Storage"
                    MeterSubCategory       = "Tiered Block Blob"
                    MeterRegion            = "Virginia"
                    MeterName              = "GRS List and Create Container Operations"
                    Quantity               = "0.0004"
                    EffectivePrice         = "0.1"
                    Cost                   = "0.00004"
                    UnitPrice              = "0.1"
                    BillingCurrency        = "USD"
                    ResourceLocation       = "EastUS2"
                    AvailabilityZone       = "Availability Zone"
                    ConsumedService        = "Microsoft.Storage"
                    ResourceId             = "/subscriptions/ed570627-0265-4620-bb42-bae06bcfa914/resourceGroups/databricks-rg-PeskyData-s6taefbli5c5e/providers/Microsoft.Storage/storageAccounts/dbstoragewp6hglwvvrad2"
                    _ServiceName           = "Storage"
                    _ServiceCategory       = "Storage"
                    _PublisherName         = "Microsoft"
                    _PublisherType         = "Cloud Provider"
                    ResourceName           = "dbstoragewp6hglwvvrad2"
                    ServiceInfo1           = "Service Info 1"
                    ServiceInfo2           = "Service Info 2"
                    AdditionalInfo         = "{""Additional"":""Info""}"
                    Tags                   = '"CostCenter":"1234","env":"prod","org":"trey","application":"databricks","databricks-environment":"true"'
                    InvoiceSectionId       = "Invoice Section Id"
                    InvoiceSection         = "ACM"
                    CostCenter             = "ACM9000"
                    UnitOfMeasure          = "10K"
                    ResourceGroup          = "databricks-rg-PeskyData-s6taefbli5c5e"
                    ReservationId          = ""
                    ReservationName        = ""
                    ProductOrderId         = "Product Order Id"
                    ProductOrderName       = "Product Order Name"
                    OfferId                = "Offer Id"
                    IsAzureCreditEligible  = "true"
                    Term                   = "Term"
                    PublisherName          = "Microsoft"
                    PlanName               = "Hot"
                    ChargeType             = "Usage"
                    _ChargeType            = "Usage"
                    Frequency              = "UsageBased"
                    PublisherType          = "Azure"
                    PayGPrice              = "0.1"
                    PricingModel           = "OnDemand"
                    CostAllocationRuleName = "Cost Allocation Rule Name"
                    benefitId              = ""
                    benefitName            = ""
                }
            )
        }

        function Run-Test($actual, $amortized) {
            ConvertTo-FinOpsSchema -ActualCost $actual -AmortizedCost $amortized
        }
    }

    Describe 'ConvertTo-FinOpsSchema' {
        Context 'Parameter validation' {
            BeforeAll {
                Mock Write-Error { }
                Mock Write-Warning { }
            }
            BeforeEach {
                $data = @(Get-MockCostDetails)
                
                $commitmentPurchase = @(Get-MockCostDetails)
                $commitmentPurchase[0].ChargeType = 'Purchase'
                $commitmentPurchase[0].PricingModel = 'Reservation'
                
                $commitmentUsage = @(Get-MockCostDetails)
                $commitmentUsage[0].ChargeType = 'Usage'
                $commitmentUsage[0].PricingModel = 'SavingsPlan'
            }
            It 'Should error when ActualCost and AmortizedCost are empty' {
                # Arrange
                # Act
                $result = Run-Test @() @()
                
                # Assert
                Should -Invoke -CommandName Write-Error -Exactly -Times 1
                $result | Should -BeNullOrEmpty
            }
            It 'Should warn when ActualCost is empty' {
                # Arrange
                # Act
                $result = Run-Test @() $data
                
                # Assert
                Should -Invoke -CommandName Write-Warning -Exactly -Times 1
                @($result).Count | Should -Be $data.Count
            }
            It 'Should warn when AmortizedCost is empty' {
                # Arrange
                # Act
                $result = Run-Test $data @()
                
                # Assert
                Should -Invoke -CommandName Write-Warning -Exactly -Times 1
                @($result).Count | Should -Be $data.Count
            }
            It 'Should error when ActualCost has commitment usage' {
                # Arrange
                # Act
                $result = Run-Test @($commitmentUsage) @($data)
                
                # Assert
                Should -Invoke -CommandName Write-Error -Exactly -Times 1
                @($result).Count | Should -Be ($data.Count + $commitmentUsage.Count)
            }
            It 'Should error when AmortizedCost has commitment purchases' {
                # Arrange
                # Act
                $result = Run-Test @($data) @($commitmentPurchase)
                
                # Assert
                Should -Invoke -CommandName Write-Error -Exactly -Times 1
                @($result).Count | Should -Be ($data.Count + $commitmentPurchase.Count)
            }
            AfterEach {
                $data = $null
            }
        }

        Context 'Metadata columns' -Skip {
            # TODO: Add tests for DataSet, SchemaVersion, and AccountType
        }

        Context 'FOCUS 0.5 columns' {
            BeforeAll {
                $data = @(Get-MockCostDetails)
            }
            It 'Should have all 0.5 columns' {
                # Arrange
                $expectedService = Get-FinOpsService -ConsumedService $data.ConsumedService -ResourceType (Split-AzureResourceId $data.ResourceId).Type

                # Act
                $result = Run-Test $data $data | Select-Object -First 1
                
                # Assert
                $result.AmortizedCost      | Should -Be ($data.Cost ?? $data.CostInBillingCurrency -as [double])
                $result.AvailabilityZone   | Should -Be $data.AvailabilityZone
                $result.BilledCost         | Should -Be ($data.Cost ?? $data.CostInBillingCurrency -as [double])
                $result.BillingAccountId   | Should -Be "/providers/Microsoft.Billing/billingAccounts/$($data.BillingAccountId)"
                $result.BillingAccountName | Should -Be $data.BillingAccountName
                $result.BillingCurrency    | Should -Be $data.BillingCurrency
                $result.BillingPeriodEnd   | Should -Be (Get-Date $data._BillingPeriodEnd -AsUTC)
                $result.BillingPeriodStart | Should -Be (Get-Date $data._BillingPeriodStart -AsUTC)
                $result.ChargePeriodEnd    | Should -Be (Get-Date $data._ChargePeriodEnd -AsUTC)
                $result.ChargePeriodStart  | Should -Be (Get-Date $data._ChargePeriodStart -AsUTC)
                $result.ChargeType         | Should -Be $data._ChargeType
                $result.InvoiceIssuerName  | Should -Be 'Microsoft'
                $result.ProviderName       | Should -Be 'Microsoft'
                $result.PublisherName      | Should -Be $data._PublisherName
                $result.Region             | Should -Be (Get-FinOpsRegion $data.ResourceLocation).RegionName
                $result.ResourceId         | Should -Be $data.ResourceId
                $result.ResourceName       | Should -Be $data.ResourceName
                $result.ServiceCategory    | Should -Be $expectedService.ServiceCategory
                $result.ServiceName        | Should -Be $expectedService.ServiceName
                $result.SubAccountId       | Should -Be "/subscriptions/$($data.SubscriptionId)"
                $result.SubAccountName     | Should -Be $data.SubscriptionName
            }    
            It 'Should prefix all non-0.5 columns' {
                # Arrange
                $focusColumns = @(
                    'AmortizedCost',
                    'AvailabilityZone', 
                    'BilledCost', 
                    'BillingAccountId', 
                    'BillingAccountName', 
                    'BillingCurrency', 
                    'BillingPeriodEnd', 
                    'BillingPeriodStart', 
                    'ChargePeriodEnd', 
                    'ChargePeriodStart', 
                    'ChargeType', 
                    'InvoiceIssuerName', 
                    'ProviderName', 
                    'PublisherName', 
                    'Region', 
                    'ResourceId', 
                    'ResourceName', 
                    'ServiceCategory', 
                    'ServiceName', 
                    'SubAccountId', 
                    'SubAccountName'
                )
                $knownColumns = $focusColumns + @("ftk_*")

                # Act
                $result = (Run-Test $data $data)[0]
                
                # Assert
                $result `
                | Select-Object -Property * -ExcludeProperty $knownColumns `
                | Should -BeNullOrEmpty
            }
            It 'Should filter commitment purchases out of amortized' {
                # Arrange
                $focusColumns = @(
                    'AmortizedCost',
                    'AvailabilityZone', 
                    'BilledCost', 
                    'BillingAccountId', 
                    'BillingAccountName', 
                    'BillingCurrency', 
                    'BillingPeriodEnd', 
                    'BillingPeriodStart', 
                    'ChargePeriodEnd', 
                    'ChargePeriodStart', 
                    'ChargeType', 
                    'InvoiceIssuerName', 
                    'ProviderName', 
                    'PublisherName', 
                    'Region', 
                    'ResourceId', 
                    'ResourceName', 
                    'ServiceCategory', 
                    'ServiceName', 
                    'SubAccountId', 
                    'SubAccountName'
                )
                $knownColumns = $focusColumns + @("ftk_*")

                # Act
                $result = (Run-Test $data $data)[0]
                
                # Assert
                $result `
                | Select-Object -Property * -ExcludeProperty $knownColumns `
                | Should -BeNullOrEmpty
            }
            # TODO: Add tests for the amortized/billed cost columns
        }

        Context 'Custom columns' -Skip {
            # TODO: Add tests for any columns we're adding and cleaning up (e.g., IDs, prices)
        }
    }
}
