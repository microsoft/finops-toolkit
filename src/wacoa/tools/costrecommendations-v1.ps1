Function CostRecommendations {
    param (
        [string]$subscriptionIds,
        [string]$resourceGroupName,
        [switch]$Verbose
    )


    # Define the current version of this script. Update this whenever you make significant changes.
    $ScriptVersion = "1.0.1" # Current version as specified

    $RemoteVersionFileUrl = "https://raw.githubusercontent.com/microsoft/finops-toolkit/refs/heads/features/wacoascripts/src/wacoa/tools/version.txt"


    # Define log file path
    $logFile = Join-Path $PSScriptRoot ('ACORL-Log-' + (Get-Date -Format 'yyyy-MM-dd-HH-mm') + '.log')

    # Function to log messages
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
        Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
        switch ($Level) {
            "INFO" { Write-Host $logMessage -ForegroundColor Green }
            "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
            "ERROR" { Write-Host $logMessage -ForegroundColor Red }
            "DEBUG" { Write-Host $logMessage -ForegroundColor Gray }
        }
    }

    # Function to check if the current script version is the latest
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
            # Download the latest version string from the remote file
            $latestVersionString = Invoke-WebRequest -Uri $RemoteVersionUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Select-Object -ExpandProperty Content
            $latestVersionString = $latestVersionString.Trim()

            # Basic validation of the downloaded version string format
            if (-not $latestVersionString -or $latestVersionString -notmatch '^\d+\.\d+(\.\d+)?(\.\d+)?$') {
                 Write-Log -Message "Could not retrieve a valid version number (e.g., x.y.z) from '$RemoteVersionUrl'. Content received: '$latestVersionString'. Skipping update check." -Level "WARNING"
                 return # Continue execution without blocking
            }

            # Compare versions using the [System.Version] type
            $currentVerObj = [System.Version]$CurrentVersion
            $latestVerObj = [System.Version]$latestVersionString

            if ($latestVerObj -gt $currentVerObj) {
                Write-Host "-----------------------------------------------------------" -ForegroundColor Yellow
                Write-Host "ACTION REQUIRED: A newer version of this script is available!" -ForegroundColor Yellow
                Write-Host "  Your Version:     $CurrentVersion" -ForegroundColor Yellow
                Write-Host "  Latest Version:   $latestVersionString" -ForegroundColor Yellow
                Write-Host "-----------------------------------------------------------" -ForegroundColor Yellow
                Write-Log -Message "A newer version ($latestVersionString) is available. Current version is $CurrentVersion. Prompting user." -Level "WARNING"

                # Prompt user for action
                while ($true) {
                    $choice = Read-Host "Do you want to [C]ontinue with the current version ($CurrentVersion) or [S]top to download the latest version? (C/S)"
                    if ($choice -ne $null) {
                        $choice = $choice.ToLower().Trim()
                        if ($choice -eq 'c') {
                            Write-Log -Message "User chose to continue with outdated version $CurrentVersion." -Level "WARNING"
                            Write-Host "Proceeding with current version $CurrentVersion..." -ForegroundColor Cyan
                            Start-Sleep -Seconds 3
                            return # Exit the function, script execution continues
                        }
                        elseif ($choice -eq 's') {
                            Write-Log -Message "User chose to stop and download the latest version ($latestVersionString)." -Level "INFO"
                            Write-Host "`nTo download the latest version, please run the following command:" -ForegroundColor Green
                            # --- IMPORTANT: Update the URL and OutFile below to the correct ones for THIS script ---
                            Write-Host "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/microsoft/finops-toolkit/features/wacoascripts/src/wacoa/tools/CollectCostRecommendations.ps1' -OutFile 'CollectCostRecommendations.ps1'" -ForegroundColor Cyan
                            # --- Update the URL and OutFile above ---
                            Write-Host "`nScript execution stopped. Please download the latest version and run it again." -ForegroundColor Yellow
                            exit # Stop the entire script execution
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


    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "This script requires PowerShell 7 or later. Please upgrade to PowerShell 7." -ForegroundColor Red
        Write-Host "Download PowerShell 7 from: https://aka.ms/powershell-release" -ForegroundColor Yellow
        exit
    }

    # Function to install and import required modules
    function Install-AndImportModules {
        param (
            [string[]]$Modules
        )
        foreach ($module in $Modules) {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                Write-Log -Message "Installing module: $module" -Level "INFO"
                Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
            }
            # Check if module is already imported before trying to import again (Original script did this implicitly via Import-Module)
            # To maintain original behavior strictly, we just attempt import:
            Import-Module -Name $module -ErrorAction Stop # Original script logic
            Write-Log -Message "Ensured module '$module' is imported." -Level "INFO" # Adjusted log message slightly
        }
    }

    # Function to authenticate to Azure
    function Connect-ToAzure {
        try {
            $context = Get-AzContext -ErrorAction Stop # Original used Stop
            if (-not $context) {
                Write-Log -Message "Logging into Azure..." -Level "INFO"
                Connect-AzAccount -ErrorAction Stop
                # Re-fetch context to confirm login
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

    # Function to download a GitHub folder and its contents (Original version)
    function Download-GitHubFolder {
        param (
            [string]$repoUrl, # URL to the zip file
            [string]$Destination   # Local directory to extract the files
        )

        # Ensure the destination path exists
        if (-not (Test-Path -Path $Destination)) {
            Write-Log -Message "Creating directory: $Destination" -Level "INFO"
            New-Item -Path $Destination -ItemType Directory -ErrorAction Stop | Out-Null
        }

        # Define the path for the temporary zip file
        $zipFilePath = Join-Path $env:TEMP "azure-resources.zip"

        # Download the zip file
        Write-Log -Message "Downloading zip file from: $repoUrl" -Level "INFO"
        try {
            Invoke-WebRequest -Uri $repoUrl -OutFile $zipFilePath -ErrorAction Stop
        }
        catch {
            Write-Log -Message "Failed to download zip file: $_" -Level "ERROR"
            throw
        }

        # Extract the zip file
        Write-Log -Message "Extracting zip file to: $Destination" -Level "INFO"
        try {
            Expand-Archive -Path $zipFilePath -DestinationPath $Destination -Force -ErrorAction Stop
        }
        catch {
            Write-Log -Message "Failed to extract zip file: $_" -Level "ERROR"
            throw
        }

        # Clean up the temporary zip file
        Remove-Item -Path $zipFilePath -Force -ErrorAction Stop # Original used Stop
        Write-Log -Message "Download and extraction completed successfully." -Level "INFO"
    }


    # Function to read cached scope (Original version)
    function Read-CachedScope {
        $cacheFilePath = Join-Path $PSScriptRoot 'ScopeCache.txt'
        if (Test-Path -Path $cacheFilePath) {
            # Original script didn't have explicit error handling here
            $cachedScope = Get-Content -Path $cacheFilePath -Raw | ConvertFrom-Json
            return $cachedScope
        }
        return $null
    }

    # Function to write scope to cache (Original version)
    function Write-CachedScope {
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Scope
        )
        $cacheFilePath = Join-Path $PSScriptRoot 'ScopeCache.txt'
        # Original script didn't have explicit error handling here
        $Scope | ConvertTo-Json | Set-Content -Path $cacheFilePath -ErrorAction Stop
    }


    # Function to prompt for scope selection (Original version)
    function Get-Scope {
        # Check if there is a cached scope
        $cachedScope = Read-CachedScope

        if ($cachedScope) {
            Write-Host "A cached scope was found from the last run:" -ForegroundColor Cyan
            Write-Host "Scope Type: $($cachedScope.ScopeType)" -ForegroundColor Cyan
            Write-Host "Scope Value: $($cachedScope.ScopeValue)" -ForegroundColor Cyan

            $reuseScope = Read-Host "Would you like to reuse the same scope? (Yes/No or Y/N)"
            $reuseScope = $reuseScope.ToLower() # Original script converted to lower

            if ($reuseScope -eq "yes" -or $reuseScope -eq "y") {
                Write-Log -Message "Reusing cached scope: $($cachedScope.ScopeType) - $($cachedScope.ScopeValue)" -Level "INFO"
                return @{
                    SubscriptionIds   = $cachedScope.SubscriptionIds
                    ResourceGroupName = $cachedScope.ResourceGroupName
                }
            }
            elseif ($reuseScope -eq "no" -or $reuseScope -eq "n") {
                Write-Log -Message "User opted not to reuse the cached scope. Proceeding with new scope selection." -Level "INFO"
                Remove-Item -Path (Join-Path $PSScriptRoot 'ScopeCache.txt') -ErrorAction SilentlyContinue
            }
            else {
                # Original script threw an error here
                Write-Log -Message "Invalid input. Please enter 'Yes', 'No', 'Y', or 'N'. Exiting script." -Level "ERROR"
                throw "Invalid scope selection."
            }
        }

        # Prompt for new scope selection
        Write-Host "`nSelect the scope for the script:" -ForegroundColor Cyan
        Write-Host "1. Entire environment (no filters)."
        Write-Host "2. Specific subscription(s)."
        Write-Host "3. Specific resource group (requires subscription ID)."
        $choice = Read-Host "Enter your choice (1, 2, or 3)"

        switch ($choice) {
            '1' { # Original script used integers, but string comparison from Read-Host is safer
                Write-Log -Message "Running script across the entire environment (no filters)." -Level "INFO"
                $scope = @{
                    ScopeType         = "EntireEnvironment"
                    ScopeValue        = "EntireEnvironment"
                    SubscriptionIds   = $null
                    ResourceGroupName = $null
                }
            }
            '2' {
                $subscriptionIds = Read-Host "Enter the subscription ID(s), separated by commas"
                Write-Log -Message "Filtering by subscription ID(s): $subscriptionIds" -Level "INFO"
                $scope = @{
                    ScopeType         = "SubscriptionIDs"
                    ScopeValue        = $subscriptionIds
                    SubscriptionIds   = $subscriptionIds
                    ResourceGroupName = $null
                }
            }
            '3' {
                $subscriptionIds = Read-Host "Enter the subscription ID where the resource group resides"
                $resourceGroupName = Read-Host "Enter the resource group name"
                Write-Log -Message "Filtering by resource group '$resourceGroupName' in subscription '$subscriptionIds'." -Level "INFO"
                $scope = @{
                    ScopeType         = "ResourceGroup"
                    ScopeValue        = $resourceGroupName # Original stored RG name here
                    SubscriptionIds   = $subscriptionIds
                    ResourceGroupName = $resourceGroupName
                }
            }
            default {
                Write-Log -Message "Invalid choice. Exiting script." -Level "ERROR"
                throw "Invalid scope selection."
            }
        }

        # Cache the selected scope
        Write-CachedScope -Scope $scope
        return @{
            SubscriptionIds   = $scope.SubscriptionIds
            ResourceGroupName = $scope.ResourceGroupName
        }
    }


    # Function to process KQL files (Original version)
function Process-KQLFiles {
    param (
        [string]$BasePath,
        [string]$SubscriptionIds,
        [string]$ResourceGroupName
    )
    $kqlFiles = Get-ChildItem -Path $BasePath -Recurse -Filter *.kql -ErrorAction Stop
    Write-Log -Message "Found $($kqlFiles.Count) recommendation files." -Level "INFO"
    Write-Host "`nFound $($kqlFiles.Count) recommendation files." -ForegroundColor Cyan

    $allResources = @()
    $queryErrors = @()

    # Build subscription filter
    $subscriptionFilter = $null
    if ($SubscriptionIds) {
        $subscriptionList = $SubscriptionIds -split ',' | ForEach-Object { "'$($_.Trim())'" }
        $subscriptionFilter = $subscriptionList -join ","
    }

    foreach ($file in $kqlFiles) {
        try {
            $query = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop

            if ($subscriptionFilter -and $ResourceGroupName) {
                $query = "$query | where SubAccountId in ($subscriptionFilter) and x_ResourceGroupName == '$ResourceGroupName'"
            }
            elseif ($subscriptionFilter) {
                $query = "$query | where SubAccountId in ($subscriptionFilter)"
            }

            Write-Log -Message "Executing query for $($file.Name)..." -Level "DEBUG"
            $result = Search-AzGraph -Query $query -First 1000 -ErrorAction Stop
            $fileResources = @($result)

            while ($result -ne $null -and $result.SkipToken) {
                Write-Log -Message "Fetching next page for $($file.Name)..." -Level "DEBUG"
                $result = Search-AzGraph -Query $query -SkipToken $result.SkipToken -First 1000 -ErrorAction Stop
                $fileResources += $result
            }

            Write-Log -Message "Completed query for $($file.Name), found $($fileResources.Count) resources." -Level "DEBUG"
            $allResources += $fileResources
        }
        catch {
            $errorMessage = "Query failed for file '$($file.FullName)': $($_.Exception.Message)"
            Write-Log -Message $errorMessage -Level "ERROR"
            $queryErrors += [PSCustomObject]@{
                IsError = $true
                Error = $errorMessage
                Query = $query
                File = $file.FullName
            }
        }
    }

    foreach ($error in $queryErrors) {
        Write-Log -Message "Error processing $($error.File): $($error.Error)" -Level "ERROR"
        if ($error.Query) {
            Write-Log -Message "Failed Query: $($error.Query)" -Level "DEBUG"
        }
    }

    Write-Log -Message "Found $($allResources.Count) recommendations in the environment." -Level "INFO"
    Write-Host "Found $($allResources.Count) recommendations in the environment." -ForegroundColor Cyan

    return @{
        AllResources = $allResources
        QueryErrors  = $queryErrors
    }
}



    # Function to get Assessment file path (Original version)
    function Get-FilePath {
        Add-Type -AssemblyName System.Windows.Forms
        $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
        $fileBrowser.InitialDirectory = [Environment]::GetFolderPath('Desktop') # Default to Desktop
        $fileBrowser.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*" # Filter for CSV files
        $fileBrowser.Title = "Select the Well-Architected Cost Optimization Assessment File"

        # Show the file browser dialog
        if ($fileBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $fileBrowser.FileName
        }
        else {
            return $null
        }
    }

    # Function to process CustomCost folder YAML files without ARG validation (Original version)
    function Process-CustomCostRecommendations {
        param (
            [string]$BasePath # Path to the root folder containing CustomCost
        )

        # Define possible CustomCost folder paths
        $customCostPath = Join-Path $BasePath "CustomCost"
        $nestedCustomCostPath = Join-Path $BasePath "azure-resources\CustomCost"

        # Check if CustomCost folder exists at either location
        $foundPath = $null
        if (Test-Path -Path $customCostPath) {
            $foundPath = $customCostPath
            Write-Log -Message "Found CustomCost folder at: $customCostPath" -Level "INFO"
        }
        elseif (Test-Path -Path $nestedCustomCostPath) {
            $foundPath = $nestedCustomCostPath
            Write-Log -Message "Found CustomCost folder at: $nestedCustomCostPath" -Level "INFO"
        }
        else {
            Write-Log -Message "CustomCost folder not found at: $customCostPath or $nestedCustomCostPath" -Level "WARNING"
            return @()
        }

        # Find all YAML files in the CustomCost folder
        $yamlFiles = Get-ChildItem -Path $foundPath -Filter *.yaml -ErrorAction Stop # Original used Stop
        if ($yamlFiles.Count -eq 0) {
            Write-Log -Message "No YAML files found in CustomCost folder." -Level "WARNING"
            return @()
        }

        Write-Log -Message "Found $($yamlFiles.Count) YAML files in CustomCost folder." -Level "INFO"
        Write-Host "Found $($yamlFiles.Count) YAML files in CustomCost folder." -ForegroundColor Cyan

        # Initialize an array to store CustomCost recommendations
        $customCostData = @()

        foreach ($file in $yamlFiles) {
            try {
                # Read the YAML file content
                $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop

                # Convert YAML to PowerShell object(s)
                try {
                     # Original script assumed single object per file
                     $yamlObject = $yamlContent | ConvertFrom-Yaml
                     $customCostData += $yamlObject # Add the single object
                     Write-Log -Message "Successfully processed CustomCost file: $($file.Name)" -Level "INFO" # Original INFO level
                }
                catch {
                    Write-Log -Message "Failed to parse YAML file '$($file.FullName)': $_" -Level "ERROR"
                }
            }
            catch {
                Write-Log -Message "Failed to read CustomCost file '$($file.FullName)': $_" -Level "ERROR"
            }
        }

        Write-Log -Message "Processed $($customCostData.Count) CustomCost recommendations." -Level "INFO"
        return $customCostData
    }


    # Function to process YAML files and append them to the Excel file (Original version)
    function Manual-Validations {
        param (
            [string]$BasePath, # Path to the folder containing YAML files
            [string]$ExcelFilePath, # Path to the Excel file
            [string]$SubscriptionIds, # Subscription IDs to filter by
            [string]$ResourceGroupName  # Resource group name to filter by
        )

        try {
            # Get CustomCost recommendations first (no validation needed)
            $customCostRecommendations = Process-CustomCostRecommendations -BasePath $BasePath
            Write-Log -Message "Found $($customCostRecommendations.Count) CustomCost recommendations." -Level "INFO"

            # Import the YAML files (excluding CustomCost folder)
            # Original logic might need adjustment depending on where CustomCost really is relative to BasePath
            $yamlFiles = Get-ChildItem -Path $BasePath -Recurse -Exclude "CustomCost" -Filter *.yaml -ErrorAction Stop # Original used Stop
            Write-Log -Message "Found $($yamlFiles.Count) YAML files for validation." -Level "INFO"

            # Build subscription filter outside parallel block
            $subscriptionFilter = $null
            if ($SubscriptionIds) {
                $subscriptionList = $SubscriptionIds -split ',' | ForEach-Object { "'$($_.Trim())'" }
                $subscriptionFilter = $subscriptionList -join ","
            }

            # Extract unique resource types from YAML files (Original logic)
            $uniqueResourceTypes = @()
            # Original used ForEach-Object -Parallel
            $yamlFiles | ForEach-Object -Parallel {
                $file = $_
                $logFile = $using:logFile # Capture log file path

                # Create a local function for logging within the parallel block
                function Write-ParallelLog {
                    param (
                        [string]$Message,
                        [string]$Level = "INFO"
                    )
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $logMessage = "$timestamp [$Level] [Thread $([System.Threading.Thread]::CurrentThread.ManagedThreadId)] $Message"
                    $logFile = $using:logFile # Access variable from parent scope
                    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
                }

                try {
                    # Read the YAML file
                    $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop

                    # Convert YAML to PowerShell object (Original assumed single object)
                    $yamlObject = $yamlContent | ConvertFrom-Yaml

                    # Add the recommendationResourceType to the array
                    if ($yamlObject.recommendationResourceType) {
                        # Split the recommendationResourceType into individual resource types
                        $resourceTypes = $yamlObject.recommendationResourceType -split ' '
                        return $resourceTypes # Return the array of types
                    }
                }
                catch {
                    Write-ParallelLog -Message "Failed to process YAML file '$($file.FullName)': $_" -Level "ERROR"
                }
            } -ThrottleLimit 5 -AsJob | Receive-Job -Wait -AutoRemoveJob | ForEach-Object {
                # Collect results - flatten the potentially nested arrays
                if ($_ -is [array]) {
                    $uniqueResourceTypes += $_
                } elseif ($_) {
                     $uniqueResourceTypes += @($_) # Ensure it's added as an array element
                }
            }

            # Remove duplicates and sort
            $uniqueResourceTypes = $uniqueResourceTypes | Sort-Object -Unique

            # Debug: Print the unique resource types
            Write-Host "Unique resource types in YAML files: $($uniqueResourceTypes -join ', ')" -ForegroundColor Cyan
            Write-Log -Message "Unique resource types in YAML files: $($uniqueResourceTypes -join ', ')" -Level "INFO"

            # Construct the resource type filter
            # Original logic used 'type ==', ARG often uses '=~' for case-insensitivity
            $resourceTypeConditions = $uniqueResourceTypes | ForEach-Object { "type == '$_'" } # Using original '=='
            $resourceTypeFilter = $resourceTypeConditions -join ' or '

            # Query Azure Resource Graph for specific resource types
            # Original query structure
            $query = "resources | where $resourceTypeFilter"
            if ($subscriptionFilter -and $ResourceGroupName) {
                 # Original used 'subscriptionId in ($subscriptionFilter)' and 'resourceGroup ==', which is generally correct ARG syntax
                 # But ensure $subscriptionFilter is correctly formatted (it should be from earlier logic)
                 $query += " | where subscriptionId in ($subscriptionFilter) and resourceGroup == '$ResourceGroupName'"
            }
            elseif ($subscriptionFilter) {
                 $query += " | where subscriptionId in ($subscriptionFilter)"
            }
            $query += " | summarize count() by type"

            Write-Log -Message "Querying Azure Resource Graph for specific resource types." -Level "INFO"
            Write-Log -Message "Query: $query" -Level "DEBUG"
            # Original script didn't handle potential errors from Search-AzGraph here
            $resourceTypesInScope = Search-AzGraph -Query $query -First 1000

            # Debug: Print the resource types found in scope
            Write-Host "Resource types found in scope: $($resourceTypesInScope.type -join ', ')" -ForegroundColor Cyan
            Write-Log -Message "Resource types found in scope: $($resourceTypesInScope.type -join ', ')" -Level "INFO"

            # Initialize an array to store relevant YAML data
            $yamlData = @()

            # Process each YAML file (Original logic)
            # Original used ForEach-Object -Parallel
            $yamlFiles | ForEach-Object -Parallel {
                $file = $_
                $resourceTypesInScope = $using:resourceTypesInScope # Capture variable
                $logFile = $using:logFile # Capture log file path

                # Create a local function for logging within the parallel block
                function Write-ParallelLog {
                    param (
                        [string]$Message,
                        [string]$Level = "INFO"
                    )
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $logMessage = "$timestamp [$Level] [Thread $([System.Threading.Thread]::CurrentThread.ManagedThreadId)] $Message"
                    $logFile = $using:logFile # Access variable from parent scope
                    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
                }

                try {
                    # Read the YAML file
                    $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop

                    # Convert YAML to PowerShell object (Original assumed single object)
                    $yamlObject = $yamlContent | ConvertFrom-Yaml

                    # Split the recommendationResourceType into individual resource types
                    $resourceTypes = $yamlObject.recommendationResourceType -split ' '

                    # Check if any of the resource types exist in scope
                    $matchFound = $false
                    foreach ($resourceType in $resourceTypes) {
                        # Original used '-in', which is case-sensitive for strings by default.
                        # Use -contains (case-insensitive for collections) or explicit comparison
                        # $resourceTypesInScope.type is likely an array of strings from ARG result
                        if ($resourceTypesInScope.type -contains $resourceType) { # Case-insensitive check
                            $matchFound = $true
                            break
                        }
                    }

                    # If a match is found, return the YAML object
                    if ($matchFound) {
                        return $yamlObject
                    }
                }
                catch {
                    Write-ParallelLog -Message "Failed to process YAML file '$($file.FullName)': $_" -Level "ERROR"
                }
            } -ThrottleLimit 5 -AsJob | Receive-Job -Wait -AutoRemoveJob | ForEach-Object {
                if ($_) {
                    $yamlData += $_ # Collect the returned YAML objects
                }
            }

            # Combine validated recommendations with CustomCost recommendations
            $combinedData = $yamlData + $customCostRecommendations

            # Convert YAML data to a format suitable for Excel (Original structure)
            $excelData = $combinedData | ForEach-Object {
                [PSCustomObject]@{
                    Description                 = $_.description
                    AcorlGuid                   = $_.acorlGuid
                    RecommendationTypeId        = $_.recommendationTypeId
                    RecommendationControl       = $_.recommendationControl
                    RecommendationImpact        = $_.recommendationImpact
                    RecommendationResourceType  = $_.recommendationResourceType
                    RecommendationMetadataState = $_.recommendationMetadataState
                    RemediationAction           = $_.remediationAction
                    PotentialBenefits           = $_.potentialBenefits
                    PgVerified                  = $_.pgVerified
                    PublishedToLearn            = $_.publishedToLearn
                    AutomationAvailable         = $_.automationAvailable
                    Tags                        = $_.tags # Original didn't handle array format
                    LearnMoreLink               = ($_.learnMoreLink | ForEach-Object { "$($_.name): $($_.url)" }) -join "; " # Original formatting
                }
            }

            # Append YAML data to the Excel file
            if ($excelData.Count -gt 0) {
                Write-Log -Message "Appending $($excelData.Count) manual recommendations to the Excel file." -Level "INFO"
                # Original didn't handle potential errors here
                $excelData | Export-Excel -Path $ExcelFilePath -WorksheetName 'Manual Recommendations' -AutoSize -TableName 'ManualRecommendations' -TableStyle 'Light19'
            }
            else {
                Write-Log -Message "No manual recommendations found to append." -Level "WARNING"
            }
        }
        catch {
            Write-Log -Message "Error in Manual-Validations function: $_" -Level "ERROR"
            throw # Original threw error
        }
    }

    # Function to export Assessment results to Excel (Original version)
    function Export-ResultsToExcel {
        param (
            [array]$AllResources,
            [string]$AssessmentFilePath,
            [string]$ExcelFilePath
        )

        # Export KQL results to Excel
        # Original didn't check if $AllResources was empty
        $AllResources | Export-Excel -Path $ExcelFilePath -WorksheetName 'Recommendations' -AutoSize -TableName 'Table1' -TableStyle 'Light19'
        Write-Log -Message "Results exported to Excel file: $ExcelFilePath" -Level "INFO"

        # Add assessment data if provided
        if ($AssessmentFilePath) {
            try {
                $assessmentData = Get-Content -Path $AssessmentFilePath | Select-Object -Skip 11 | ConvertFrom-Csv -ErrorAction Stop
                $assessmentData | Export-Excel -Path $ExcelFilePath -WorksheetName 'Well-Architected Assessment' -AutoSize -TableName 'WAF Assessment' -TableStyle 'Light19'
                Write-Log -Message "Added Well-Architected Cost Optimization assessment as a new tab in the Excel file." -Level "INFO"
            }
            catch {
                Write-Log -Message "Failed to import or add the Well-Architected Cost Optimization assessment: $_" -Level "ERROR"
            }
        }
    }

    # Main script execution
    try {
        # --- Start Log Message with Version ---
        Write-Log -Message "Starting script execution (Version $ScriptVersion)." -Level "INFO" # Modified Log Message

        # --- Perform Version Check ---
        Check-ScriptVersion -CurrentVersion $ScriptVersion -RemoteVersionUrl $RemoteVersionFileUrl # Added Call

        # Check PowerShell Version (Original position)
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-Host "This script requires PowerShell 7 or later. Please upgrade to PowerShell 7." -ForegroundColor Red
            Write-Host "Download PowerShell 7 from: https://aka.ms/powershell-release" -ForegroundColor Yellow
            exit
        }

        Install-AndImportModules -Modules @('Az.Accounts', 'Az.ResourceGraph', 'ImportExcel', 'powershell-yaml')
        Connect-ToAzure

        $workingFolderPath = $PSScriptRoot
        Set-Location -Path $workingFolderPath
        Write-Log -Message "Set working directory to: $workingFolderPath" -Level "INFO"

        # Hardcoded GitHub repository folder URL (Original)
        $repoUrl = "https://github.com/microsoft/finops-toolkit/raw/refs/heads/features/wacoascripts/src/wacoa/content/azure-resources.zip"


        $tempBaseDir = Join-Path $workingFolderPath "Temp"
        $tempDir = Join-Path $tempBaseDir "azure-resources" 
        # Download and extract the zip file if the folder doesn't exist
        if (-not (Test-Path -Path $tempDir -PathType Container)) { # Check for container
             Write-Log -Message "Downloading and extracting zip file to $tempDir." -Level "INFO"
             # Ensure base Temp folder exists
             if (-not (Test-Path -Path $tempBaseDir -PathType Container)) {
                New-Item -Path $tempBaseDir -ItemType Directory -ErrorAction Stop | Out-Null
             }
             # Pass the base temp dir as destination, assuming zip extracts into 'azure-resources' folder
             Download-GitHubFolder -RepoUrl $repoUrl -Destination $tempBaseDir
        }
        else {
            Write-Log -Message "Folder '$tempDir' already exists. Skipping download." -Level "INFO"
        }


        # Prompt to include Well-Architected Cost Optimization assessment (Original logic)
        $includeAssessment = Read-Host "Would you like to include the results of a Well-Architected Cost Optimization assessment? (Yes/No or Y/N)"
        $assessmentFilePath = $null
        if ($includeAssessment -eq "yes" -or $includeAssessment -eq "y") {
            # Open file browser dialog to select the assessment file
            $assessmentFilePath = Get-FilePath
            if (-not $assessmentFilePath) {
                Write-Log -Message "No file selected. Skipping Well-Architected Cost Optimization assessment." -Level "WARNING"
            }
        }

        # Prompt for scope selection
        $scope = Get-Scope
        $subscriptionIds = $scope.SubscriptionIds
        $resourceGroupName = $scope.ResourceGroupName

        # Define the Excel file path
        $ExcelFilePath = Join-Path $PSScriptRoot ('ACORL-File-' + (Get-Date -Format 'yyyy-MM-dd-HH-mm') + '.xlsx')

        # Process YAML files and append to the Excel file (Original logic)
        $runManualChecks = Read-Host "Would you like to run manual checks? (Yes/No or Y/N)"
        if ($runManualChecks -eq "yes" -or $runManualChecks -eq "y") {
            Write-Log -Message "Running manual checks." -Level "INFO"
            # Process YAML files and append to the Excel file
            # Pass $tempDir (e.g., ./Temp/azure-resources) as the BasePath for Manual-Validations
            Manual-Validations -BasePath $tempDir -ExcelFilePath $ExcelFilePath -SubscriptionIds $subscriptionIds -ResourceGroupName $resourceGroupName
        }
        else {
            Write-Log -Message "Skipping manual checks as per user request." -Level "INFO"
            # No processing of CustomCost recommendations when manual checks are skipped in original logic
        }


        # Process KQL files
        # Pass $tempDir (e.g., ./Temp/azure-resources) as the BasePath for KQL files
        $results = Process-KQLFiles -BasePath $tempDir -SubscriptionIds $subscriptionIds -ResourceGroupName $resourceGroupName

        # Summarize recommendations by priority and resourceType (Original logic)
        # Note: Original grouping used 'x_RecommendationImpact' which might not be correct, should maybe be 'x_RecommendationPriority'? Sticking to original for now.
        $summary = $results.AllResources | Group-Object -Property @{
            Expression = {
                # Original used x_RecommendationImpact, but example output used Priority. Using original expression.
                "$($_.x_RecommendationPriority) | $($_.x_ResourceType)" # Assuming x_RecommendationPriority exists
            }
        } | ForEach-Object {
            # Splitting the Group Name (e.g., "High | Microsoft.Compute/virtualMachines")
             $groupParts = $_.Name -split ' \| '
             # Check if split worked correctly
             $priorityValue = if ($groupParts.Count -ge 1) { $groupParts[0] } else { 'Unknown Priority' }
             $resourceTypeValue = if ($groupParts.Count -ge 2) { $groupParts[1] } else { 'Unknown Type' }

            [PSCustomObject]@{
                Priority     = $priorityValue # Get priority from the group name
                ResourceType = $resourceTypeValue # Get resource type from the group name
                ImpactedResources = $_.Count
            }
        } | Sort-Object Priority, ResourceType # Added sort for consistent output


        # Display the summary
        Write-Host "`nRecommendations Summary:" -ForegroundColor Cyan
        $summary | Format-Table -AutoSize

        # Display Query Errors (using the error objects collected)
        if ($results.QueryErrors.Count -gt 0) {
            Write-Host "`nThe following query errors occurred:" -ForegroundColor Red
            foreach ($error in $results.QueryErrors) {
                 # Display the error message from the error object
                 Write-Host "- File: $($error.File)" -ForegroundColor Red
                 Write-Host "  Error: $($error.Error)" -ForegroundColor Red
            }
        }

        # Export KQL results to Excel
        if ($results.AllResources.Count -gt 0) {
            Export-ResultsToExcel -AllResources $results.AllResources -AssessmentFilePath $assessmentFilePath -ExcelFilePath $ExcelFilePath
        }
        else {
            Write-Log -Message "No KQL resources found to export." -Level "WARNING" # Changed from "No resources found"
            # Check if Assessment file was provided, if so, create the Excel file just for that
            if($assessmentFilePath -and (Test-Path $assessmentFilePath)){
                 Write-Log -Message "Exporting only Well-Architected Assessment as no KQL results were found." -Level "INFO"
                 Export-ResultsToExcel -AllResources @() -AssessmentFilePath $assessmentFilePath -ExcelFilePath $ExcelFilePath # Call with empty KQL results
            }
        }

        Write-Log -Message "Script execution completed." -Level "INFO"
        # Added final console messages for clarity
        Write-Host "`nScript execution finished." -ForegroundColor Green
        Write-Host "Results file: $ExcelFilePath" -ForegroundColor Green
        Write-Host "Log file: $logFile" -ForegroundColor Green


    }
    catch {
        Write-Log -Message "An error occurred: $_" -Level "ERROR"
        Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red # Added console error message
    }
    finally {
         # Added finally block to ensure this message always logs
         Write-Log -Message "Script execution finished run." -Level "INFO"
    }
}

# Execute the main function
CostRecommendations
