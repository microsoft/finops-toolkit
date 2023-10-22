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

    $csvData = Import-Csv -Path $ActualCost
    
    $rowCount = $csvData.Count
    $processedCount = 0
    $start = [DateTime]::Now
    
    $transformedData = $csvData | ForEach-Object {
        $object = $_
        $object | Add-Member -MemberType NoteProperty -Name IsActualCost -Value $true # TODO: Filter actual dataset to only commitment purchases
        $object | Add-Member -MemberType NoteProperty -Name IsAmortizedCost -Value $false # TODO: Pull amortized cost from amortized dataset
        $accountType = Get-AccountType $object    
        $format = "MM/dd/yyyy"
        # Create a new object with the mapped column names
        # This will ensure that the output CSV has the correct column names
        # If exporting all columns, we will use the columnnames mapped here. 
        $newObject = @{
            AmortizedCost                    = if ($object.IsAmortizedCost) { $object.CostInBillingCurrency } else { 0 }            
            AvailabilityZone                 = $object.AvailabilityZone
            BilledCost                       = if ($object.IsActualCost) { $object.CostInBillingCurrency } else { 0 }            
            BillingAccountId                 = '/providers/Microsoft.Billing/billingAccounts/' + $object.BillingAccountId  
            BillingAccountName               = $object.BillingAccountName
            BillingCurrency                  = $object.BillingCurrency
            BillingPeriodEnd                 = [datetime]::ParseExact($object.BillingPeriodEndDate, $format, [System.Globalization.CultureInfo]::InvariantCulture).Date            
            BillingPeriodStart               = [datetime]::ParseExact($object.BillingPeriodStartDate, $format, [System.Globalization.CultureInfo]::InvariantCulture).Date
            ChargePeriodStart                = if ($object.PSObject.Properties.Name -contains 'ChargePeriodStart' -and -not [string]::IsNullOrEmpty($object.ChargePeriodStart)) {$object.ChargePeriodStart = [datetime]::ParseExact($object.ChargePeriodStart, $format, [System.Globalization.CultureInfo]::InvariantCulture).Date}
            ChargePeriodEnd                  = if ($object.PSObject.Properties.Name -contains 'ChargePeriodEnd' -and -not [string]::IsNullOrEmpty($object.ChargePeriodEnd)) {$object.ChargePeriodEnd = [datetime]::ParseExact($object.ChargePeriodEnd, $format, [System.Globalization.CultureInfo]::InvariantCulture).Date}
            ChargeType                       = if ($object.ChargeType.StartsWith('Unused')) { 'Usage' } elseif (@('Usage', 'Purchase') -contains $object.ChargeType) { $object.ChargeType } else { 'Adjustment' }
            ServiceName                      = $object.ConsumedService # TODO: Convert to ServiceName
            InvoiceIssuerName                = 'Microsoft' # TODO: Get partner name
            ProviderName                     = $object.'Microsoft'
            PublisherName                    = $object.PublisherName
            ResourceId                       = $object.ResourceId
            Region                           = $object.ResourceLocation # TODO: Convert to standard Azure region
            ResourceName                     = $object.ResourceId # TODO: (Split-AzureResourceId $object.ResourceId).Name
            SubAccountId                     = '/subscriptions/' + $object.SubscriptionId
            SubAccountName                   = $object.SubscriptionName
            ftk_AccountType                  = (Get-AccountType -Object $object)
            ftk_AccountId                    = $object.AccountId
            ftk_AccountName                  = $object.AccountName
            ftk_AccountOwnerId               = $object.AccountOwnerId
            ftk_AdditionalInfo               = $object.AdditionalInfo
            ftk_EffectivePrice               = $object.EffectivePrice
            ftk_BenefitId                    = $object.benefitId
            ftk_BenefitName                  = $object.benefitName
            ftk_BillingAccountId             = $object.BillingAccountId
            ftk_BillingAccountName           = $object.BillingAccountName
            ftk_BillingAccountType           = if ($accountType -eq 'EA') { 'Billing Account' } elseif ($accountType -eq 'MCA') { 'Billing Profile' } else { 'Subscription' }
            ftk_BillingAccountResourceType   = if ($accountType -eq 'EA') { 'Microsoft.Billing/billingAccounts' } elseif ($accountType -eq 'MCA') { 'Microsoft.Billing/billingAccounts/billingProfiles' } else { 'Microsoft.Resources/subscriptions' }
            ftk_BillingProfileId             = $object.BillingProfileId
            ftk_BillingProfileName           = $object.BillingProfileName
            ftk_ChargeType                   = $object.ChargeType
            ftk_CostAllocationRuleName       = $object.CostAllocationRuleName
            ftk_CostCenter                   = $object.CostCenter
            ftk_CostInPricingCurrency        = $object.CostInBillingCurrency
            ftk_BilledCostInUsd              = if ($object.IsActualCost) { $null } else { 0 } # TODO: Get CostInUsd for EA
            ftk_AmortizedCostInUsd           = if ($object.IsAmortizedCost) { $null } else { 0 } # TODO: Get CostInUsd for EA
            ftk_CustomerName                 = $null
            ftk_CustomerTenantId             = $null
            ftk_ExchangeRatePricingToBilling = if ($accountType -eq 'EA') { 1 } else { $null }
            ftk_ExchangeRateDate             = $object.BillingPeriodStartDate
            ftk_Frequency                    = $object.Frequency
            ftk_InvoiceId                    = $null
            ftk_InvoiceSectionId             = $object.InvoiceSectionId
            ftk_InvoiceSectionName           = $object.InvoiceSectionName
            ftk_IsAzureCreditEligible        = $object.IsAzureCreditEligible
            ftk_MeterCategory                = $object.MeterCategory
            ftk_MeterId                      = $object.MeterId
            ftk_MeterName                    = $object.MeterName
            ftk_MeterRegion                  = $object.MeterRegion
            ftk_MeterSubCategory             = $object.MeterSubCategory
            ftk_OfferId                      = $object.OfferId
            ftk_PartNumber                   = $object.PartNumber
            ftk_PartnerEarnedCreditApplied   = $null
            ftk_PartnerEarnedCreditRate      = $null
            ftk_InvoiceIssuerId              = $null
            ftk_PaygCostInBillingCurrency    = $object.PayGPrice * $object.Quantity
            ftk_PaygCostInUsd                = $object.PayGPriceUSD * $object.Quantity
            ftk_PayGPrice                    = $object.PayGPrice
            ftk_PlanName                     = $object.PlanName
            ftk_PreviousInvoiceId            = $null
            ftk_PricingCurrency              = $object.BillingCurrency
            ftk_PricingModel                 = $object.PricingModel
            ftk_ProductId                    = $object.ProductId
            ftk_ProductName                  = $object.ProductName
            ftk_ProductOrderId               = $object.ProductOrderId
            ftk_ProductOrderName             = $object.ProductOrderName
            ftk_Provider                     = $null
            ftk_PublisherId                  = $object.PublisherId
            ftk_ResourceGroupId              = $object.ResourceGroup # TODO: (Split-AzureResourceId $object.ResourceId).ResourceGroupId
            ftk_ResourceGroupName            = $object.ResourceGroup # TODO: (Split-AzureResourceId $object.ResourceId).ResourceGroupName
            ftk_PublisherType                = $object.PublisherType
            ftk_Quantity                     = $object.Quantity
            ftk_ResellerMpnId                = $null
            ftk_ResellerName                 = $null
            ftk_ResourceGroup                = $object.ResourceGroup
            ftk_ResourceType                 = $object.ResourceId #  TODO: Parse type from ResourceId
            ftk_ServiceFamily                = $object.ServiceFamily
            #... other mappings ...
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
        $percent = [Math]::Round(($processedCount / $rowCount) * 100,1)
        # $secPerRow is the average processing time per row.
        $secPerRow = if ($processedCount -lt 10) { $estimatedSecPerRow } else { ([DateTime]::Now - $start).TotalSeconds/$processedCount }
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
        $Object
    )

    $ftk_AccountType = switch ($true) {
        { $Object.BillingAccountId -eq $Object.BillingProfileId } { "EA" }
        { $Object.BillingAccountId.Contains(":") } { "MCA" }
        default { "Other" }
    }
    
    return $ftk_AccountType
}
