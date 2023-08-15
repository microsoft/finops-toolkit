<#
    .SYNOPSIS
        Saves a released version of the FinOps hub bicep template to local disk.

    .PARAMETER Version
        Version of the FinOps hub to download. Defaults to latest.

    .PARAMETER Destination
        Path to store the download. Defaults to env:temp.

    .EXAMPLE
        Save-FinOpsHubTemplate

        Downloads the latest version of FinOps hub template to current users' temp folder.

    .EXAMPLE
        Save-FinOpsHubTemplate -Version '1.0.0' -Destination 'C:\myHub'

        Downloads version 1.0.0 of FinOpsHub template to c:\myHub directory.
#>
function Save-FinOpsHubTemplate
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Version = 'latest',

        [Parameter()]
        [switch]
        $Preview,

        [Parameter()]
        [string]
        $Destination = $env:temp
    )

    $progress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try
    {
        New-Directory -Path $Destination
        $releases = Get-FinOpsToolkitVersion -Latest:$($Version -eq 'Latest') -Preview:$Preview

        if ($Version -eq 'Latest')
        {
            $release = $releases | Select-Object -First 1
        }
        else
        {
            $release = $releases | Where-Object -FilterScript {$_.Version -eq $Version}
        }

        foreach ($asset in $release.Assets)
        {
            Write-Verbose -Message ($script:localizedData.FoundAsset -f $asset.Name)
            $saveFilePath = Join-Path -Path $Destination -ChildPath $asset.Name
            if (Test-Path -Path $saveFilePath)
            {
                Remove-Item -Path $saveFilePath -Recurse -Force
            }

            $null = Invoke-Webrequest -Uri $asset.Url -OutFile $saveFilePath -Verbose:$false
            if ([System.IO.Path]::GetExtension($saveFilePath) -eq '.zip')
            {
                Write-Verbose -Message ($script:localizedData.ExpandingZip -f $saveFilePath)
                Expand-Archive -Path $saveFilePath -DestinationPath ($saveFilePath -replace '.zip', '')
                Remove-Item -Path $saveFilePath -Recurse -Force
            }
        }
    }
    catch
    {
        throw $_.Exception.Message
    }
    finally
    {
        $ProgressPreference = $progress
    }
}
