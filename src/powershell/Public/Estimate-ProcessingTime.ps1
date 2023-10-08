# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    This script is used to test the processing time of the ConvertTo-FinOpsSchema function.

    .DESCRIPTION
    This script is used to test the ConvertTo-FinOpsSchema function.
    You can specify the number of rows and columns to generate, as well as the column mapping.
    It creates a CSV file based on the input of the user and calls the function with the specified parameters.
    The function will create a new CSV file with the specified column mapping and export all columns or only the columns specified in the column mapping.
    The script will then delete the input and output files.

    .PARAMETER rows
    Specifies the number of rows to use for the test.

    .PARAMETER columns
    Specifies the number of columns to use for the test.

    .PARAMETER columnMapping
    Specifies the column mapping to use for the test.

    .PARAMETER ExportAllColumns
    Specifies whether to export all columns or only the columns specified in the column mapping.

    .EXAMPLE
    .\Estimate-ProcessingTime.ps1 -rows 1000 -columns 10 -columnMapping @{billingAccountId='BillingAccountId';billingAccountName='BillingAccountName';ftk_AccountType='ftk_AccountType';BillingProfileId='BillingProfileId';SubscriptionId='SubscriptionId'} -ExportAllColumns $true
    # This will run a test to estimate the processing time and then prompt the user to continue. If the user enters Y or y, the operation will continue. If the user enters N or n, the operation will be aborted.

    .EXAMPLE
    .\Estimate-ProcessingTime.ps1 -rows 1000 -columns 10 -columnMapping @{billingAccountId='BillingAccountId';billingAccountName='BillingAccountName';ftk_AccountType='ftk_AccountType';BillingProfileId='BillingProfileId';SubscriptionId='SubscriptionId'} -ExportAllColumns $true -Force
    # This will run a test to estimate the processing time and then continue without prompting the user.

    .EXAMPLE
    .\Estimate-ProcessingTime.ps1 -rows 1000 -columns 10 -columnMapping @{billingAccountId='BillingAccountId';billingAccountName='BillingAccountName';ftk_AccountType='ftk_AccountType';BillingProfileId='BillingProfileId';SubscriptionId='SubscriptionId'} -ExportAllColumns $true -Force -ExportAllColumns $false
    # This will run a test to estimate the processing time and then continue without prompting the user. It will export only the columns specified in the column mapping.

    .EXAMPLE
    .\Estimate-ProcessingTime.ps1 -rows 1000 -columns 10 -columnMapping @{billingAccountId='BillingAccountId';billingAccountName='BillingAccountName';ftk_AccountType='ftk_AccountType';BillingProfileId='BillingProfileId';SubscriptionId='SubscriptionId'} -ExportAllColumns $true -Force -ExportAllColumns $false
    # This will run a test to estimate the processing time and then continue without prompting the user. It will export only the columns specified in the column mapping.

#>


<# Parameter Block #>
[CmdletBinding()]
param(
    [int]
    $rows,

    [int]
    $columns,

    [hashtable]
    $columnMapping,

    [bool]
    $ExportAllColumns = $true
)
    
# Define the directory, input, and output file paths
$directory = "..\Public"
$inputFile = "$directory\inputtestfile.csv"
$outputFile = "$directory\outputtestfile.csv"

# Ensure the directory exists
if (-not (Test-Path -Path $directory)) {
        New-Item -Path $directory -ItemType Directory
    }

# Create a large CSV file for testing
$columnNames = @('BillingAccountId', 'BillingAccountName', 'ftk_AccountType') + (5..$columns | ForEach-Object { "Column$_" })
$columnNames -join ',' | Out-File -FilePath $inputFile

Write-Verbose "Input file created at $inputFile"

# Add rows to the CSV file for testing purposes (this is not part of the function)
# The script uses a ForEach-Object loop to iterate over a range of numbers from 1 to the value of $rows. 
# For each number in the range, the loop generates a new row of data and writes it to a CSV file.
1..$rows | ForEach-Object {
    $rowData = @("BAID$_", "BAName$_", "Data3_$_", "Data3_$_") + (5..$columns | ForEach-Object { Get-Random })
    $rowData -join ',' | Out-File -FilePath $inputFile -Append -Force
}

# Call the function and Measure the time taken to export CSV with column mapping
$elapsedTime = Measure-Command {
    ConvertTo-FinOpsSchema -ActualCost $inputFile -outputFilePath $outputFile -columnMapping $columnMapping -ExportAllColumns $ExportAllColumns
}
$correctedTimeString = $elapsedTime.TotalSeconds *10
$host.UI.RawUI.ForegroundColor = "Yellow"
Write-Output "Estimated total processing time: $($correctedTimeString) seconds"
$host.UI.RawUI.ForegroundColor = "White"
#  delete the files after the test is complete
Remove-Item -Path $inputFile
Remove-Item -Path $outputFile
