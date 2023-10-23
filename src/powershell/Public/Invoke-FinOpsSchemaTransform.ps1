# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Converts Microsoft Cost Management cost details to the FinOps Open Cost and Usage Specification (FOCUS) schema.

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
    Invoke-FinOpsSchemaTransform -ActualCostPath ActualCost.csv -AmortizedCostPath AmortizedCost.csv -Destination FOCUS.csv

    Converts previously downloaded ActualCost.csv and AmortizedCost.csv files to FOCUS and saves the combined data to a FOCUS.csv file.

    .LINK
    https://aka.ms/ftk/Invoke-FinOpsSchemaTransform
#>
function Invoke-FinOpsSchemaTransform {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string]
        $ActualCostPath,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
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

    # TODO: Consider importing from other file formats in a future release
    $actual = Import-Csv -Path $ActualCostPath
    $amortized = Import-Csv -Path $AmortizedCostPath
    
    $converted = ConvertTo-FinOpsSchema -ActualCost $actual -AmortizedCost $amortized

    # TODO: Consider exporting to other file formats in a future release
    $exportParams = @{}
    if ($Delimiter) { $exportParams.Delimiter = $Delimiter }
    if ($Encoding) { $exportParams.Encoding = $Encoding }
    Export-Csv -InputObject $converted -Path $OutputFile -NoTypeInformation @exportParams -NoClobber:$NoClobber -Force:$Force
}
