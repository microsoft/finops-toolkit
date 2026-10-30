# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$script:__MonitorConfig = @{
    Indentation = ''
    Colors      = @{
        Envelope  = 'DarkGray'
        Message   = 'Gray' #$host.UI.RawUI.ForegroundColor
        Exception = 'Yellow' # fall back to system default
    }
}
$script:__MonitorConfig | Add-Member -MemberType ScriptMethod -Name Indent -Value { param([string]$Chars = '  ') $script:__MonitorConfig.Indentation += $Chars }
$script:__MonitorConfig | Add-Member -MemberType ScriptMethod -Name Outdent -Value { param([string]$Chars = '  ') if ($Chars.Length -eq 0) { return } $script:__MonitorConfig.Indentation = $script:__MonitorConfig.Indentation -replace ".{$($Chars.Length)}$", '' }

<#
    .SYNOPSIS
    Starts a monitoring session with formatted console output.

    .PARAMETER Name
    The name of the monitoring session.

    .PARAMETER ScriptBlock
    The script block to monitor.

    .DESCRIPTION
    The Start-Monitor command starts a monitoring session with formatted console output. The command is used to monitor the progress of a script block. To write messages to the console, use the Report command (Write-MonitorMessage).
#>
function Start-Monitor
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Name,
        [Parameter()][string]$Indent,
        [Parameter()][switch]$CatchExceptions,
        [Parameter(Position = 1)][scriptblock]$ScriptBlock
    )

    if ($script:__MonitorConfig.Indentation.Length -gt 0) { Write-MonitorMessage }
    $script:__MonitorConfig.Indent($Indent)
    Write-MonitorMessage $Name
    $script:__MonitorConfig.Indent('│ ')
    try
    {
        $ScriptBlock.Invoke()
    }
    catch
    {
        # Use inner exception; outer exception is from the Invoke() call
        $e = $_.Exception.InnerException ?? $_.Exception ?? $_
        if ($CatchExceptions)
        {
            Write-MonitorMessage "Script failed!" -Exception $e
        }
        else
        {
            throw $e
        }
    }
    finally
    {
        $script:__MonitorConfig.Outdent()
        Write-MonitorMessage -Footer "└$('─' * (50 - $script:__MonitorConfig.Indentation.Length - 1))"
        $script:__MonitorConfig.Outdent($Indent)
    }
}

<#
    .SYNOPSIS
    Writes a message to the console.

    .PARAMETER Message
    The message to write.

    .PARAMETER Object
    An object to write. If specified, the object will be written in dark gray.

    .PARAMETER Exception
    An exception to write after the message. If specified, the message and stack trace will be written in yellow.

    .PARAMETER Header
    A header to write before the message. If specified, the header will be written in dark gray.

    .PARAMETER Footer
    A footer to write after the message. If specified, the footer will be written in dark gray.
#>
function Write-MonitorMessage
{
    param(
        [string]$Message,
        [object]$Object,
        [System.Exception]$Exception,
        [string]$Header,
        [string]$Footer
    )

    $messages = @()

    if ($Message -or -not ($Exception -or $Object))
    {
        $messages += @{ Message = $Message; Header = $Header; Footer = $Footer }
    }

    if ($Object)
    {
        $Object.PSObject.Properties | ForEach-Object {
            $messages += @{
                Message = "$($_.Name) = $($_.Value | ConvertTo-Json -Depth 1)"
                Header  = "$Header  "
                Footer  = $Footer
            }
        }
    }

    if ($Exception)
    {
        # Check for nested exception
        if (-not $Exception.Message -and $Exception.Exception) { $Exception = $Exception.Exception }

        $newHeader = "$Header  "
        $messages += @{ Header = $newHeader; Exception = $Exception.Message }
        $Exception.StackTrace -replace '   at', '├╴at' -replace '├([^├]+)$', '└$1' -split '\r\n' `
        | ForEach-Object {
            # TODO: Do we need to abort for empty stack traces? -- if (-not $_) { return }
            $segments = $_ -split '╴'
            $messages += @{ Header = "$newHeader$($segments[0])╴"; Exception = "$($segments[1])" }
        }
    }

    $messages | ForEach-Object {
        Invoke-Command -ArgumentList @($_.Message, $_.Exception, $_.Header, $_.Footer) -ScriptBlock {
            param(
                [string]$Message,
                [string]$Exception,
                [string]$Header,
                [string]$Footer
            )
            @(
                @{ text = $script:__MonitorConfig.Indentation; color = 'Envelope' }
                @{ text = $Header; color = 'Envelope' }
                @{ text = $Message; color = 'Message' }
                @{ text = $Exception; color = 'Exception' }
                @{ text = $Footer; color = 'Envelope' }
            ) | Where-Object { $_.text } `
            | ForEach-Object { Write-Host $_.text -ForegroundColor $script:__MonitorConfig.Colors.$($_.color) -NoNewline }
            Write-Host ''
            return

            Write-Host "$($script:__MonitorConfig.Indentation)$Header" -NoNewline -ForegroundColor $script:__MonitorConfig.Colors.Envelope
            if ($Message)
            {
                Write-Host $Message -NoNewline -ForegroundColor $script:__MonitorConfig.Colors.Message
            }
            if ($Exception)
            {
                Write-Host $Exception -NoNewline -ForegroundColor $script:__MonitorConfig.Colors.Exception
            }
            Write-Host $Footer -ForegroundColor $script:__MonitorConfig.Colors.Envelope
        }
    }
}

Set-Alias Monitor Start-Monitor
Set-Alias Report Write-MonitorMessage
