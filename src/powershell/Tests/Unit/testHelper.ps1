function New-MockReleaseObject
{
    param
    (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Releases,

        [Parameter()]
        [switch]
        $AsJson
    )

    $output = @()
    foreach ($hashtable in $Releases)
    {
        $hashtable['tag_name'] = $hashtable.Version
        $output += New-Object -TypeName 'psobject' -Property $hashtable
    }

    if ($AsJson)
    {
        $output = ConvertTo-Json -InputObject $output
    }

    return $output
}

function New-MockRelease
{
    [OutputType([hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Version,

        [Parameter()]
        [bool]
        $PreRelease = $false,

        [Parameter()]
        $Assets = @()
    )

    return @{
        Name       = $Name
        Version    = $Version
        PreRelease = $PreRelease
        Assets     = $Assets
    }
}

function New-MockAsset
{
    [OutputType([hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Parameter()]
        [switch]
        $Base
    )

    $output = @{ Name = $Name }

    if ($Base)
    {
        $output['browser_download_url']  = $Url
    }
    else
    {
        $output['Url']  = $Url
    }

    return $output
}

function New-MockResource
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $SubscriptionId,

        [Parameter()]
        [string]
        $ResourceGroupName,

        [Parameter()]
        [string]
        $Name
    )

    $tagTemplate = '/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Cloud/hubs/{2}'

    return @{
        Tags = @{
            'cm-resource-parent' = $tagTemplate -f  $SubscriptionId, $ResourceGroupName, $Name
        }
    }
}
