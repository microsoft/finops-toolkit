$IsRunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'

<#
.SYNOPSIS
    Prerequisites and validation functions for the CostRecommendations script.
.DESCRIPTION
    This script contains functions for logging, version checking, module installation,
    Azure connectivity, scope selection, and file/folder preparation.
.NOTES
    Version: 2.0
    Author: arclares
#>

function Test-SubscriptionId {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId
    )
    
    # Validate subscription ID is a valid GUID format
    $guidRegex = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    return $SubscriptionId -match $guidRegex
}

function Test-ResourceGroupName {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    
    # Validate resource group name follows Azure naming conventions
    # Alphanumeric, hyphens, underscores, periods, and parentheses only
    # Between 1 and 90 characters
    # Cannot end with a period
    $rgNameRegex = '^[a-zA-Z0-9_\-\.\(\)]{1,90}$'
    $endsWithPeriod = $ResourceGroupName -match '\.$'
    
    return ($ResourceGroupName -match $rgNameRegex) -and (-not $endsWithPeriod)
}

function Test-ResourceType {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceType
    )
    
    # Validate resource type follows Azure format: Provider.Service/resourceType
    # Can have multiple levels like Provider.Service/parentType/childType
    $resourceTypeRegex = '^[A-Za-z0-9]+(\.[A-Za-z0-9]+)+/[A-Za-z0-9/]+$'
    return $ResourceType -match $resourceTypeRegex
}

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    Add-Content -Path $script:logFile -Value $logMessage -ErrorAction SilentlyContinue
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "DEBUG" { Write-Host $logMessage -ForegroundColor Gray }
    }
}

function Check-ScriptVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,

        [Parameter(Mandatory = $true)]
        [string]$RemoteVersionUrl
    )

    Write-Log -Message "Current script version: $CurrentVersion" -Level "INFO"
    Write-Log -Message "Checking for latest version at: $RemoteVersionUrl" -Level "INFO"

    try {
        $latestVersionString = Invoke-WebRequest -Uri $RemoteVersionUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Select-Object -ExpandProperty Content
        $latestVersionString = $latestVersionString.Trim()

        if (-not $latestVersionString -or $latestVersionString -notmatch '^\d+\.\d+(\.\d+)?(\.\d+)?$') {
             Write-Log -Message "Could not retrieve a valid version number (e.g., x.y.z) from '$RemoteVersionUrl'. Content received: '$latestVersionString'. Skipping update check." -Level "WARNING"
             return
        }

        $currentVerObj = [System.Version]$CurrentVersion
        $latestVerObj = [System.Version]$latestVersionString

        if ($latestVerObj -gt $currentVerObj) {
            Write-Host "-----------------------------------------------------------" -ForegroundColor Yellow
            Write-Host "ACTION REQUIRED: A newer version of this script is available!" -ForegroundColor Yellow
            Write-Host "  Your Version:     $CurrentVersion" -ForegroundColor Yellow
            Write-Host "  Latest Version:   $latestVersionString" -ForegroundColor Yellow
            Write-Host "-----------------------------------------------------------" -ForegroundColor Yellow
            Write-Log -Message "A newer version ($latestVersionString) is available. Current version is $CurrentVersion. Prompting user." -Level "WARNING"

            while ($true) {
                $choice = Read-Host "Do you want to [C]ontinue with the current version ($CurrentVersion) or [S]top to download the latest version? (C/S)"
                if ($choice -ne $null) {
                    $choice = $choice.ToLower().Trim()
                    if ($choice -eq 'c') {
                        Write-Log -Message "User chose to continue with outdated version $CurrentVersion." -Level "WARNING"
                        Write-Host "Proceeding with current version $CurrentVersion..." -ForegroundColor Cyan
                        Start-Sleep -Seconds 3
                        return
                    }
                    elseif ($choice -eq 's') {
                        Write-Log -Message "User chose to stop and download the latest version ($latestVersionString)." -Level "INFO"
                        Write-Host "`nTo download the latest version, please run the following command:" -ForegroundColor Green
                        # --- IMPORTANT: Update the URL and OutFile below to the correct ones for THIS script ---
                        Write-Host "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/microsoft/finops-toolkit/features/wacoascripts/src/wacoa/tools/CollectCostRecommendations.ps1' -OutFile 'CollectCostRecommendations.ps1'" -ForegroundColor Cyan
                        # --- Update the URL and OutFile above ---
                        Write-Host "`nScript execution stopped. Please download the latest version and run it again." -ForegroundColor Yellow
                        exit
                    }
                    else {
                        Write-Host "Invalid input. Please enter 'C' to Continue or 'S' to Stop." -ForegroundColor Red
                    }
                } else {
                     Write-Host "Input cannot be empty. Please enter 'C' or 'S'." -ForegroundColor Red
                }
            }
        }
        elseif ($latestVerObj -lt $currentVerObj) {
             Write-Log -Message "Current script version ($CurrentVersion) is newer than the version found online ($latestVersionString). You might be running a development version." -Level "WARNING"
        }
        else {
            Write-Log -Message "Script is up to date (Version $CurrentVersion)." -Level "INFO"
        }
    }
    catch {
        Write-Log -Message "Failed to check for script updates. Error: $($_.Exception.Message). Continuing with current version ($CurrentVersion)." -Level "WARNING"
    }
}

function Install-AndImportModules {
    param (
        [string[]]$Modules
    )

    if (($env:ACC_ENV -eq 'AzureCloudShell') -or ($env:CLOUD_SHELL -eq 'true')) {
        Write-Log -Message "Running in Azure Cloud Shell. Adjusting module installation..." -Level "INFO"
        $modulesToInstallInCloudShell = @('ImportExcel', 'powershell-yaml')
        foreach ($module in $modulesToInstallInCloudShell) {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                Write-Log -Message "Installing module for Cloud Shell: $module" -Level "INFO"
                Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
            }
        }
    }
    else {
        foreach ($module in $Modules) {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                Write-Log -Message "Installing module: $module" -Level "INFO"
                Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
            }
        }
    }

    foreach ($module in $Modules) {
        Import-Module -Name $module -ErrorAction Stop
        Write-Log -Message "Ensured module '$module' is imported." -Level "INFO"
    }
}

function Connect-ToAzure {
    if (($env:ACC_ENV -eq 'AzureCloudShell') -or ($env:CLOUD_SHELL -eq 'true')) {
        Write-Log -Message "Already connected to Azure in Cloud Shell." -Level "INFO"
        $context = Get-AzContext
        Write-Log -Message "Current context: Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level "INFO"
        return
    }

    try {
        $context = Get-AzContext -ErrorAction Stop
        if (-not $context) {
            Write-Log -Message "Logging into Azure..." -Level "INFO"
            Connect-AzAccount -ErrorAction Stop
             $context = Get-AzContext -ErrorAction Stop
             Write-Log -Message "Logged into Azure successfully. Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level "INFO"
        }
        else {
            Write-Log -Message "Already logged into Azure. Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level "INFO"
        }
    }
    catch {
        Write-Log -Message "Failed to log into Azure: $_" -Level "ERROR"
        throw
    }
}

function Download-GitHubFolder {
    param (
        [string]$repoUrl,
        [string]$Destination
    )

    if (-not (Test-Path -Path $Destination)) {
        Write-Log -Message "Creating directory: $Destination" -Level "INFO"
        New-Item -Path $Destination -ItemType Directory -ErrorAction Stop | Out-Null
    }

    $tempPath = $env:TEMP
    if (-not $tempPath) { $tempPath = $env:HOME } # Fallback for Linux/Cloud Shell where $env:TEMP is null
    if (-not $tempPath) { $tempPath = $PSScriptRoot }
    $zipFilePath = Join-Path $tempPath "azure-resources.zip"

    Write-Log -Message "Downloading zip file from: $repoUrl to $zipFilePath" -Level "INFO"
    try {
        Invoke-WebRequest -Uri $repoUrl -OutFile $zipFilePath -ErrorAction Stop
    }
    catch {
        Write-Log -Message "Failed to download zip file: $_" -Level "ERROR"
        throw
    }

    Write-Log -Message "Extracting zip file to: $Destination" -Level "INFO"
    try {
        # First, extract to a temporary staging directory for validation
        $stagingPath = Join-Path $tempPath "azure-resources-staging"
        if (Test-Path -Path $stagingPath) {
            Remove-Item -Path $stagingPath -Recurse -Force -ErrorAction Stop
        }
        New-Item -Path $stagingPath -ItemType Directory -ErrorAction Stop | Out-Null
        
        # Extract without -Force to staging directory first
        Expand-Archive -Path $zipFilePath -DestinationPath $stagingPath -ErrorAction Stop
        
        # Validate extracted contents for path traversal attempts
        $extractedFiles = Get-ChildItem -Path $stagingPath -Recurse -File
        $hasPathTraversal = $false
        foreach ($file in $extractedFiles) {
            $relativePath = $file.FullName.Substring($stagingPath.Length).TrimStart([IO.Path]::DirectorySeparatorChar)
            # Check for path traversal attempts (../ or ..\)
            if ($relativePath -match '\.\.[/\\]' -or $relativePath -match '^\.\.') {
                Write-Log -Message "Potential path traversal detected in zip file: $relativePath" -Level "ERROR"
                $hasPathTraversal = $true
                break
            }
        }
        
        if ($hasPathTraversal) {
            Remove-Item -Path $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
            throw "Zip file contains potentially malicious path traversal entries."
        }
        
        # If validation passed, copy to final destination
        Write-Log -Message "Validation passed. Moving files to final destination." -Level "INFO"
        Get-ChildItem -Path $stagingPath -Recurse | ForEach-Object {
            $targetPath = Join-Path $Destination ($_.FullName.Substring($stagingPath.Length).TrimStart([IO.Path]::DirectorySeparatorChar))
            if ($_.PSIsContainer) {
                if (-not (Test-Path -Path $targetPath)) {
                    New-Item -Path $targetPath -ItemType Directory -ErrorAction Stop | Out-Null
                }
            } else {
                $targetDir = Split-Path -Parent $targetPath
                if (-not (Test-Path -Path $targetDir)) {
                    New-Item -Path $targetDir -ItemType Directory -ErrorAction Stop | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $targetPath -Force -ErrorAction Stop
            }
        }
        
        # Clean up staging directory
        Remove-Item -Path $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log -Message "Failed to extract zip file: $_" -Level "ERROR"
        throw
    }

    Remove-Item -Path $zipFilePath -Force -ErrorAction Stop
    Write-Log -Message "Download and extraction completed successfully." -Level "INFO"
}

function Read-CachedScope {
    $cacheFilePath = Join-Path $PSScriptRoot $script:settings.paths.cacheFile
    if (Test-Path -Path $cacheFilePath) {
        try {
            $cachedScope = Get-Content -Path $cacheFilePath -Raw | ConvertFrom-Json -ErrorAction Stop
            return $cachedScope
        }
        catch {
            Write-Log -Message "Error reading cached scope: $_" -Level "WARNING"
            return $null
        }
    }
    return $null
}

function Write-CachedScope {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Scope
    )
    $cacheFilePath = Join-Path $PSScriptRoot $script:settings.paths.cacheFile
    try {
        $Scope | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFilePath -ErrorAction Stop
    }
    catch {
        Write-Log -Message "Error writing scope to cache: $_" -Level "WARNING"
    }
}

function Get-Scope {
    $cachedScope = Read-CachedScope

    if ($cachedScope) {
        Write-Host "A cached scope was found from the last run:" -ForegroundColor Cyan
        Write-Host "Scope Type: $($cachedScope.ScopeType)" -ForegroundColor Cyan
        
        if ($cachedScope.ScopeType -eq "EntireEnvironment") {
            Write-Host "Scope: Entire Environment (no filters)" -ForegroundColor Cyan
        }
        elseif ($cachedScope.ScopeType -eq "CustomList") {
            Write-Host "Scope: From JSON file - $($cachedScope.ScopeValue)" -ForegroundColor Cyan
            
            if ($cachedScope.IndividualScopes -and $cachedScope.IndividualScopes.Count -gt 0) {
                Write-Host "Includes:" -ForegroundColor Cyan
                foreach ($scope in $cachedScope.IndividualScopes) {
                    if ($scope.Type -eq "Subscription") {
                        Write-Host "  - Subscription: $($scope.SubscriptionId)" -ForegroundColor Cyan
                    }
                    elseif ($scope.Type -eq "ResourceGroup") {
                        Write-Host "  - Resource Group: $($scope.ResourceGroupName) (Subscription: $($scope.SubscriptionId))" -ForegroundColor Cyan
                    }
                }
            }
        }

        $reuseScope = Read-Host "Would you like to reuse the same scope? (Yes/No or Y/N)"
        $reuseScope = $reuseScope.ToLower()

        if ($reuseScope -eq "yes" -or $reuseScope -eq "y") {
            Write-Log -Message "Reusing cached scope: $($cachedScope.ScopeType)" -Level "INFO"
            return $cachedScope
        }
        elseif ($reuseScope -eq "no" -or $reuseScope -eq "n") {
            Write-Log -Message "User opted not to reuse the cached scope. Proceeding with new scope selection." -Level "INFO"
            Remove-Item -Path (Join-Path $PSScriptRoot $script:settings.paths.cacheFile) -ErrorAction SilentlyContinue
        }
        else {
            Write-Log -Message "Invalid input. Please enter 'Yes', 'No', 'Y', or 'N'. Exiting script." -Level "ERROR"
            throw "Invalid scope selection."
        }
    }

    Write-Host "`nSelect the scope for the script:" -ForegroundColor Cyan
    Write-Host "1. Entire environment (no filters)."
    Write-Host "2. Load scope(s) from JSON file."
    $choice = Read-Host "Enter your choice (1 or 2)"

    switch ($choice) {
        '1' {
            Write-Log -Message "Running script across the entire environment (no filters)." -Level "INFO"
            $scope = @{
                ScopeType         = "EntireEnvironment"
                ScopeValue        = "EntireEnvironment"
                SubscriptionIds   = $null
                ResourceGroupName = $null
                IndividualScopes  = $null
            }
        }
        '2' {
            $jsonPath = $null
            if ($IsRunningOnWindows -and (-not (($env:ACC_ENV -eq 'AzureCloudShell') -or ($env:CLOUD_SHELL -eq 'true')))) {
                try {
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
                    $openFileDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
                    $openFileDialog.Title = "Select a scope JSON file"

                    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $jsonPath = $openFileDialog.FileName
                    }
                    else {
                        Write-Log -Message "User cancelled file selection." -Level "ERROR"
                        throw "No JSON file selected."
                    }
                }
                catch {
                    Write-Warning "System.Windows.Forms is not available or failed to load. Please enter the path manually."
                    $jsonPath = Read-Host "Enter full path to the JSON file"
                    if (-not (Test-Path -LiteralPath $jsonPath)) {
                        Write-Log -Message "File not found at path: $jsonPath" -Level "ERROR"
                        throw "File not found at path: $jsonPath"
                    }
                }
            }
            else {
                Write-Host "Please provide the path to the scope JSON file." -ForegroundColor Cyan
                Write-Host "Tip: Upload the file to your Cloud Shell home directory first." -ForegroundColor Yellow
                $jsonPath = Read-Host "Enter file path (e.g., /home/user/scope.json or ~/scope.json)"
                if (-not (Test-Path -LiteralPath $jsonPath)) {
                    Write-Log -Message "File not found at path: $jsonPath" -Level "ERROR"
                    throw "File not found at path: $jsonPath"
                }
            }

            Write-Log -Message "Selected JSON file: $jsonPath" -Level "INFO"
            
            try {
                $scopeData = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json -ErrorAction Stop
                
                if (-not $scopeData.scopes -or $scopeData.scopes.Count -eq 0) {
                    Write-Log -Message "Invalid JSON format or empty scopes array. JSON should contain a 'scopes' array with scope objects." -Level "ERROR"
                    throw "Invalid JSON format. The file should contain a 'scopes' array."
                }
                
                $individualScopes = @()
                $allSubscriptionIds = @()
                
                foreach ($item in $scopeData.scopes) {
                    $rawScope = $item.scope
                    
                    if (-not $rawScope) {
                        Write-Log -Message "Invalid scope item found in JSON. Each item should have a 'scope' property." -Level "WARNING"
                        continue
                    }
                    
                    if ($rawScope -match "^/subscriptions/([^/]+)$") {
                        $subId = $Matches[1]
                        
                        # Validate subscription ID format
                        if (-not (Test-SubscriptionId -SubscriptionId $subId)) {
                            Write-Log -Message "Invalid subscription ID format: $subId (must be a valid GUID)" -Level "ERROR"
                            continue
                        }
                        
                        $allSubscriptionIds += $subId
                        
                        $individualScopes += @{
                            Type = "Subscription"
                            SubscriptionId = $subId
                            ResourceGroupName = $null
                        }
                        
                        Write-Log -Message "Added subscription scope: $subId" -Level "INFO"
                    } 
                    elseif ($rawScope -match "^/subscriptions/([^/]+)/resourceGroups/([^/]+)$") {
                        $subId = $Matches[1]
                        $rgName = $Matches[2]
                        
                        # Validate subscription ID and resource group name formats
                        if (-not (Test-SubscriptionId -SubscriptionId $subId)) {
                            Write-Log -Message "Invalid subscription ID format: $subId (must be a valid GUID)" -Level "ERROR"
                            continue
                        }
                        
                        if (-not (Test-ResourceGroupName -ResourceGroupName $rgName)) {
                            Write-Log -Message "Invalid resource group name format: $rgName" -Level "ERROR"
                            continue
                        }
                        
                        $allSubscriptionIds += $subId
                        
                        $individualScopes += @{
                            Type = "ResourceGroup"
                            SubscriptionId = $subId
                            ResourceGroupName = $rgName
                        }
                        
                        Write-Log -Message "Added resource group scope: $rgName in subscription $subId" -Level "INFO"
                    } 
                    else {
                        Write-Log -Message "Invalid scope format detected: $rawScope" -Level "WARNING"
                        Write-Log -Message "Expected format: /subscriptions/{subId} or /subscriptions/{subId}/resourceGroups/{rgName}" -Level "WARNING"
                    }
                }
                
                if ($individualScopes.Count -eq 0) {
                    Write-Log -Message "No valid scopes found in the JSON file." -Level "ERROR"
                    throw "No valid scopes found in the JSON file."
                }
                
                $allSubscriptionIds = $allSubscriptionIds | Select-Object -Unique
                
                $scope = @{
                    ScopeType         = "CustomList"
                    ScopeValue        = $jsonPath
                    SubscriptionIds   = $allSubscriptionIds -join ','
                    ResourceGroupName = $null
                    IndividualScopes  = $individualScopes
                }
                
                Write-Log -Message "Loaded $($individualScopes.Count) scope(s) from JSON file." -Level "INFO"
                Write-Log -Message "Unique subscriptions: $($allSubscriptionIds.Count)" -Level "INFO"
            }
            catch {
                Write-Log -Message "Error processing JSON file: $_" -Level "ERROR"
                throw "Error processing JSON file: $_"
            }
        }
        default {
            Write-Log -Message "Invalid choice. Exiting script." -Level "ERROR"
            throw "Invalid scope selection."
        }
    }

    Write-CachedScope -Scope $scope
    return $scope
}

function Get-FilePath {
    if (($env:ACC_ENV -eq 'AzureCloudShell') -or ($env:CLOUD_SHELL -eq 'true')) {
        Write-Host "Please provide the path to the Well-Architected assessment CSV file." -ForegroundColor Cyan
        Write-Host "Tip: Upload the file to your Cloud Shell home directory first." -ForegroundColor Yellow
        $filePath = Read-Host "Enter file path (e.g., /home/user/assessment.csv or ~/assessment.csv)"
        if (Test-Path -LiteralPath $filePath) {
            return $filePath
        }
        else {
            Write-Host "File not found at path: $filePath" -ForegroundColor Red
            return $null
        }
    }
   elseif ($IsRunningOnWindows) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
        $fileBrowser.InitialDirectory = [Environment]::GetFolderPath('Desktop')
        $fileBrowser.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
        $fileBrowser.Title = "Select the Well-Architected Cost Optimization Assessment File"

        if ($fileBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $fileBrowser.FileName
        }
        else {
            return $null
        }
    }
    catch {
        Write-Warning "System.Windows.Forms is not available. Please enter the path manually."
        $filePath = Read-Host "Enter full path to the CSV file"
        if (-not (Test-Path -LiteralPath $filePath)) {
            Write-Host "File not found at path: $filePath" -ForegroundColor Red
            return $null
        }
        return $filePath
    }
}
else {
    Write-Host "Please provide the path to the Well-Architected assessment CSV file." -ForegroundColor Cyan
    Write-Host "Tip: Upload the file to your Cloud Shell home directory first." -ForegroundColor Yellow
    $filePath = Read-Host "Enter file path (e.g., /home/user/assessment.csv or ~/assessment.csv)"
    if (Test-Path -LiteralPath $filePath) {
        return $filePath
    }
    else {
        Write-Host "File not found at path: $filePath" -ForegroundColor Red
        return $null
    }
}
}