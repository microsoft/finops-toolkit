# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets details about an Azure resource type.

    .PARAMETER ResourceType
    Optional. Azure resource type value. Accepts wildcards. Default = * (all).

    .PARAMETER IsPreview
    Optional. Indicates whether to include or exclude resource types that are in preview. Note: Not all resource types self-identify as being in preview, so this may not be completely accurate. Default = null (include all).

    .DESCRIPTION
    The Get-FinOpsResourceType command returns an Azure resource type with readable display names, a flag to indicate if the resource provider identified this as a preview resource type, a description, an icon, and help and support links.

    .EXAMPLE
    Get-FinOpsResourceType -ResourceType "microsoft.compute/virtualmachines"

    Returns the resource type details for virtual machines.

    .EXAMPLE
    Get-FinOpsResourceType -Preview $false

    Returns all resource types that are not in preview.

    .LINK
    https://aka.ms/ftk/Get-FinOpsResourceType
#>
function Get-FinOpsResourceType()
{
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [string]
        $ResourceType = "*",

        [Nullable[bool]]
        $IsPreview = $null
    )

    process
    {
        return Get-OpenDataResourceType `
        | Where-Object {
            $_.ResourceType -like $ResourceType `
                -and ($null -eq $IsPreview -or $_.IsPreview -eq $IsPreview)
        } `
        | ForEach-Object {
            $_.IsPreview = $_.IsPreview -eq $true
            return $_
        }
    }
}
