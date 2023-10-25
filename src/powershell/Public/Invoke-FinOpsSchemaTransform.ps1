# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Loads Microsoft Cost Management cost data from a CSV file, converts it to the FinOps Open Cost and Usage Specification (FOCUS) schema, and saves it to a new CSV file.

    .DESCRIPTION
    The Invoke-FinOpsSchemaTransform command reads actual and amortized cost data from files via Import-Csv, converts them to the FinOps Open Cost and Usage Specification (FOCUS) schema via ConvertTo-FinOpsSchema, and then saves the result to a CSV file using Export-Csv.
    
    This command is a simple helper to simplify chaining these commands together. If you do not want to read from a CSV file or write to a CSV file, use the ConvertTo-FinOpsSchema command.

    Invoke-FinOpsSchemaTransform inherits the same schema constraints as ConvertTo-FinOpsSchema. Refer to that documentation for details.

    .PARAMETER ActualCostPath
    Required. Specifies the path to the actual cost data file. File must be a supported Microsoft Cost Management schema.
    
    .PARAMETER AmortizedCostPath
    Required. Specifies the path to the amortized cost data file. File must be a supported Microsoft Cost Management schema.
    
    .PARAMETER OutputFile
    Required. Specifies the path to save the FOCUS cost data to.
    
    .PARAMETER Delimiter
    Optional. Specifies a delimiter to separate the property values. Enter a character, such as a colon (:). To specify a semicolon (;), enclose it in quotation marks. Default: "," (comma).
    
    .PARAMETER Encoding
    Optional. Specifies the encoding for the exported file. This value is passed to Export-Csv. Please refer to the Export-Csv documentation for the default and allowed values.

    .PARAMETER NoClobber
    Optional. Use this parameter to not overwrite an existing file. By default, if the file exists in the specified path, it will be overwritten without warning.
    
    .PARAMETER Force
    Optional. This parameter allows overwriting files with the Read Only attribute.
    
    .EXAMPLE
    Invoke-FinOpsSchemaTransform -ActualCostPath ActualCost.csv -AmortizedCostPath AmortizedCost.csv -OutputFile FOCUS.csv

    Converts previously downloaded ActualCost.csv and AmortizedCost.csv files to FOCUS and saves the combined data to a FOCUS.csv file.

    .LINK
    https://aka.ms/ftk/Invoke-FinOpsSchemaTransform
#>
function Invoke-FinOpsSchemaTransform {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ActualCostPath,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AmortizedCostPath,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputFile,

        [string]
        $Delimiter,

        [string]
        $Encoding,

        [switch]
        $NoClobber,

        [switch]
        $Force
    )
    
    Write-Verbose "Invoke-FinOpsSchemaTransform..."

    # Validate parameters
    if (-not (Test-Path $ActualCostPath)) {
        throw [string]::Format($LocalizedData.FinOpsSchemaTransform_Invoke_ActualCostPathNotFound, $ActualCostPath)
    }
    if (-not (Test-Path $AmortizedCostPath)) {
        throw [string]::Format($LocalizedData.FinOpsSchemaTransform_Invoke_ActualCostPathNotFound, $AmortizedCostPath)
    }
    
    # TODO: Consider importing from other file formats in a future release
    # Import-Excel / Export-Excel

    $actual = Import-Csv -Path $ActualCostPath
    Write-Verbose "  Imported $($actual.Count) rows from $ActualCostPath"
    $amortized = Import-Csv -Path $AmortizedCostPath
    Write-Verbose "  Imported $($amortized.Count) rows from $AmortizedCostPath"
    
    Write-Verbose "  Converting to FOCUS..."
    Write-Verbose "----------------------------------------"
    $converted = ConvertTo-FinOpsSchema -ActualCost $actual -AmortizedCost $amortized -Verbose:$false
    Write-Verbose "----------------------------------------"
    Write-Verbose "  Converted $($converted.Count) rows to FOCUS"

    # TODO: Consider exporting to other file formats in a future release
    $exportParams = @{}
    if ($Delimiter) { $exportParams.Delimiter = $Delimiter }
    if ($Encoding) { $exportParams.Encoding = $Encoding }
    Write-Verbose "  Exporting to CSV..."
    $converted `
    | Where-Object { $_ -ne $null } `
    | Export-Csv -Path $OutputFile -NoTypeInformation @exportParams -NoClobber:$NoClobber -Force:$Force
    Write-Verbose "...done"
}
