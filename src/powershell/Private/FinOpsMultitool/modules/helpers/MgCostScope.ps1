# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# -- MG-Scope State --------------------------------------------------------
# First cost module that gets 401/403 at MG scope sets this to $true.
# All subsequent modules check it and skip to per-sub immediately.
$script:MgCostScopeFailed = $false

function Test-MgCostScope {
    return (-not $script:MgCostScopeFailed)
}

function Set-MgCostScopeFailed {
    $script:MgCostScopeFailed = $true
    Write-Host "  MG-scope cost access unavailable for this tenant - all subsequent modules will use per-subscription queries" -ForegroundColor Yellow
}
