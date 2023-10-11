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

    .PARAMETER Destination
    Specifies the file path where the output CSV file, which contains the converted data, will be stored.

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

param(
    [Parameter(Mandatory = $true)]
    [string]
    $ActualCost,

    [Parameter(Mandatory = $false)]
    [bool]
    $ExportAllColumns = $true
)

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
    
        # Create a new object with the mapped column names
        # This will ensure that the output CSV has the correct column names
        # If exporting all columns, we will use the columnnames mapped here. 
        $newObject = @{
            AmortizedCost        = $object.AmortizedCost
            AvailabilityZone     = $object.AvailabilityZone
            BilledCost           = $object.BilledCost
            BillingAccountId     = $object.BillingAccountId
            BillingAccountName   = $object.BillingAccountName
            BillingCurrency      = $object.BillingCurrency
            BillingPeriodEnd     = $object.BillingPeriodEndDate
            BillingPeriodStart   = $object.BillingPeriodStartDate
            ChargePeriodEnd      = $object.ChargePeriodEndDate
            ChargePeriodStart    = $object.ChargePeriodStartDate
            ChargeType           = $object.ChargeType
            ProviderName         = $object.ProviderName
            PublisherName        = $object.PublisherName
            Region               = $object.Region
            ResourceId           = $object.ResourceId
            ResourceName         = $object.ResourceName
            ServiceCategory      = $object.ServiceCategory
            ServiceName          = $object.ServiceName
            SubAccountId         = $object.SubAccountId
            SubAccountName       = $object.SubAccountName
            ftk_AccountType      = (Get-AccountType -Object $object)
            ftk_BillingProfileId = $object.BillingProfileId
            ftk_BillingProfileName = $object.BillingProfileName
            ftk_SubscriptionId   = $object.SubscriptionId

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