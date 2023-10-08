# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.


<#
    .SYNOPSIS
    Converts Cost Management cost data to the FinOps Open Cost and Usage Specification (FOCUS) schema.

    .DESCRIPTION
    The ConvertTo-FinOpsSchema command returns an object that adheres to the FinOps Open Cost and Usage Specification (FOCUS) schema.
    It currently understands how to convert Cost Management cost data using schema 0.5 as of September 2023.
    Older schemas may not be fully supported. Please review output and report any issues to https://aka.ms/ftk.
    You can pipe objects to ConvertTo-FinOpsSchema from an exported or downloaded CSV file using Import-Csv or ConvertFrom-Csv and pipe to Export-Csv to save as a CSV file.

    .PARAMETER ActualCost
    Specifies the actual cost data to be converted. Object must be a supported Microsoft Cost Management schema. Specify the filepath like this: .\Detail_Account_196312_202309_en.csv

    .PARAMETER outputFilePath
    Specifies the path of the output CSV file.

    .PARAMETER RunTest
    Specifies whether to run a test to estimate the processing time.

    .PARAMETER rows
    Specifies the number of rows to use for the test.

    .PARAMETER columns
    Specifies the number of columns to use for the test.

    .PARAMETER ExportAllColumns
    Specifies whether to export all columns or only the columns specified in the column mapping.

    .PARAMETER Force
    Specifies whether to force the operation to continue without user confirmation after the test is complete.

    .EXAMPLE
    ConvertTo-FinOpsSchema -ActualCost .\Detail_Account_196312_202309_en.csv -outputFilePath .\Detail_Account_196312_202309_en_filtered.csv -ExportAllColumns $false

    # This will convert the input file to the output file using the default column mapping and export only the columns specified in the column mapping. The operation will not run a test and will not prompt the user to continue.
    

    .EXAMPLE
    ConvertTo-FinOpsSchema -ActualCost .\Detail_Account_196312_202309_en.csv -outputFilePath .\Detail_Account_196312_202309_en_filtered.csv -columnMapping @{billingAccountId='BillingAccountId';billingAccountName='BillingAccountName';ftk_AccountType='ftk_AccountType';BillingProfileId='BillingProfileId';SubscriptionId='SubscriptionId'} -ExportAllColumns $true -Force

    # This will convert the input file to the output file using the default column mapping and export all columns. The operation will not run a test and will not prompt the user to continue. 

    .EXAMPLE
    ConvertTo-FinOpsSchema -ActualCost .\Detail_Account_196312_202309_en.csv -outputFilePath .\Detail_Account_196312_202309_en_filtered.csv -ExportAllColumns $true -RunTest -rows 1000 -columns 10 -Force
    # This will run a test to estimate the processing time and then prompt the user to continue. If the user enters Y or y, the operation will continue. If the user enters N or n, the operation will be aborted. 

    .EXAMPLE
    ConvertTo-FinOpsSchema -ActualCost .\Detail_Account_196312_202309_en.csv -outputFilePath .\Detail_Account_196312_202309_en_filtered.csv -ExportAllColumns $true -RunTest -rows 1000 -columns 10 -Force -ExportAllColumns $false
    # This will run a test to estimate the processing time and then continue without prompting the user. It will export only the columns specified in the column mapping.
#>

<# Parameter Block #>
param(
    [Parameter(Mandatory = $true)]
    [string]
    $ActualCost,

    [Parameter(Mandatory = $true)]
    [string]
    $outputFilePath,

    [Parameter(Mandatory = $false)]
    [bool]
    $RunTest = $false,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100000)]
    [int]
    $rows = 1000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 20)]
    [int]
    $columns = 10,

    [Parameter(Mandatory = $false)]
    [bool]
    $ExportAllColumns = $true,

    [Parameter(Mandatory = $false)]
    [switch]
    $Force
)

# Define the input and output file paths
$ActualCost=".\Detail_Account_196312_202309_en.csv"
$outputFilePath=".\Detail_Account_196312_202309_en_filtered.csv"

# Define the column mapping
# The keys are the original column names, and the values are the new column names. If the value is the same as the key, the column will not be renamed.
# If the value is not the same as the key, the column will be renamed and the value will be used as the new column name.
# If the key is not present in the input data, the column will not be included in the output data.
$columnMapping = @{
    billingAccountId = 'BillingAccountId'
    billingAccountName = 'BillingAccountName'
    ftk_AccountType = 'ftk_AccountType'
    BillingProfileId = 'BillingProfileId'
    SubscriptionId = 'SubscriptionId'
}

<# Helper Functions #>
function Add-AccountType {
    [CmdletBinding()]
    param 
    (
        [PSCustomObject]
        $Object
    )

    $ftk_AccountType = switch ($true) {
        { $Object.BillingAccountId -eq $Object.BillingProfileId } { "EA" }
        { $null -eq $Object.BillingProfileId -or 
          $Object.BillingProfileId -eq $Object.SubscriptionId } { "Other" }
        default { "MCA" }
    }
    # Add or Update the ftk_AccountType property to the object.
    if ($Object.PSObject.Properties["ftk_AccountType"]) {
        $Object.PSObject.Properties["ftk_AccountType"].Value = $ftk_AccountType
    } else {
        $Object | Add-Member -MemberType NoteProperty -Name "ftk_AccountType" -Value $ftk_AccountType -Force
    }
    
    return $Object
}


<# Main Function #>
function ConvertTo-FinOpsSchema {
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $ActualCost,

        [Parameter()]
        [string]
        $outputFilePath,

        [Parameter()]
        [hashtable]
        $columnMapping,

        [Parameter()]
        [bool]
        $ExportAllColumns,

        [Parameter()]
        [switch]
        $Force
    )
    
    if (-not (Test-Path -Path $ActualCost)) {
        Write-Error "Input file $ActualCost does not exist."
        return
    }
    
    $outputDirectory = [System.IO.Path]::GetDirectoryName($outputFilePath)
    if (-not (Test-Path -Path $outputDirectory -PathType Container)) {
        New-Item -Path $outputDirectory -ItemType Directory
    }

    # Import the CSV data
    $csvData = Import-Csv -Path $ActualCost
    
    # Iterate over each row and apply transformations
    $transformedData = $csvData | ForEach-Object {
        $object = $_
        $object = Add-AccountType -Object $object

        # Create a new object with the mapped column names
        $newObject = @{}
        foreach ($column in $object.PSObject.Properties.Name) {
            if ($ExportAllColumns -or $column -in $columnMapping.Keys) {
                $newColumnName = if ($columnMapping.ContainsKey($column)) { $columnMapping[$column] } else { $column }
                $newObject[$newColumnName] = $object.$column
            }
        }

        # Output the new object
        [PSCustomObject]$newObject
    }
    
    # Export the transformed data to the output CSV file
    $transformedData | Export-Csv -Path $outputFilePath -NoTypeInformation -Encoding UTF8
}




<# Testing Framework #>
# Define the number of rows and columns for testing and it will display an estimated processing time.
if ($RunTest) {
    $host.UI.RawUI.ForegroundColor = "Yellow"
    Write-Output "Running test..." 
    .\Estimate-ProcessingTime.ps1 -rows $rows -columns $columns -columnMapping $columnMapping -ExportAllColumns $ExportAllColumns
    $host.UI.RawUI.ForegroundColor = "White"
    $confirmation = Read-Host "Do you want to continue? (Y/N)"


} else {
    $confirmation = Read-Host "Do you want to continue? (Y/N)"
}

# if the user enters Y or y, continue with processing
if ($Force -or ($confirmation -eq 'Y')) {
    # Continue with processing...

<# The actual function call #>
    # Call the functions from the function with the specified parameters
    ConvertTo-FinOpsSchema -ActualCost $ActualCost -outputFilePath $outputFilePath -columnMapping $columnMapping -ExportAllColumns $ExportAllColumns
    $host.UI.RawUI.ForegroundColor = "Green"
    Write-Output "Processing completed."
    $host.UI.RawUI.ForegroundColor = "White"

} else {
    $host.UI.RawUI.ForegroundColor = "Red"
    Write-Output "Operation aborted by the user."
    $host.UI.RawUI.ForegroundColor = "White"

}