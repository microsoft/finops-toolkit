# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# ARM endpoint for the cloud the user is actually signed in to. Hardcoding the
# public URL breaks Azure Government and Azure China.
function Get-FinOpsArmEndpoint {
    $url = $null
    try { $url = (Get-AzContext).Environment.ResourceManagerUrl } catch { }
    if ([string]::IsNullOrWhiteSpace($url)) { $url = 'https://management.azure.com' }
    return $url.TrimEnd('/')
}

function Get-PlainAccessToken {
    param([string]$ResourceUrl)
    if ([string]::IsNullOrWhiteSpace($ResourceUrl)) { $ResourceUrl = Get-FinOpsArmEndpoint }
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
