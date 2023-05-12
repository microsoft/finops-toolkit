<#
    .SYNOPSIS
        Retrieves available version numbers of the FinOps Hub template.
        
    .PARAMETER Latest
        Will only return the latest version number of FinOps Hub template.
       
    .PARAMETER Preview
        Includes pre-releases.
    
    .EXAMPLE
        Get-FinOpsToolkitVersions
        
        Returns all available released version numbers of FinOps Hub templates.
        
    .EXAMPLE
        Get-FinOpsToolkitVersions -Latest
        
        Returns only the latest version number of the FinOps Hub templates.
#>
function Get-FinOpsToolkitVersions
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [switch]
        $Latest,

        [Parameter()]
        [switch]
        $Preview
    )

    $releaseUri = 'https://api.github.com/repos/microsoft/cloud-hubs/releases'
    [array]$releases = Invoke-WebRequest -Uri $releaseUri -Verbose:$false | ConvertFrom-Json
    if (-not $Preview)
    {
        $releases = $releases | Where-Object {($_.prerelease -eq $false)} 
    }
    
    if ($Latest)
    {
        $releases = $releases | Select-Object -First 1
        Write-Verbose -Message ($LocalizedData.FoundLatestRelease -f $releases.tag_name)
    }
    
    return $releases.tag_name
}
