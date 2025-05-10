# PowerShell script to download all files from FOCUS Spec v1.1 GitHub directory (no git, no zip)
# This script gathers the list of files at runtime by crawling the GitHub API for the v1.1 tag.
# It downloads each file from the v1.1 tag on GitHub, preserving the folder structure in the current directory.

$ErrorActionPreference = 'Stop'

# GitHub API URL for the v1.1 tree
$apiUrl = "https://api.github.com/repos/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/git/trees/v1.1?recursive=1"
$baseRawUrl = "https://raw.githubusercontent.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/v1.1/"
$targetRoot = Join-Path $PWD "."

Write-Host "Fetching file list from GitHub API..."
$response = Invoke-WebRequest -Uri $apiUrl -Headers @{ 'User-Agent' = 'PowerShell' }
$json = $response.Content | ConvertFrom-Json
$files = $json.tree | Where-Object { $_.type -eq 'blob' } | Select-Object -ExpandProperty path

foreach ($file in $files) {
    $url = $baseRawUrl + $file
    $targetPath = Join-Path $targetRoot $file
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    Write-Host "Downloading $file..."
    Invoke-WebRequest -Uri $url -OutFile $targetPath
}
 
