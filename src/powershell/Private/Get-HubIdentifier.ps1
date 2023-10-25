# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
<#
    .SYNOPSIS
    Gets the unique 13 character string that Azure deployments add to a resource from a list of strings.

    .PARAMETER Collection
    Collection of strings to evaluate.

    .EXAMPLE
    Get-HubIdentifier -Collection @('test-123456hyfpqje', 'test123456hyfpqje', '123456hyfpqjetest', 'test_hub_123456hyfpqje')

    Returns the string '123456hyfpqje'.
#>
function Get-HubIdentifier
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Collection
    )

    $substrings = @()
    foreach ($string in $Collection)
    {
        for ($startIndex = 0; $startIndex -lt $string.Length; $startIndex++)
        {
            for ($endIndex = 1; $endIndex -le ($string.Length - $startIndex); $endIndex++)
            {
                $substrings += $string.Substring($startIndex, $endIndex).ToLower()
            }
        }
    }

    $id = $substrings | Group-Object | Where-Object -FilterScript {$_.count -eq $Collection.length -and $_.Name.Length -eq 13} | Select-Object -Expand 'Name'
    if ($id -notcontains '-' -and $id -notcontains '_')
    {
        return $id
    }

    return $null
}
