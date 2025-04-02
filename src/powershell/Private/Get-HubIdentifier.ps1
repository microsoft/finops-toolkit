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
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Collection
    )

    $idPattern = '[a-z0-9]{13}'  # Matches exactly 13 alphanumeric characters
    $substrings = @()

    foreach ($string in $Collection)
    {
        # Use regex to find valid 13-character matches
        $match = [regex]::Matches($string, $idPattern)
        if ($match.Count -gt 0)
        {
            $substrings += $match | ForEach-Object { $_.Value }
        }

        # Generate all possible substrings
        for ($startIndex = 0; $startIndex -lt $string.Length; $startIndex++)
        {
            for ($endIndex = 1; $endIndex -le ($string.Length - $startIndex); $endIndex++)
            {
                $substrings += $string.Substring($startIndex, $endIndex).ToLower()
            }
        }
    }

    # Filter out matches that have hyphens or underscores and return the first valid match
    $validMatches = $substrings | Group-Object | Where-Object { $_.Count -eq $Collection.Length -and $_.Name.Length -eq 13 -and $_.Name -notmatch '[-_]' } | Select-Object -ExpandProperty Name
    return $validMatches | Select-Object -First 1
}
