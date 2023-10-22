# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Converts Microsoft Cost Management data to comply with the FinOps Open Cost and Usage Specification (FOCUS) schema version 0.5.

    .DESCRIPTION
    The ConvertTo-FinOpsSchema PowerShell script takes cost data adhering to the Microsoft Cost Management schema and converts it into a format that complies with the FinOps Open Cost and Usage Specification (FOCUS) schema version 0.5. 
    This conversion aids in data management, analytics, and reporting by ensuring data consistency and adherence to standards. 
    It's important to note that the script is specifically designed for schema version 0.5 (as of September 2023) and may not fully support older versions.
    Please review output and report any issues to https://aka.ms/ftk.

    .PARAMETER ActualCost
    Specifies the input cost data that will be converted. The object must adhere to a supported Microsoft Cost Management schema. Provide the filepath of the data to be converted. Example usage: ..\..\sample-data\EA_ActualCost.csv

    .PARAMETER ExportAllColumns
    Optionally specifies whether to export all columns in the input data or only the columns specified in the column mapping (Select-Object). When this parameter is set to $false, only the columns specified in the column mapping will be exported. Default value is $true, meaning all columns will be exported.


    .EXAMPLE
    ConvertTo-FinOpsSchema -ActualCost ..\..\sample-data\EA_ActualCost.csv  -ExportAllColumns $false | Export-Csv -Path .\EA_ActualCost_Output.csv -NoTypeInformation
    Converts the input data found in EA_ActualCost.csv, exporting only the columns specified in the column mapping (Select-Object), and stores the converted data in EA_ActualCost_Output.csv.

    .EXAMPLE
    ConvertTo-FinOpsSchema -ActualCost ..\..\sample-data\EA_ActualCost.csv  -ExportAllColumns $true | Export-Csv -Path .\EA_ActualCost_Output.csv 
    Converts the input data found in EA_ActualCost.csv, exporting all columns specified in the script, and stores the converted data in EA_ActualCost_Output.csv.

    .LINK
    https://aka.ms/ftk/ConvertTo-FinOpsSchema
#>
function ConvertTo-FinOpsSchema {
    [CmdletBinding()]
    param(
        [string]
        $ActualCost,

        [bool]
        $ExportAllColumns
    )

    if (-not (Test-Path -Path $ActualCost)) {
        Write-Error "Input file $ActualCost does not exist."
        return
    }

    # TODO: Add SchemaVersion
    # TODO: Warn if schema version is not supported (option to continue anyway?)

    $actualData = Import-Csv -Path $ActualCost
    $actualData | Add-Member -MemberType NoteProperty -Name DataSet -Value 'ActualCost'
    # TODO: Filter actual cost rows
    $actualData | Add-Member -MemberType NoteProperty -Name IsActualCost    -Value $true
    $actualData | Add-Member -MemberType NoteProperty -Name IsAmortizedCost -Value $false
    
    # TODO: Add support for amortized cost data
    $amortizedData = @()
    $amortizedData | Add-Member -MemberType NoteProperty -Name DataSet -Value 'AmortizedCost'
    $amortizedData | Add-Member -MemberType NoteProperty -Name IsAmortizedCost -Value $true
    
    $csvData = $actualData + $amortizedData
    $rowCount = $csvData.Count
    $processedCount = 0
    $start = [DateTime]::Now
    
    $transformedData = $csvData | ForEach-Object {
        $row = $_
        
        # Determine what type of cost this is
        $isAmortizedCost = $row.DataSet -ne 'ActualCost'
        $isActualCost = $row.DataSet -eq 'ActualCost' -or -not ( `
                $row.ChargeType -eq 'Purchase' -and ( `
                @('Reservation', 'SavingsPlan') -contains $row.PricingModel `
                    -or $row.ReservationId `
                    -or $row.BenefitId `
                    -or $row.ConsumedService.ToLower() -ne 'microsoft.capacity' `
            ) `
        )
        
        # TODO: Move outside the loop
        $accountType = Get-AccountType $row    
        $schemaVersion = "$($accountType)_2023-10-preview"
        
        $resourceInfo = Split-AzureResourceId ($row.ResourceId ?? $row.InstanceName)
        $regionInfo = Get-FinOpsSchemaRegion -ResourceLocation ($row.ResourceLocation ?? $row.Location ?? $row.MeterRegion)
        $serviceInfo = Get-FinOpsSchemaService `
            -ConsumedService $row.ConsumedService `
            -ResourceId $row.ResourceId `
            -MeterCategory $row.MeterCategory `
            -ProductName $row.ProductName `
            -PublisherId $row.PublisherId `
            -PublisherName $row.PublisherName `
            -PublisherType $row.PublisherType
        $unitInfo = Get-FinOpsSchemaUnits -UnitOfMeasure $row.UnitOfMeasure

        # Create a new object with the mapped column names
        # This will ensure that the output CSV has the correct column names
        # If exporting all columns, we will use the columnnames mapped here. 
        $newObject = @{
            AmortizedCost                  = if ($row.IsAmortizedCost) { $row.CostInBillingCurrency } else { 0 }
            AvailabilityZone               = $row.AvailabilityZone
            BilledCost                     = if ($row.IsActualCost) { $row.CostInBillingCurrency } else { 0 }
            BillingAccountId               = if ($accountType -eq 'EA') { "/providers/Microsoft.Billing/billingAccounts/$($row.BillingAccountId)" } elseif ($accountType -eq 'MCA') { "/providers/Microsoft.Billing/billingAccounts/$($row.BillingAccountId)/billingProfiles/$($row.BillingProfileId)" } else { "/subscriptions/$($row.SubAccountId)" }
            BillingAccountName             = $row.BillingAccountName ?? $row.SubscriptionName
            BillingCurrency                = $row.BillingCurrency ?? $row.BillingCurrencyCode ?? $row.Currency
            BillingPeriodEnd               = (Parse-Date $row.BillingPeriodEndDate -EndDate)
            BillingPeriodStart             = (Parse-Date $row.BillingPeriodStartDate)
            ChargePeriodEnd                = (Parse-Date ($row.Date ?? $row.UsageDate) -EndDate)
            ChargePeriodStart              = (Parse-Date ($row.Date ?? $row.UsageDate))
            ChargeType                     = if ($row.ChargeType.StartsWith('Unused')) { 'Usage' } elseif (@('Usage', 'Purchase') -contains $row.ChargeType) { $row.ChargeType } else { 'Adjustment' }
            InvoiceIssuerName              = $row.PartnerName ?? 'Microsoft'
            ServiceCategory                = $serviceInfo.ServiceCategory
            ServiceName                    = $serviceInfo.ServiceName
            ProviderName                   = $serviceInfo.ProviderName
            PublisherName                  = $serviceInfo.PublisherName
            Region                         = $regionInfo.RegionName
            ResourceId                     = $resourceInfo.ResourceId
            ResourceName                   = $resourceInfo.Name
            SubAccountId                   = "/subscriptions/$($row.SubscriptionId ?? $row.SubscriptionGuid)"
            SubAccountName                 = $row.SubscriptionName
            
            ftk_AccountName                = $row.AccountName
            ftk_AccountOwnerId             = $row.AccountOwnerId
            ftk_AccountType                = $accountType
            # TODO: Add an -ExpandJSON parameter to expand objects so we don't break CSV output by default
            ftk_AdditionalInfo             = $row.AdditionalInfo
            ftk_AmortizedCostInUsd         = if ($row.IsAmortizedCost) { $row.CostInUsd } else { 0 }
            ftk_AmortizedPricingCost       = if ($row.IsAmortizedCost) { $row.CostInPricingCurrency } else { 0 }
            ftk_BilledCostInUsd            = if ($row.IsActualCost) { $row.CostInUsd } else { 0 }
            ftk_BilledPricingCost          = if ($row.IsActualCost) { $row.CostInPricingCurrency } else { 0 }
            ftk_BillingAccountId           = $row.BillingAccountId
            ftk_BillingAccountName         = $row.BillingAccountName
            ftk_BillingAccountResourceType = if ($accountType -eq 'EA') { 'Microsoft.Billing/billingAccounts' } elseif ($accountType -eq 'MCA') { 'Microsoft.Billing/billingAccounts/billingProfiles' } else { 'Microsoft.Resources/subscriptions' }
            ftk_BillingAccountType         = if ($accountType -eq 'EA') { 'Billing Account' } elseif ($accountType -eq 'MCA') { 'Billing Profile' } else { 'Subscription' }
            ftk_BillingExchangeRate        = $original.ExchangeRate ?? $row.ExchangeRatePricingToBilling ?? 1
            ftk_BillingExchangeRateDate    = Parse-Date -Date ($row.BillingPeriodStartDate ?? $row.Date ?? $row.UsageDate) -StartOfMonth
            ftk_BillingProfileId           = $row.BillingProfileId
            ftk_BillingProfileName         = $row.BillingProfileName
            ftk_ChargeId                   = $null
            ftk_ChargeType                 = $row.ChargeType
            ftk_CommitmentDiscountId       = $row.BenefitId
            ftk_CommitmentDiscountName     = $row.BenefitName
            ftk_CommitmentDiscountProgram  = if (-not $row.BenefitId) { $null } elseif ($row.BenefitId.ToLower() -contains "/microsoft.capacity/reservation") { "Reservation" } elseif ($row.BenefitId.ToLower() -contains "microsoft.billingbenefits/savingsplan") { "Savings Plan" } else { $null }
            ftk_CostAllocationRuleName     = $row.CostAllocationRuleName
            ftk_CostCenter                 = $row.CostCenter
            ftk_CustomerName               = $row.CustomerName
            ftk_CustomerId                 = $row.CustomerTenantId
            ftk_DataSet                    = $row.DataSet
            ftk_EffectivePrice             = $row.EffectivePrice
            ftk_Frequency                  = $row.Frequency
            ftk_InvoiceId                  = $row.InvoiceId
            ftk_InvoiceIssuerId            = $row.PartnerTenantId
            ftk_InvoiceSectionId           = $row.InvoiceSectionId
            ftk_InvoiceSectionName         = $row.InvoiceSectionName
            ftk_IsCreditEligible           = $row.IsAzureCreditEligible
            ftk_ListCost                   = $row.PayGPrice * $row.Quantity
            ftk_ListCostInUsd              = $row.PayGPriceUSD * $row.Quantity
            ftk_ListPricingCost            = $row.PayGPrice * $row.Quantity
            ftk_ListPrice                  = $row.PayGPrice
            ftk_MeterCategory              = $row.MeterCategory
            ftk_MeterId                    = $row.MeterId
            ftk_MeterName                  = $row.MeterName
            ftk_MeterRegion                = $row.MeterRegion
            ftk_MeterSubCategory           = $row.MeterSubCategory
            ftk_OfferId                    = $row.OfferId
            ftk_PartNumber                 = $row.PartNumber
            ftk_PartnerCreditApplied       = $row.PartnerEarnedCreditApplied
            ftk_PartnerCreditRate          = $row.PartnerEarnedCreditRate
            ftk_PlanName                   = $row.PlanName
            ftk_PreviousInvoiceId          = $row.PreviousInvoiceId
            ftk_PricingCurrency            = $row.PricingCurrency ?? $row.BillingCurrency
            ftk_PricingModel               = $row.PricingModel
            ftk_PricingBlockSize           = $unitInfo.PricingBlockSize
            ftk_PricingQuantity            = $row.Quantity * $unitInfo.PricingBlockSize
            ftk_PricingUnit                = $unitInfo.PricingUnit
            ftk_ProductId                  = $row.ProductId
            ftk_ProductName                = $row.ProductName
            ftk_ProductOrderId             = $row.ProductOrderId
            ftk_ProductOrderName           = $row.ProductOrderName
            ftk_Provider                   = $row.Provider
            ftk_PublisherId                = $serviceInfo.PublisherId
            ftk_PublisherType              = $serviceInfo.PublisherType
            ftk_ResourceGroupId            = $resourceInfo.ResourceGroupId
            ftk_ResourceGroupName          = $resourceInfo.ResourceGroupName
            ftk_ResellerId                 = $row.ResellerMpnId
            ftk_ResellerName               = $row.ResellerName
            ftk_ResourceType               = $resourceInfo.ResourceType
            ftk_SchemaVersion              = $schemaVersion
            ftk_ServiceFamily              = $row.ServiceFamily
            # TODO: Add an -ExpandJSON parameter to expand objects so we don't break CSV output by default
            ftk_Tags                       = if (-not $row.Tags) { "{}" } elseif ($row.Tags.StartsWith("{")) { $row.Tags } else { "{$($row.Tags)}" }
            ftk_Term                       = $row.Term
            ftk_UsageQuantity              = $row.Quantity ?? $row.UsageQuantity
            ftk_UsageUnit                  = $unitInfo.DistinctUnits
        }
        # TODO: 
        # Unexpected Columns: When an unexpected column is encountered, the name of the column is added to $unexpectedColumns to notify the user after processing.
        # $RemoveCustomColumns: When $RemoveCustomColumns is $false (or not set), the unexpected columns are allowed to pass through to the output data. 
        # If $RemoveCustomColumns is $true, unexpected columns are omitted from the output. Write-Warning: A single warning with all unexpected column names is issued after processing, avoiding repetitive warnings during processing.
            
        $processedCount++
        
        # Time Estimation Logic.
        # If we have processed less than 10 rows, we will use an estimated seconds per row based on testing.
        $estimatedSecPerRow = 0.01
        # This is to avoid a divide by zero error. After 10 rows, we will use the average time per row.
        $percent = [Math]::Round(($processedCount / $rowCount) * 100, 1)
        # $secPerRow is the average processing time per row.
        $secPerRow = if ($processedCount -lt 10) { $estimatedSecPerRow } else { ([DateTime]::Now - $start).TotalSeconds / $processedCount }
        # $remaining is the estimated remaining time for the processing of the rest of the data based on that average.
        $remaining = $secPerRow * ($rowCount - $processedCount)

        # Number Formatting.
        # We want to format the numbers to be more readable. 
        # We will use the current culture to determine the appropriate formatting.
        $formattedProcessedCount = $processedCount.ToString('N0', [System.Globalization.CultureInfo]::CurrentCulture)
        $formattedRowCount = $rowCount.ToString('N0', [System.Globalization.CultureInfo]::CurrentCulture)

        Write-Progress -Activity "Converting to FinOps Schema" `
            -Status "Row $formattedProcessedCount of $formattedRowCount $percent% complete" `
            -PercentComplete $percent `
            -SecondsRemaining $remaining

        [PSCustomObject]$newObject
    }


    # If $ExportAllColumns is $false, we will only export the columns specified below using Select-Object.
    if (-not $ExportAllColumns) {
        $transformedData = $transformedData `
        | Select-Object AmortizedCost, AvailabilityZone, BilledCost, BillingAccountId, 
        BillingAccountName, BillingCurrency, BillingPeriodEnd, BillingPeriodStart, ChargePeriodEnd, 
        ChargePeriodStart, ChargeType, ProviderName, PublisherName, Region, ResourceId, ResourceName,
        ServiceCategory, ServiceName, SubAccountId, SubAccountName
    }
    # We will return all the transformed data if the value of $ExportAllColumns is $true.
    $transformedData
    Write-Progress -Activity "Converting to FinOps Schema" -Completed
}

function Get-AccountType {
    [CmdletBinding()]
    param(
        [PSCustomObject]
        $row
    )

    $ftk_AccountType = switch ($true) {
        { $row.BillingAccountId -eq $row.BillingProfileId } { "EA" }
        { $row.BillingAccountId.Contains(":") } { "MCA" }
        default { "Other" }
    }
    
    return $ftk_AccountType
}

# TODO: Make this its own public function
function Get-FinOpsSchemaRegion([string]$ResourceLocation) {
    # TODO: Look up from Regions.csv
    return @{
        RegionId   = ($ResourceLocation ?? "").ToLower() -replace " ", ""
        RegionName = $ResourceLocation
    }
}

# TODO: Make this its own public function
function Get-FinOpsSchemaService([string]$ConsumedService, [string]$ResourceId, [string]$MeterCategory, [string]$ProductName, [string]$PublisherId, [string]$PublisherName, [string]$PublisherType) {
    # TODO: Look up from Services.csv
    return @{
        # ServiceType values = Infrastructure, Platform, Software, Other
        ServiceType     = $null
        ServiceCategory = $null
        ServiceName     = $ConsumedService
        PublisherId     = $PublisherId
        PublisherName   = $PublisherName
        # PublisherType values = Cloud Provider, Vendor, Other???
        PublisherType   = ($PublisherType -eq "Marketplace") ? "Vendor" : "Cloud Provider"
        ProviderName    = $PublisherName ?? "Microsoft"
        ProviderType    = "Cloud Provider" # Cloud Provider, Vendor, Other???
    }
}

# TODO: Make this its own public function
function Get-FinOpsSchemaUnits([string]$UnitOfMeasure) {
    # TODO: Look up from PricingUnits.csv
    return @{
        DistinctUnit     = $UnitOfMeasure
        PricingBlockSize = 1
        PricingUnit      = $UnitOfMeasure
    }
}

function Parse-Date([string]$Date, [switch]$EndDate, [switch]$StartOfMonth) {
    try {
        $parsedDate = [datetime]::ParseExact($Date, "MM/dd/yyyy", [System.Globalization.CultureInfo]::InvariantCulture).ToUniversalTime().Date
        return ($EndDate `
                ? $parsedDate.AddDays(1) `
                : ($StartOfMonth `
                    ? (Get-Date $parsedDate -Day 1) `
                    : $parsedDate `
            ) `
        )
    } catch {
        return $null
    }
}
