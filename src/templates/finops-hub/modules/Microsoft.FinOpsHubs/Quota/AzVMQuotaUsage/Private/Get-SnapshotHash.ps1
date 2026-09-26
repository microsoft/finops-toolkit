# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Gets the lowercase SHA256 hash of a string.

.PARAMETER Text
    String to hash as UTF-8.

.OUTPUTS
    Lowercase hexadecimal hash.
#>
function Get-SnapshotHash {
    param ([string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant() }
    finally { $sha.Dispose() }
}
