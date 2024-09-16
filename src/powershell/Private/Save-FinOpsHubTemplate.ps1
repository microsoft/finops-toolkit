# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

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
        # Get environment to verify hubs version
        $azEnv = (Get-AzContext).Environment.Name

        # If no environment is found, check without the Name property
        if (-not $azEnv)
        {
            $azEnv = (Get-AzContext).Environment
        }
    }
    catch
    {
        # Don't fail the script if this fails; just assume public cloud
        $azEnv = 'AzureCloud'
    }

    try
    {
        New-Directory -Path $Destination
        # TODO: Remove 0.2+ filter for Azure Gov/China when FOCUS exports are supported
        $releases = Get-FinOpsToolkitVersion -Latest:$($Version -eq 'Latest') -Preview:$Preview `
        | Where-Object { $_.Version -ne '0.2' -and ($azEnv -eq 'AzureCloud' -or $_.Version.StartsWith('0.0') -or $_.Version.StartsWith('0.1')) }  # 0.2 not supported in Azure Gov/China (as of Feb 2024)

        # Redirect 0.2 to 0.3 due to bug
        if ($Version -eq '0.2')
        {
            Write-Information $LocalizedData.Hub_Deploy_02to021
            $Version = '0.3'
        }
        
        # TODO: Remove 0.2+ redirect for Azure Gov/China when FOCUS exports are supported
        # Redirect 0.2.* to 0.1.1 for Azure Gov/China
        if ($azEnv -ne 'AzureCloud' -and $Version -ne '0.0' -and $Version.StartsWith('0.1') -eq $false -and $Version -ne 'latest')
        {
            Write-Information $LocalizedData.Hub_Deploy_02to011
            $Version = '0.1.1'
        }


        # Get the version
        if ($Version.ToLower() -eq 'latest')
        {
            $release = $releases | Select-Object -First 1
        }
        else
        {
            $release = $releases | Where-Object -FilterScript { $_.Version -eq $Version }
        }

        # Save files
        foreach ($asset in $release.Files)
        {
            Write-Verbose -Message ($script:LocalizedData.HubTemplate_Save_FoundAsset -f $asset.Name)
            $saveFilePath = Join-Path -Path $Destination -ChildPath $asset.Name
            
            if (Test-Path -Path $saveFilePath)
            {
                Remove-Item -Path $saveFilePath -Recurse -Force
            }

            $null = Invoke-WebRequest -Uri $asset.Url -OutFile $saveFilePath -Verbose:$false
            if ([System.IO.Path]::GetExtension($saveFilePath) -eq '.zip')
            {
                Write-Verbose -Message ($script:LocalizedData.HubTemplate_Save_ExpandingZip -f $saveFilePath)
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
