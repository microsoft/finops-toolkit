# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Get-PlainAccessToken {
    param([string]$ResourceUrl = 'https://management.azure.com')
    $tok = (Get-AzAccessToken -ResourceUrl $ResourceUrl).Token
    if ($tok -is [securestring]) {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tok)
        try { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
        finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    else { $tok }
}
