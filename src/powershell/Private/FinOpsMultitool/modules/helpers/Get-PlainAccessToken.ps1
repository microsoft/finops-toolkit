# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# ARM endpoint for the cloud the user is actually signed in to. Hardcoding the
# public URL breaks Azure Government and Azure China.
function Get-FinOpsArmEndpoint {
    $url = $null
    try { $url = (Get-AzContext).Environment.ResourceManagerUrl } catch {
        Write-Verbose "Non-fatal: $($_.Exception.Message)"
    }
    if ([string]::IsNullOrWhiteSpace($url)) { $url = 'https://management.azure.com' }
    return $url.TrimEnd('/')
}

function Resolve-FinOpsRequestUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [switch]$AllowAnonymousLoopback
    )

    $parsed = $null
    if ($Uri -match '[\x00-\x20\\]' -or -not [Uri]::TryCreate($Uri, [UriKind]::Absolute, [ref]$parsed) -or
        $parsed.UserInfo -or $parsed.Fragment -or -not $parsed.Host) {
        throw 'The endpoint must be an absolute URL without credentials, fragments, or control characters.'
    }
    if ($parsed.Scheme -ne 'https' -and -not ($AllowAnonymousLoopback -and $parsed.Scheme -eq 'http' -and $parsed.IsLoopback)) {
        throw 'Authenticated and remote endpoints must use HTTPS. HTTP is allowed only for a token-free loopback emulator.'
    }
    return $parsed
}

function Get-PlainAccessToken {
    param([string]$ResourceUrl)
    if ([string]::IsNullOrWhiteSpace($ResourceUrl)) { $ResourceUrl = Get-FinOpsArmEndpoint }
    $null = Resolve-FinOpsRequestUri -Uri $ResourceUrl
    $tok = (Get-AzAccessToken -ResourceUrl $ResourceUrl).Token
    if ($tok -is [securestring]) {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tok)
        # PtrToStringBSTR, not PtrToStringAuto: a BSTR is always UTF-16, but Auto
        # picks the platform default and truncates the token to one char on macOS.
        try { [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    else { $tok }
}
