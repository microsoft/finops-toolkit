# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.


<#
.SYNOPSIS
Converts Cost Management cost data to the FinOps Open Cost and Usage Specification (FOCUS) schema.

.DESCRIPTION
The ConvertTo-FinOpsSchema command returns an object that adheres to the FinOps Open Cost and Usage Specification (FOCUS) schema.
It currently understands how to convert Cost Management cost data using the latest schemas as of September 2023.
Older schemas may not be fully supported. Please review output and report any issues to https://aka.ms/ftk.
You can pipe objects to ConvertTo-FinOpsSchema from an exported or downloaded CSV file using Import-Csv or ConvertFrom-Csv and pipe to Export-Csv to save as a CSV file.

.PARAMETER ActualCost
Specifies the actual cost data to be converted. Object must be a supported Microsoft Cost Management schema.

.PARAMETER AmortizedCost
Specifies the amortized cost data to be converted. Object must be a supported Microsoft Cost Management schema.

.PARAMETER Version
FOCUS schema version to convert data to. Allowed values: 0.5, 1.0-workingdraft, 1.0-preview. Default = 0.5.

.EXAMPLE
ConvertTo-FinOpsSchema -ActualCost (Import-Csv my-actual-cost-details.csv) -AmortizedCost (Import-Csv my-amortized-cost-details.csv) | Export-Csv my-cost-details-in-focus.csv

.NOTES
Version: 
Author: 
Date: 
#>

function ConvertTo-FinOpsSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [object]$ActualCost,

        [Parameter(Mandatory=$false)]
        [object]$AmortizedCost,

        [Parameter()]
        [ValidateSet("0.5", "1.0-workingdraft", "1.0-preview")]
        [string]$Version = "0.5"
    )
    
    # Define the columns to add to the output
    $columnsToAdd = @(
        'ftk_AccountName', 
        'ftk_AccountId', 
        'ftk_AccountOwnerId', 
        'ftk_AvailabilityZone', 
        'ftk_EffectivePrice'
        )
    
    # Combine ActualCost and AmortizedCost
    $CombinedCost = $ActualCost + $AmortizedCost
    Write-Host "Combined Cost Data Count: $($CombinedCost.Count)"
    
    # Perform transformations based on the version
    switch ($Version) {
        "0.5" {
            if ($null -ne $CombinedCost -and $CombinedCost.Count -gt 0) {
                $firstRow = $CombinedCost[0]
                # If the first row of the data does not contain the billingAccountId or BillingAccountId column, throw an error
                if (-not ($firstRow.PSObject.Properties.Name -contains 'billingAccountId' -or $firstRow.PSObject.Properties.Name -contains 'BillingAccountId')) {
                    throw "Cost details schema not supported."
                }
            # else throw an error 
            } else {
                throw "Combined Cost data is empty or null."
            }
            # TODO: Filter the actual cost data to rows where ChargeType == "Purchase" and PricingModel == "Reservation" or "SavingsPlan" (leave amortized cost as-is).
            # This to ensure that we only have rows with Purchase, reservation or savings plan data. Only applicable to actual cost data. Leaving the amortized cost data as-is.

            # 1. Uppercase Column Names Modifications
            $CombinedCost = $CombinedCost | ForEach-Object {
                $obj = $_
                $newObj = New-Object PSObject
                foreach ($property in $obj.PSObject.Properties) {
                    # If property name starts with a lowercase letter, modify the name
                    $newPropertyName = if ($property.Name -cmatch "^[a-z]") {
                        $property.Name -creplace '^[a-z]', { $_.Value.ToUpper() }
                    } else {
                        # If not, keep the original name
                        $property.Name
                    }
                    # Add the property to the new object with the potentially modified name
                    $newObj | Add-Member -MemberType NoteProperty -Name $newPropertyName -Value $property.Value
                }
                # Return the new object with modified property names
                $newObj
                # write-host "newObj: $($newObj | Select-Object -First 1 | Out-String)"
            }
            
            # Write-Host "Sample data after Uppercase Column Name Modifications: $($CombinedCost | Select-Object -First 1 | Out-String)"
            # Count the number of rows in the data
            Write-Host "Combined Cost Data Count after Uppercase Column Name Modifications: $($CombinedCost.Count)"


            # 2. Column Name Modifications (prepend 'ftk_')
            $CombinedCost = $CombinedCost | ForEach-Object {
                $properties = @{}
                $_.PSObject.Properties | ForEach-Object {
                    $newPropertyName = "ftk_" + ($_.Name.Substring(0,1).ToUpper() + $_.Name.Substring(1))
                    $properties.$newPropertyName = $_.Value
                }
                New-Object PSObject -Property $properties
            }
            # Write-Host "Sample data after Column Name Modifications: $($CombinedCost | Select-Object -First 1 | Out-String)"
            Write-Host "Combined Cost Data Count after Column Name Modifications: $($CombinedCost.Count)"

            # 3. Column Additions (ftk_AccountName, ftk_AccountId, ftk_AccountOwnerId, ftk_AvailabilityZone, ftk_EffectivePrice)
            $CombinedCost = $CombinedCost | ForEach-Object {
                $obj = $_
                foreach ($col in $columnsToAdd) {
                    if (-not $obj.PSObject.Properties.Name -contains $col) {
                        $obj = $obj | Add-Member -MemberType NoteProperty -Name $col -Value $null -PassThru
                    }
                }
                # Return the updated object
                $obj 
                # Write-Host "obj: $($obj | Select-Object -First 1 | Out-String)"

            }
            Write-Host "Combined Cost Data Count after Column Additions: $($CombinedCost.Count)"

            # 4. Additional Transformation
            
            # Logic for ftk_AccountType column (EA, MCA, Other)
            function Add-AccountType {
                param (
                    [PSCustomObject]$Object
                )
                
                # Logic for ftk_AccountType column (EA, MCA, Other)
                $ftk_AccountType = switch ($true) {
                    { $Object.ftk_BillingAccountId -eq $Object.ftk_BillingProfileId } { "EA" }
                    { $Object.ftk_BillingProfileId -eq $Object.ftk_SubscriptionId -or $null -eq $Object.ftk_BillingProfileId } { "Other" }
                    default { "MCA" }
                }
                
                # Add or Update the ftk_AccountType property to the object. This is where we add the actual row value.
                if ($Object.PSObject.Properties["ftk_AccountType"]) {
                    $Object.PSObject.Properties["ftk_AccountType"].Value = $ftk_AccountType
                } else {
                    $Object | Add-Member -MemberType NoteProperty -Name "ftk_AccountType" -Value $ftk_AccountType -Force
                }
                
                # Return the updated object
                return $Object
            }

            # Using the function to update $CombinedCost
            $CombinedCost = $CombinedCost | ForEach-Object {
                Add-AccountType -Object $_
            }
            
            Write-Host "Combined Cost Data Count after ftk_AccountType Column Addition: $($CombinedCost.Count)"


            # TODO: Add logic for ftk_BillingAccountName column
            # BillingAccountName = ...
            # If ftk_AccountType == "EA", then ftk_BillingAccountName
            # If ftk_AccountType == "MCA", then ftk_BillingProfileName
            # Otherwise, ftk_SubscriptionName
            
            # TODO: BillingPeriodEnd = BillingPeriodStart + 1d (format as ISO)
            # $CombinedCost = $CombinedCost | ForEach-Object {
            #     $obj = $_
            #     $billingPeriodStart = [datetime]$obj.ftk_BillingPeriodStartDate
            #     $billingPeriodEnd = $billingPeriodStart.AddDays(1)
            #     $obj.ftk_BillingPeriodEndDate = $billingPeriodEnd.ToString("yyyy-MM-ddTHH:mm:ssZ")
            #     # Return the updated object
            #     $obj

            # }

            # TODO: Add other transformation logic here...
            
            } # End of switch ($Version)
        
        "1.0-workingdraft" {
            # TODO: Implement transformations for 1.0-workingdraft version

        }
        
        "1.0-preview" {
            # TODO: Implement transformations for 1.0-preview version
        }
    }
    
    # Return the transformed combined cost data
    return $CombinedCost
}





########################################## Test the function and output the results to a CSV file ###################################

# Define the paths to your Actual Cost and Amortized Cost CSV files.
##########################################  This codeblock can be commented out when running the tests ##############################
<# $actualCostCsvPath = "Detail_Account_196312_202309_en.csv"
$amortizedCostCsvPath = "Detail_Account_196312_202309_en_amortized.csv" #>


# Check if the CSV paths exist. If they do, import the data and run the function. If not, throw an error.
##########################################  This whole code block can be commented out when running the tests #######################
<# if ((Test-Path $actualCostCsvPath) -and (Test-Path $amortizedCostCsvPath)) {
    $actualCostData = Import-Csv $actualCostCsvPath
    $amortizedCostData = Import-Csv $amortizedCostCsvPath
    Write-Host "Actual Cost Data Count: $($actualCostData.Count)"
    Write-Host "Amortized Cost Data Count: $($amortizedCostData.Count)"
    $transformedData = ConvertTo-FinOpsSchema -ActualCost $actualCostData -AmortizedCost $amortizedCostData
    Write-Host "Transformed Data Count: $($transformedData.Count)"
    $transformedData | Export-Csv "TransformedCombinedData.csv" -NoTypeInformation
} else {
    Write-Host "Error: Either $actualCostCsvPath or $amortizedCostCsvPath does not exist."
} #>
