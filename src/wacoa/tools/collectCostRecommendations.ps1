# Ensure you replace the placeholder comment "[Your Repository URL or Update Instructions]"
# in the Check-ScriptVersion function with the actual link or instructions for users.

Function CostRecommendations {
    param (
        [string]$subscriptionIds,
        [string]$resourceGroupName,
        [switch]$Verbose
    )


    $ScriptVersion = "1.0.0" 
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
                        $choice = $choice.ToLower().Trim()
                        if ($choice -eq 'c') {
                            Write-Host "-----------------------------------------------------------" -ForegroundColor Yellow
                            Write-Log -Message "User chose to continue with outdated version $CurrentVersion. Proceed with caution." -Level "WARNING"
                            Write-Host "Proceeding with current version $CurrentVersion..." -ForegroundColor Cyan
                            Write-Host "-----------------------------------------------------------" -ForegroundColor Yellow
                            Start-Sleep -Seconds 3 # Pause for user to read the message
                            return # Exit the function, script execution continues
                        }
                        elseif ($choice -eq 's') {
                            Write-Log -Message "User chose to stop and download the latest version ($latestVersionString)." -Level "INFO"
                            Write-Host "`nTo download the latest version, please run the following command:" -ForegroundColor Green
                            Write-Host "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/microsoft/finops-toolkit/main/src/wacoa/tools/CollectCostRecommendations.ps1' -OutFile 'CollectCostRecommendations.ps1'" -ForegroundColor Cyan
                            Write-Host "`nScript execution stopped. Please download the latest version and run it again." -ForegroundColor Yellow
                            exit # Stop the entire script execution
                        }
                        else {
                            Write-Host "Invalid input. Please enter 'C' to Continue or 'S' to Stop." -ForegroundColor Red
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
            # Check if module is already imported before trying to import again
            if (-not (Get-Module -Name $module -ErrorAction SilentlyContinue)) {
                Import-Module -Name $module -ErrorAction Stop
                Write-Log -Message "Imported module: $module" -Level "INFO"
            } else {
                 Write-Log -Message "Module '$module' is already imported." -Level "DEBUG"
            }
        }
    }

    # Function to authenticate to Azure
    function Connect-ToAzure {
        try {
            # Check context before attempting Connect-AzAccount
            $context = Get-AzContext -ErrorAction SilentlyContinue # Use SilentlyContinue first
            if (-not $context) {
                Write-Log -Message "No active Azure context found. Logging into Azure..." -Level "INFO"
                Connect-AzAccount -ErrorAction Stop
                # Re-check context after connection attempt
                $context = Get-AzContext -ErrorAction Stop
                Write-Log -Message "Logged into Azure successfully. Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level "INFO"
            }
            else {
                Write-Log -Message "Already logged into Azure. Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level "INFO"
            }
        }
        catch {
            Write-Log -Message "Failed to log into Azure or verify context: $_" -Level "ERROR"
            throw # Re-throw the error to stop the script if connection fails
        }
    }

    # Function to download a GitHub folder and its contents
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
            # Use timeout and basic parsing for robustness
            Invoke-WebRequest -Uri $repoUrl -OutFile $zipFilePath -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop # Increased timeout for larger files
        }
        catch {
            Write-Log -Message "Failed to download zip file: $_" -Level "ERROR"
            throw
        }

        # Extract the zip file
        Write-Log -Message "Extracting zip file to: $Destination" -Level "INFO"
        try {
            # Use -Force to overwrite existing files if necessary (e.g., during re-download)
            Expand-Archive -Path $zipFilePath -DestinationPath $Destination -Force -ErrorAction Stop
        }
        catch {
            Write-Log -Message "Failed to extract zip file: $_" -Level "ERROR"
            throw
        }

        # Clean up the temporary zip file
        Remove-Item -Path $zipFilePath -Force -ErrorAction SilentlyContinue # Use SilentlyContinue for cleanup
        Write-Log -Message "Download and extraction completed successfully." -Level "INFO"
    }

    # Function to read cached scope
    function Read-CachedScope {
        $cacheFilePath = Join-Path $PSScriptRoot 'ScopeCache.txt'
        if (Test-Path -Path $cacheFilePath) {
            try {
                $cachedScope = Get-Content -Path $cacheFilePath -Raw | ConvertFrom-Json -ErrorAction Stop
                return $cachedScope
            }
            catch {
                Write-Log -Message "Failed to read or parse scope cache file '$cacheFilePath': $_. Ignoring cache." -Level "WARNING"
                return $null
            }
        }
        return $null
    }

    # Function to write scope to cache
    function Write-CachedScope {
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Scope
        )
        $cacheFilePath = Join-Path $PSScriptRoot 'ScopeCache.txt'
        try {
             $Scope | ConvertTo-Json | Set-Content -Path $cacheFilePath -ErrorAction Stop
        }
        catch {
            Write-Log -Message "Failed to write scope cache file '$cacheFilePath': $_." -Level "WARNING"
        }
    }

    # Function to prompt for scope selection
    function Get-Scope {
        # Check if there is a cached scope
        $cachedScope = Read-CachedScope

        if ($cachedScope) {
            Write-Host "A cached scope was found from the last run:" -ForegroundColor Cyan
            Write-Host "Scope Type: $($cachedScope.ScopeType)" -ForegroundColor Cyan
            Write-Host "Scope Value: $($cachedScope.ScopeValue)" -ForegroundColor Cyan

            # Loop until valid input is received
            while ($true) {
                $reuseScope = Read-Host "Would you like to reuse the same scope? (Yes/No or Y/N)"
                if ($reuseScope -ne $null) {
                    $reuseScope = $reuseScope.ToLower().Trim()
                    if ($reuseScope -in ('yes', 'y')) {
                        Write-Log -Message "Reusing cached scope: $($cachedScope.ScopeType) - $($cachedScope.ScopeValue)" -Level "INFO"
                        # Return the structure expected by the rest of the script
                        return @{
                            SubscriptionIds   = $cachedScope.SubscriptionIds
                            ResourceGroupName = $cachedScope.ResourceGroupName
                        }
                    }
                    elseif ($reuseScope -in ('no', 'n')) {
                        Write-Log -Message "User opted not to reuse the cached scope. Proceeding with new scope selection." -Level "INFO"
                        Remove-Item -Path (Join-Path $PSScriptRoot 'ScopeCache.txt') -ErrorAction SilentlyContinue
                        break # Exit loop to proceed with new selection
                    }
                    else {
                        Write-Host "Invalid input. Please enter 'Yes', 'No', 'Y', or 'N'." -ForegroundColor Red
                    }
                } else {
                     Write-Host "Input cannot be empty. Please enter 'Yes', 'No', 'Y', or 'N'." -ForegroundColor Red
                }
            }
        }

        # Prompt for new scope selection
        Write-Host "`nSelect the scope for the script:" -ForegroundColor Cyan
        Write-Host "1. Entire environment (all subscriptions accessible)."
        Write-Host "2. Specific subscription(s)."
        Write-Host "3. Specific resource group (requires subscription ID)."

        $scope = $null # Initialize scope variable

        while ($scope -eq $null) {
            $choice = Read-Host "Enter your choice (1, 2, or 3)"
            switch ($choice) {
                '1' {
                    Write-Log -Message "Running script across the entire environment (all accessible subscriptions)." -Level "INFO"
                    $scope = @{
                        ScopeType         = "EntireEnvironment"
                        ScopeValue        = "EntireEnvironment"
                        SubscriptionIds   = $null # Explicitly null for entire environment
                        ResourceGroupName = $null # Explicitly null
                    }
                }
                '2' {
                    $subscriptionIdsInput = Read-Host "Enter the subscription ID(s), separated by commas"
                    # Validate input (basic check for non-empty)
                    if ([string]::IsNullOrWhiteSpace($subscriptionIdsInput)) {
                        Write-Host "Subscription ID(s) cannot be empty." -ForegroundColor Red
                        continue # Re-prompt
                    }
                    $subscriptionIds = ($subscriptionIdsInput -split ',').Trim() -join ',' # Trim whitespace from each ID
                    Write-Log -Message "Filtering by subscription ID(s): $subscriptionIds" -Level "INFO"
                    $scope = @{
                        ScopeType         = "SubscriptionIDs"
                        ScopeValue        = $subscriptionIds # Store the comma-separated string
                        SubscriptionIds   = $subscriptionIds
                        ResourceGroupName = $null # Explicitly null
                    }
                }
                '3' {
                    $subscriptionIdInput = Read-Host "Enter the single subscription ID where the resource group resides"
                    # Validate input
                    if ([string]::IsNullOrWhiteSpace($subscriptionIdInput) -or $subscriptionIdInput -match ',') {
                        Write-Host "Please enter a single, valid subscription ID." -ForegroundColor Red
                        continue # Re-prompt
                    }
                    $subscriptionIds = $subscriptionIdInput.Trim() # Ensure no extra spaces

                    $resourceGroupNameInput = Read-Host "Enter the resource group name"
                    # Validate input
                    if ([string]::IsNullOrWhiteSpace($resourceGroupNameInput)) {
                        Write-Host "Resource group name cannot be empty." -ForegroundColor Red
                        continue # Re-prompt
                    }
                    $resourceGroupName = $resourceGroupNameInput.Trim() # Ensure no extra spaces

                    Write-Log -Message "Filtering by resource group '$resourceGroupName' in subscription '$subscriptionIds'." -Level "INFO"
                    $scope = @{
                        ScopeType         = "ResourceGroup"
                        ScopeValue        = "$subscriptionIds/$resourceGroupName" # More informative value
                        SubscriptionIds   = $subscriptionIds
                        ResourceGroupName = $resourceGroupName
                    }
                }
                default {
                    Write-Host "Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
                    # No throw here, loop will continue
                }
            }
        }

        # Cache the selected scope
        Write-CachedScope -Scope $scope

        # Return the structure needed by subsequent functions
        return @{
            SubscriptionIds   = $scope.SubscriptionIds
            ResourceGroupName = $scope.ResourceGroupName
        }
    }


    # Function to process KQL files
    function Process-KQLFiles {
        param (
            [string]$BasePath,
            [string]$SubscriptionIds,
            [string]$ResourceGroupName
        )
        $kqlFiles = Get-ChildItem -Path $BasePath -Recurse -Filter *.kql -ErrorAction SilentlyContinue # Use SilentlyContinue if path might not exist
        if (-not $kqlFiles) {
            Write-Log -Message "No KQL files found in path '$BasePath' or its subdirectories." -Level "WARNING"
            return @{ AllResources = @(); QueryErrors = @() } # Return empty structure
        }

        Write-Log -Message "Found $($kqlFiles.Count) KQL recommendation files." -Level "INFO"
        Write-Host "`nFound $($kqlFiles.Count) KQL recommendation files." -ForegroundColor Cyan

        $allResources = [System.Collections.Concurrent.ConcurrentBag[object]]::new() # Thread-safe collection
        $queryErrors = [System.Collections.Concurrent.ConcurrentBag[object]]::new()  # Thread-safe collection

        # Build subscription filter string safely
        $subscriptionFilterString = $null
        if (-not [string]::IsNullOrWhiteSpace($subscriptionIds)) {
            $formattedIds = $subscriptionIds -split ',' | ForEach-Object { "'$($_.Trim())'" }
            if ($formattedIds) {
                $subscriptionFilterString = $formattedIds -join ","
            }
        }

        # Use Invoke-Command for parallelism which handles using: scope better in PS7+
        # Requires Az.ResourceGraph module to be available in the runspace
        $Jobs = $kqlFiles | ForEach-Object {
            $file = $_
            $job = Invoke-Command -ScriptBlock {
                param($filePath, $subFilterString, $rgName, $logFilePath)

                # Local function for logging within the parallel task
                function Write-ParallelLog {
                    param (
                        [string]$Message,
                        [string]$Level = "INFO"
                    )
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $logMessage = "$timestamp [$Level] [$([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId)] $Message" # Add Runspace ID for clarity
                    Add-Content -Path $using:logFilePath -Value $logMessage -ErrorAction SilentlyContinue
                }

                $localResults = @()
                $localError = $null

                try {
                    Write-ParallelLog -Message "Processing file: $($using:filePath.Name)" -Level "DEBUG"
                    $query = Get-Content -LiteralPath $using:filePath.FullName -Raw -ErrorAction Stop

                    # Dynamically append filters
                    $filterClauses = @()
                    if ($using:subFilterString) {
                        $filterClauses += "subscriptionId in ($($using:subFilterString))"
                    }
                    # ARG uses 'resourceGroup' not 'x_ResourceGroupName' for filtering resources
                    if (-not [string]::IsNullOrWhiteSpace($using:rgName)) {
                         # Check if the query already projects resourceGroup, otherwise this filter might fail if applied after projection.
                         # This is a basic check; complex queries might need smarter injection.
                         # Assuming base queries select '*', 'properties', or explicitly 'resourceGroup'.
                        $filterClauses += "resourceGroup =~ '$($using:rgName)'" # Use case-insensitive match
                    }

                    if ($filterClauses.Count -gt 0) {
                        # Find a suitable place to inject 'where' or append using '| where'
                        # Simple approach: append if no 'where' is obviously present before a final projection/summarize
                        # More robust: Parse query structure (complex)
                        # Safest simple approach: append with '| where'
                        $query += " | where " + ($filterClauses -join ' and ')
                    }


                    Write-ParallelLog -Message "Executing query for $($using:filePath.Name): $query" -Level "DEBUG"

                    # Execute the query using Azure Resource Graph with pagination
                    $currentResult = Search-AzGraph -Query $query -First 1000 -ErrorAction Stop
                    if ($currentResult) { $localResults += $currentResult }

                    while ($currentResult -ne $null -and $currentResult.SkipToken) {
                        Write-ParallelLog -Message "Fetching next page for $($using:filePath.Name)..." -Level "DEBUG"
                        $currentResult = Search-AzGraph -Query $query -SkipToken $currentResult.SkipToken -First 1000 -ErrorAction Stop
                        if ($currentResult) { $localResults += $currentResult }
                    }

                    Write-ParallelLog -Message "Completed query for $($using:filePath.Name), found $($localResults.Count) resources." -Level "DEBUG"
                    return @{ Success = $true; Data = $localResults }
                }
                catch {
                    $errorMessage = "Query failed for file '$($using:filePath.FullName)': $($_.Exception.Message)"
                    Write-ParallelLog -Message $errorMessage -Level "ERROR"
                    Write-ParallelLog -Message "Failed Query: $query" -Level "ERROR"
                    return @{ Success = $false; Error = $errorMessage; Query = $query }
                }
            } -ArgumentList $file.FullName, $subscriptionFilterString, $resourceGroupName, $logFile -HideComputerName -ThrottleLimit 5 # Adjust ThrottleLimit as needed
            @{ Job = $job; File = $file } # Keep track of which job corresponds to which file
        }

        # Wait for all jobs and collect results
        foreach ($jobInfo in $Jobs) {
            Wait-Job -Job $jobInfo.Job
            $output = Receive-Job -Job $jobInfo.Job

            if ($output.Success) {
                # Add results to the concurrent bag
                if ($output.Data) {
                    $output.Data | ForEach-Object { $allResources.Add($_) }
                }
            } else {
                # Add errors to the concurrent bag
                $queryErrors.Add(@{
                    File = $jobInfo.File.FullName
                    Error = $output.Error
                    Query = $output.Query
                })
            }
            Remove-Job -Job $jobInfo.Job # Clean up job object
        }


        Write-Log -Message "Found $($allResources.Count) KQL-based recommendations in the environment." -Level "INFO"
        Write-Host "Found $($allResources.Count) KQL-based recommendations in the environment." -ForegroundColor Cyan

        # Convert concurrent bags back to regular arrays for return
        return @{
            AllResources = $allResources.ToArray()
            QueryErrors  = $queryErrors.ToArray()
        }
    }


    # Function to get Assessment file path
    function Get-FilePath {
        # Check if running in a non-interactive environment or ISE where Forms dialog won't work
        if (-not $env:PSModulePath -or $Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows PowerShell ISE') {
             Write-Log -Message "Graphical file browser not supported in this host. Please provide the full path." -Level "WARNING"
             $filePath = Read-Host "Enter the full path to the Well-Architected Cost Optimization Assessment CSV file"
             if (Test-Path $filePath -PathType Leaf) {
                 return $filePath
             } else {
                 Write-Log -Message "File not found at specified path: $filePath" -Level "ERROR"
                 return $null
             }
        }

        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
            $fileBrowser.InitialDirectory = [Environment]::GetFolderPath('Desktop') # Default to Desktop
            $fileBrowser.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*" # Filter for CSV files
            $fileBrowser.Title = "Select the Well-Architected Cost Optimization Assessment File"

            # Show the file browser dialog
            # Running this on the STA thread if possible
            $thread = [System.Threading.Thread]::CurrentThread
            if ($thread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
                Write-Log -Message "Attempting to show dialog on STA thread..." -Level "DEBUG"
                $staThread = [System.Threading.Thread]::New({
                    param($dialog)
                    $script:dialogResult = $dialog.ShowDialog() # Use script scope to pass result out
                })
                $staThread.SetApartmentState([System.Threading.ApartmentState]::STA)
                $staThread.Start($fileBrowser) # Pass dialog as argument
                $staThread.Join() # Wait for the dialog thread to complete

                if ($script:dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
                    return $fileBrowser.FileName
                } else {
                    return $null
                }
            } else {
                 # Already on STA thread
                 if ($fileBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                     return $fileBrowser.FileName
                 } else {
                     return $null
                 }
            }
        } catch {
            Write-Log -Message "Could not display graphical file browser: $_. Please provide the full path." -Level "WARNING"
            $filePath = Read-Host "Enter the full path to the Well-Architected Cost Optimization Assessment CSV file"
            if (Test-Path $filePath -PathType Leaf) {
                return $filePath
            } else {
                Write-Log -Message "File not found at specified path: $filePath" -Level "ERROR"
                return $null
            }
        } finally {
            # Clean up script scope variable if used
            if (Get-Variable -Name 'script:dialogResult' -ErrorAction SilentlyContinue) {
                Remove-Variable -Name 'script:dialogResult' -Scope Script
            }
        }
    }

    # Function to process CustomCost folder YAML files without ARG validation
    function Process-CustomCostRecommendations {
        param (
            [string]$BasePath # Path to the root folder containing 'azure-resources' or similar structure
        )

        # Define possible CustomCost folder paths relative to BasePath
        $customCostPath1 = Join-Path $BasePath "CustomCost" # If BasePath is directly 'azure-resources'
        $customCostPath2 = Join-Path $BasePath "azure-resources\CustomCost" # If BasePath is parent of 'azure-resources'

        # Determine the correct path
        $foundPath = $null
        if (Test-Path -Path $customCostPath1 -PathType Container) {
            $foundPath = $customCostPath1
            Write-Log -Message "Found CustomCost folder at: $customCostPath1" -Level "INFO"
        }
        elseif (Test-Path -Path $customCostPath2 -PathType Container) {
            $foundPath = $customCostPath2
            Write-Log -Message "Found CustomCost folder at: $customCostPath2" -Level "INFO"
        }
        else {
            Write-Log -Message "CustomCost folder not found at expected locations relative to '$BasePath'." -Level "WARNING"
            return @() # Return empty array if folder not found
        }

        # Find all YAML files in the found CustomCost folder
        $yamlFiles = Get-ChildItem -Path $foundPath -Filter *.yaml -ErrorAction SilentlyContinue
        if ($yamlFiles.Count -eq 0) {
            Write-Log -Message "No YAML files found in CustomCost folder '$foundPath'." -Level "WARNING"
            return @()
        }

        Write-Log -Message "Found $($yamlFiles.Count) YAML files in CustomCost folder '$foundPath'." -Level "INFO"
        Write-Host "Found $($yamlFiles.Count) YAML files in CustomCost folder." -ForegroundColor Cyan

        # Initialize an array to store CustomCost recommendations
        $customCostData = @()

        foreach ($file in $yamlFiles) {
            try {
                # Read the YAML file content
                $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop

                # Convert YAML to PowerShell object(s)
                # Handle potential multiple documents in one YAML file
                $yamlObjects = $yamlContent | ConvertFrom-Yaml -ErrorAction Stop -AllDocuments

                if ($yamlObjects) {
                    # Ensure we handle single or multiple documents correctly
                    if ($yamlObjects -is [array]) {
                        $customCostData += $yamlObjects
                    } else {
                        $customCostData += @($yamlObjects)
                    }
                    Write-Log -Message "Successfully processed CustomCost file: $($file.Name)" -Level "DEBUG"
                } else {
                     Write-Log -Message "YAML file '$($file.FullName)' appears empty or could not be parsed." -Level "WARNING"
                }
            }
            catch {
                Write-Log -Message "Failed to read or parse CustomCost YAML file '$($file.FullName)': $_" -Level "ERROR"
            }
        }

        Write-Log -Message "Processed $($customCostData.Count) CustomCost recommendations." -Level "INFO"
        return $customCostData
    }


    # Function to process YAML files (excluding CustomCost) and validate against scope
    function Manual-Validations {
        param (
            [string]$BasePath, # Path to the root folder containing 'azure-resources' or similar
            [string]$ExcelFilePath, # Path to the Excel file
            [string]$SubscriptionIds, # Subscription IDs to filter by (comma-separated string or null)
            [string]$ResourceGroupName  # Resource group name to filter by (string or null)
        )

        # Base path for YAML files (assuming they are inside 'azure-resources')
        $yamlBasePath = Join-Path $BasePath "azure-resources"
        if (-not (Test-Path -Path $yamlBasePath -PathType Container)) {
             # Fallback if BasePath is already 'azure-resources'
             if (Test-Path -Path $BasePath -PathType Container) {
                 $yamlBasePath = $BasePath
             } else {
                Write-Log -Message "YAML base path '$yamlBasePath' or '$BasePath' not found." -Level "ERROR"
                return # Cannot proceed
             }
        }
        Write-Log -Message "Using YAML base path: $yamlBasePath" -Level "DEBUG"

        try {
            # Get CustomCost recommendations first (no validation needed relative to BasePath)
            $customCostRecommendations = Process-CustomCostRecommendations -BasePath $BasePath # Pass the original base path
            Write-Log -Message "Found $($customCostRecommendations.Count) CustomCost recommendations (always included)." -Level "INFO"

            # Import the YAML files for validation (excluding the CustomCost folder itself)
            # Need to find the correct CustomCost path again to exclude it
            $customCostPath1 = Join-Path $BasePath "CustomCost"
            $customCostPath2 = Join-Path $BasePath "azure-resources\CustomCost"
            $excludePath = $null
            if (Test-Path -Path $customCostPath1 -PathType Container) { $excludePath = $customCostPath1 }
            elseif (Test-Path -Path $customCostPath2 -PathType Container) { $excludePath = $customCostPath2 }

            $yamlFilesToValidate = Get-ChildItem -Path $yamlBasePath -Recurse -Filter *.yaml -ErrorAction SilentlyContinue
            if ($excludePath) {
                # Filter out files under the exclude path
                 $yamlFilesToValidate = $yamlFilesToValidate | Where-Object { $_.FullName -notlike "$excludePath\*" }
            }

            if ($yamlFilesToValidate.Count -eq 0) {
                Write-Log -Message "No other YAML files found for validation outside CustomCost folder." -Level "INFO"
            } else {
                Write-Log -Message "Found $($yamlFilesToValidate.Count) YAML files for potential validation." -Level "INFO"
            }

            if($yamlFilesToValidate.Count -eq 0 -and $customCostRecommendations.Count -eq 0) {
                 Write-Log -Message "No manual recommendations (CustomCost or validated YAML) found to process." -Level "INFO"
                 return # Nothing to do
            }

            # --- Validation Logic (only run if there are YAML files to validate) ---
            $validatedYamlData = @()
            if ($yamlFilesToValidate.Count -gt 0) {
                Write-Log -Message "Starting validation for $($yamlFilesToValidate.Count) YAML files..." -Level "INFO"

                # Extract unique resource types from the YAML files to validate
                $uniqueResourceTypes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase) # Case-insensitive set
                $yamlFileObjects = @{} # Store parsed objects to avoid re-parsing

                foreach ($file in $yamlFilesToValidate) {
                    try {
                        $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
                        # Use -AllDocuments in case a file contains multiple definitions
                        $yamlObjectList = $yamlContent | ConvertFrom-Yaml -ErrorAction Stop -AllDocuments

                        if($yamlObjectList){
                            $fileObjects = @() # Store potentially multiple objects from one file
                            # Handle single vs multiple documents
                            if ($yamlObjectList -is [array]) {
                                $fileObjects = $yamlObjectList
                            } else {
                                $fileObjects = @($yamlObjectList)
                            }

                            # Store for later use
                            $yamlFileObjects[$file.FullName] = $fileObjects

                            # Extract resource types
                            foreach ($yamlObject in $fileObjects) {
                                if ($yamlObject.PSObject.Properties['recommendationResourceType'] -ne $null -and -not [string]::IsNullOrWhiteSpace($yamlObject.recommendationResourceType)) {
                                    # Split by space and add each type to the hash set
                                    $yamlObject.recommendationResourceType -split ' ' | ForEach-Object {
                                        if (-not [string]::IsNullOrWhiteSpace($_)) { $uniqueResourceTypes.Add($_.Trim()) | Out-Null }
                                    }
                                }
                            }
                        } else {
                             Write-Log -Message "Could not parse YAML file '$($file.FullName)' for resource types." -Level "WARNING"
                        }
                    } catch {
                        Write-Log -Message "Failed to read/parse YAML file '$($file.FullName)' during resource type extraction: $_" -Level "ERROR"
                    }
                }

                if ($uniqueResourceTypes.Count -eq 0) {
                    Write-Log -Message "No 'recommendationResourceType' found in any validation YAML files." -Level "WARNING"
                } else {
                    Write-Log -Message "Unique resource types found in validation YAMLs: $($uniqueResourceTypes -join ', ')" -Level "DEBUG"

                    # Construct ARG query parts
                    $resourceTypeFilter = ($uniqueResourceTypes | ForEach-Object { "type =~ '$_'" }) -join ' or '
                    $scopeFilters = @()
                    if (-not [string]::IsNullOrWhiteSpace($SubscriptionIds)) {
                        $formattedSubs = $SubscriptionIds -split ',' | ForEach-Object { "'$($_.Trim())'" }
                        if ($formattedSubs) {
                            $scopeFilters += "subscriptionId in ($($formattedSubs -join ','))"
                        }
                    }
                    if (-not [string]::IsNullOrWhiteSpace($ResourceGroupName)) {
                        $scopeFilters += "resourceGroup =~ '$ResourceGroupName'"
                    }

                    # Build the final query to find *if* any relevant resources exist in scope
                    $query = "Resources"
                    $query += " | where ($resourceTypeFilter)" # Filter by types first
                    if ($scopeFilters.Count -gt 0) {
                        $query += " and ($($scopeFilters -join ' and '))" # Then filter by scope
                    }
                    $query += " | limit 1" # We only need to know if *at least one* exists
                    $query += " | project type" # Only need the type column for confirmation

                    Write-Log -Message "Querying Azure Resource Graph to check for existence of relevant resource types in scope." -Level "INFO"
                    Write-Log -Message "Existence Check Query: $query" -Level "DEBUG"

                    $resourceTypesInScope = try {
                         Search-AzGraph -Query $query -First 1 # Use -First 1, equivalent to limit 1
                    } catch {
                         Write-Log -Message "ARG query for resource type existence failed: $_. Cannot validate YAML recommendations against scope." -Level "ERROR"
                         $null # Indicate failure
                    }

                    # Use a HashSet for quick lookups of types found in scope
                    $typesFoundInScopeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                    if($resourceTypesInScope){
                         # The query returns the types of the resources found (up to the limit)
                         # We need to query again to get *all* unique types present
                         $queryAllTypes = "Resources"
                         $queryAllTypes += " | where ($resourceTypeFilter)"
                         if ($scopeFilters.Count -gt 0) {
                              $queryAllTypes += " and ($($scopeFilters -join ' and '))"
                         }
                         $queryAllTypes += " | summarize count() by type"
                         Write-Log -Message "Querying ARG for all unique relevant types in scope..." -Level "DEBUG"
                         Write-Log -Message "All Types Query: $queryAllTypes" -Level "DEBUG"

                         $allTypesResult = try { Search-AzGraph -Query $queryAllTypes -First 1000 } catch { Write-Log -Message "ARG query for all types failed: $_" -Level "WARNING"; $null }
                         if($allTypesResult){
                             $allTypesResult.type | ForEach-Object { $typesFoundInScopeSet.Add($_) | Out-Null }
                             Write-Log -Message "Resource types confirmed to exist in scope: $($typesFoundInScopeSet -join ', ')" -Level "INFO"
                         } else {
                              Write-Log -Message "Could not retrieve list of specific resource types present in scope." -Level "WARNING"
                         }
                    } else {
                        Write-Log -Message "No resources matching any specified types found within the selected scope. Skipping validation YAMLs." -Level "INFO"
                    }

                    # Now iterate through the *parsed* YAML objects and add them if their types exist in scope
                    if ($typesFoundInScopeSet.Count -gt 0) {
                         Write-Log -Message "Filtering YAML recommendations based on resource types found in scope..." -Level "DEBUG"
                         foreach ($filePath in $yamlFileObjects.Keys) {
                             foreach ($yamlObject in $yamlFileObjects[$filePath]) {
                                 $matchFound = $false
                                 if ($yamlObject.PSObject.Properties['recommendationResourceType'] -ne $null -and -not [string]::IsNullOrWhiteSpace($yamlObject.recommendationResourceType)) {
                                     $resourceTypesInYaml = $yamlObject.recommendationResourceType -split ' '
                                     foreach ($resourceType in $resourceTypesInYaml) {
                                         $trimmedType = $resourceType.Trim()
                                         if (-not [string]::IsNullOrWhiteSpace($trimmedType) -and $typesFoundInScopeSet.Contains($trimmedType)) {
                                             $matchFound = $true
                                             break # Found a match for this YAML object, no need to check other types in it
                                         }
                                     }
                                 } else {
                                     # If recommendationResourceType is missing or empty, should it be included?
                                     # Current logic: No, it needs a type to be validated. Add warning?
                                     Write-Log -Message "YAML object in '$filePath' lacks 'recommendationResourceType', cannot validate against scope." -Level "DEBUG"
                                 }

                                 if ($matchFound) {
                                     $validatedYamlData += $yamlObject
                                     Write-Log -Message "Validated YAML recommendation included from '$filePath' (Matched Type)." -Level "DEBUG"
                                 }
                             }
                         }
                         Write-Log -Message "Found $($validatedYamlData.Count) validated YAML recommendations matching resource types in scope." -Level "INFO"
                    } else {
                         # This condition is met if the ARG query ran but found 0 relevant types, or if the query failed.
                         Write-Log -Message "No matching resource types found in scope, or ARG query failed. No validation YAMLs will be included." -Level "INFO"
                    }
                }
            } # End of validation logic block

            # Combine validated recommendations with CustomCost recommendations
            $combinedData = $validatedYamlData + $customCostRecommendations
            Write-Log -Message "Total manual recommendations (CustomCost + Validated): $($combinedData.Count)" -Level "INFO"

            # Convert combined YAML data to a format suitable for Excel
            $excelData = $combinedData | ForEach-Object {
                # Handle potential missing properties gracefully
                $Tags = if ($_.PSObject.Properties['tags']) { $_.tags } else { $null }
                $LearnMoreLinks = if ($_.PSObject.Properties['learnMoreLink']) { $_.learnMoreLink } else { $null }

                [PSCustomObject]@{
                    Description                 = $_.PSObject.Properties['description']?.Value ?? ''
                    AcorlGuid                   = $_.PSObject.Properties['acorlGuid']?.Value ?? ''
                    RecommendationTypeId        = $_.PSObject.Properties['recommendationTypeId']?.Value ?? ''
                    RecommendationControl       = $_.PSObject.Properties['recommendationControl']?.Value ?? ''
                    RecommendationImpact        = $_.PSObject.Properties['recommendationImpact']?.Value ?? ''
                    RecommendationResourceType  = $_.PSObject.Properties['recommendationResourceType']?.Value ?? ''
                    RecommendationMetadataState = $_.PSObject.Properties['recommendationMetadataState']?.Value ?? ''
                    RemediationAction           = $_.PSObject.Properties['remediationAction']?.Value ?? ''
                    PotentialBenefits           = $_.PSObject.Properties['potentialBenefits']?.Value ?? ''
                    PgVerified                  = $_.PSObject.Properties['pgVerified']?.Value ?? '' # Consider converting to boolean if needed
                    PublishedToLearn            = $_.PSObject.Properties['publishedToLearn']?.Value ?? '' # Consider converting to boolean if needed
                    AutomationAvailable         = $_.PSObject.Properties['automationAvailable']?.Value ?? '' # Consider converting to boolean if needed
                    Tags                        = if ($Tags -is [array]) { $Tags -join '; ' } else { $Tags } # Join if it's an array
                    LearnMoreLink               = if ($LearnMoreLinks -is [array]) { ($LearnMoreLinks | ForEach-Object { if ($_.name -and $_.url) { "$($_.name): $($_.url)" } }) -join "; " } else { '' } # Handle array of links
                }
            }

            # Append YAML data to the Excel file
            if ($excelData.Count -gt 0) {
                Write-Log -Message "Appending $($excelData.Count) manual recommendations to the Excel file: $ExcelFilePath" -Level "INFO"
                # Ensure the Excel file exists or is created by a previous step (like Export-ResultsToExcel)
                # If Export-ResultsToExcel hasn't run yet, this might create the file
                try {
                    # Check if file exists to use -Append or not (Export-Excel handles creation)
                    $appendSwitch = if(Test-Path $ExcelFilePath) { $true } else { $false } # Not needed for Export-Excel >= 7
                    $excelData | Export-Excel -Path $ExcelFilePath -WorksheetName 'Manual Recommendations' -AutoSize -TableName 'ManualRecommendations' -TableStyle 'Light19' -ErrorAction Stop #-Append:$appendSwitch # Append parameter deprecated/implicit in newer versions
                    Write-Log -Message "Successfully appended manual recommendations." -Level "INFO"
                } catch {
                    Write-Log -Message "Failed to append manual recommendations to Excel file '$ExcelFilePath': $_" -Level "ERROR"
                }
            }
            else {
                Write-Log -Message "No manual recommendations (CustomCost or Validated) found to append to Excel." -Level "INFO"
            }
        }
        catch {
            Write-Log -Message "Error in Manual-Validations function: $_" -Level "ERROR"
            # Decide if this should be a throwing error or just log
            # throw # Uncomment if this failure should stop the script
        }
    }


    # Function to export Assessment results to Excel
    function Export-ResultsToExcel {
        param (
            [Parameter(Mandatory=$true)]
            [array]$AllResources, # KQL results

            [Parameter(Mandatory=$false)]
            [string]$AssessmentFilePath, # Optional WAF Assessment CSV path

            [Parameter(Mandatory=$true)]
            [string]$ExcelFilePath # Output Excel file path
        )

        # Export KQL results to Excel
        if ($AllResources -and $AllResources.Count -gt 0) {
            Write-Log -Message "Exporting $($AllResources.Count) KQL recommendations to Excel..." -Level "INFO"
            try {
                 $AllResources | Export-Excel -Path $ExcelFilePath -WorksheetName 'Recommendations' -AutoSize -TableName 'Table1' -TableStyle 'Light19' -ErrorAction Stop
                 Write-Log -Message "KQL Recommendations exported successfully to '$ExcelFilePath' (Sheet: Recommendations)." -Level "INFO"
            } catch {
                 Write-Log -Message "Failed to export KQL recommendations to Excel: $_" -Level "ERROR"
                 # Decide whether to continue if export fails
            }
        } else {
             Write-Log -Message "No KQL recommendations provided to export." -Level "WARNING"
             # Create an empty sheet maybe? Or ensure the file exists for potential manual recs?
             # Let's ensure the file path directory exists for potential later appends
             $excelDir = Split-Path $ExcelFilePath -Parent
             if (-not (Test-Path $excelDir)) { New-Item -ItemType Directory -Path $excelDir -ErrorAction SilentlyContinue | Out-Null }
             # Creating an empty file might interfere with Export-Excel logic, better let it handle creation.
        }


        # Add assessment data if provided
        if (-not [string]::IsNullOrWhiteSpace($AssessmentFilePath)) {
            if (Test-Path $AssessmentFilePath -PathType Leaf) {
                 Write-Log -Message "Importing Well-Architected Assessment from '$AssessmentFilePath'..." -Level "INFO"
                try {
                    $assessmentData = Import-Csv -Path $AssessmentFilePath -ErrorAction Stop
                    if ($assessmentData -and $assessmentData.Count -gt 0) {
                        Write-Log -Message "Appending Well-Architected Assessment data to '$ExcelFilePath' (Sheet: Well-Architected Assessment)." -Level "INFO"
                        $assessmentData | Export-Excel -Path $ExcelFilePath -WorksheetName 'Well-Architected Assessment' -AutoSize -TableName 'WAFAssessment' -TableStyle 'Light19' -ErrorAction Stop
                        Write-Log -Message "Successfully appended Well-Architected Assessment." -Level "INFO"
                    } else {
                         Write-Log -Message "Well-Architected Assessment file '$AssessmentFilePath' is empty or could not be read." -Level "WARNING"
                    }
                }
                catch {
                    Write-Log -Message "Failed to import or append the Well-Architected Cost Optimization assessment: $_" -Level "ERROR"
                }
            } else {
                 Write-Log -Message "Well-Architected Assessment file not found at specified path: $AssessmentFilePath. Skipping." -Level "WARNING"
            }
        } else {
             Write-Log -Message "No Well-Architected Assessment file path provided." -Level "DEBUG"
        }
    }

    # Main script execution
    try {
        # --- Start Log Message with Version ---
        Write-Log -Message "Starting script execution (Version $ScriptVersion)." -Level "INFO"

        # --- Perform Version Check ---
        Check-ScriptVersion -CurrentVersion $ScriptVersion -RemoteVersionUrl $RemoteVersionFileUrl

        # Check PowerShell Version (already checked at top level)

        # Install Modules (ErrorAction Stop inside function will halt here if needed)
        Install-AndImportModules -Modules @('Az.Accounts', 'Az.ResourceGraph', 'ImportExcel', 'powershell-yaml')

        # Connect to Azure (Throws error if connection fails)
        Connect-ToAzure

        # Set Working Directory and Download Recommendations
        $workingFolderPath = $PSScriptRoot
        # Set-Location is sometimes problematic in scripts, use Join-Path instead
        # Set-Location -Path $workingFolderPath
        Write-Log -Message "Script running from directory: $workingFolderPath" -Level "INFO"

        # Hardcoded GitHub repository zip URL for recommendations content
        # Ensure this is the correct link to the ZIP file containing KQL/YAML
        $repoZipUrl = "https://github.com/microsoft/finops-toolkit/raw/main/src/wacoa/tools/azure-resources.zip" # Assuming zip is in main branch now
        # Check if the old URL is still valid or if it moved
        # $repoZipUrl_old = "https://github.com/arthurclares/costbestpractices/raw/refs/heads/main/content/azure-resources.zip"


        # Define the destination directory for extracted content
        $tempDir = Join-Path $workingFolderPath "Temp" # Base temp directory
        $contentDir = Join-Path $tempDir "azure-resources" # Specific content directory

        # Download and extract the zip file if the content directory doesn't exist
        if (-not (Test-Path -Path $contentDir -PathType Container)) {
            Write-Log -Message "Recommendation content folder '$contentDir' not found. Downloading and extracting from '$repoZipUrl'." -Level "INFO"
            # Ensure Temp directory exists first
             if (-not (Test-Path -Path $tempDir -PathType Container)) {
                 New-Item -Path $tempDir -ItemType Directory -ErrorAction Stop | Out-Null
             }
             # Pass $tempDir as destination for extraction, Download function assumes zip extracts to a folder named 'azure-resources' inside it
             # Let's adjust Download-GitHubFolder slightly or ensure the zip structure matches assumption
             # Assuming the zip extracts its contents directly (not within a parent folder)
             # Modify destination for Download-GitHubFolder:
             $extractDestination = $tempDir # Extract into Temp, expecting 'azure-resources' folder to be created by Expand-Archive
             Download-GitHubFolder -RepoUrl $repoZipUrl -Destination $extractDestination # Pass the parent temp dir

             # Verify content directory exists after extraction
             if (-not (Test-Path -Path $contentDir -PathType Container)) {
                 Write-Log -Message "Expected content directory '$contentDir' not found after extraction. Please check the zip file structure and permissions." -Level "ERROR"
                 throw "Failed to prepare recommendation content."
             }
        }
        else {
            Write-Log -Message "Recommendation content folder '$contentDir' already exists. Skipping download." -Level "INFO"
        }

        # Prompt to include Well-Architected Cost Optimization assessment
        $assessmentFilePath = $null # Initialize
        while ($true) {
            $includeAssessment = Read-Host "Would you like to include the results of a Well-Architected Cost Optimization assessment? (Yes/No or Y/N)"
            if ($includeAssessment -ne $null) {
                $includeAssessment = $includeAssessment.ToLower().Trim()
                if ($includeAssessment -in ('yes', 'y')) {
                    $assessmentFilePath = Get-FilePath # Calls the file browser/prompt function
                    if (-not $assessmentFilePath) {
                        Write-Log -Message "No file selected or file path invalid. Skipping Well-Architected Cost Optimization assessment." -Level "WARNING"
                    } else {
                         Write-Log -Message "Selected assessment file: $assessmentFilePath" -Level "INFO"
                    }
                    break # Exit loop
                }
                elseif ($includeAssessment -in ('no', 'n')) {
                    Write-Log -Message "Skipping Well-Architected Cost Optimization assessment inclusion." -Level "INFO"
                    break # Exit loop
                }
                else {
                    Write-Host "Invalid input. Please enter 'Yes', 'No', 'Y', or 'N'." -ForegroundColor Red
                }
            } else {
                 Write-Host "Input cannot be empty. Please enter 'Yes', 'No', 'Y', or 'N'." -ForegroundColor Red
            }
        }


        # Prompt for scope selection
        $scope = Get-Scope # Returns hashtable with SubscriptionIds and ResourceGroupName
        $subscriptionIds = $scope.SubscriptionIds   # Can be null, comma-separated string
        $resourceGroupName = $scope.ResourceGroupName # Can be null or string

        # Define the Excel file path
        $ExcelFilePath = Join-Path $workingFolderPath ('ACORL-File-' + (Get-Date -Format 'yyyy-MM-dd-HH-mm') + '.xlsx')
        Write-Log -Message "Output Excel file will be: $ExcelFilePath" -Level "INFO"

        # --- Run KQL Processing First ---
        # Process KQL files based on scope
        $kqlResults = Process-KQLFiles -BasePath $contentDir -SubscriptionIds $subscriptionIds -ResourceGroupName $resourceGroupName # Use contentDir

        # --- Export KQL and Optional WAF Assessment Results ---
        # This creates the Excel file and adds the first two sheets if data exists
        Export-ResultsToExcel -AllResources $kqlResults.AllResources -AssessmentFilePath $assessmentFilePath -ExcelFilePath $ExcelFilePath

        # --- Run Manual/YAML Checks ---
        # Prompt user if they want to run these checks
        $runManualChecksChoice = $null
        while ($true) {
            $runManualChecksChoice = Read-Host "Would you like to run manual checks (process YAML recommendations)? (Yes/No or Y/N)"
            if($runManualChecksChoice -ne $null){
                 $runManualChecksChoice = $runManualChecksChoice.ToLower().Trim()
                 if ($runManualChecksChoice -in ('yes', 'y', 'no', 'n')) { break }
                 else { Write-Host "Invalid input. Please enter 'Yes', 'No', 'Y', or 'N'." -ForegroundColor Red }
            } else { Write-Host "Input cannot be empty." -ForegroundColor Red}
        }


        if ($runManualChecksChoice -in ('yes', 'y')) {
            Write-Log -Message "Running manual checks (processing YAML files)..." -Level "INFO"
            # Process YAML files (CustomCost + Validated) and append to the *existing* Excel file
            Manual-Validations -BasePath $tempDir -ExcelFilePath $ExcelFilePath -SubscriptionIds $subscriptionIds -ResourceGroupName $resourceGroupName # Pass tempDir as BasePath
        }
        else {
            Write-Log -Message "Skipping manual checks (YAML processing) as per user request." -Level "INFO"
        }

        # --- Summarize and Display KQL Results ---
        if ($kqlResults.AllResources -and $kqlResults.AllResources.Count -gt 0) {
            Write-Host "`nKQL Recommendations Summary:" -ForegroundColor Cyan
            try {
                # Grouping requires consistent property names. Verify 'x_RecommendationImpact', 'x_ResourceType' exist.
                # Use Select-Object to handle potential missing properties during grouping
                $summary = $kqlResults.AllResources |
                    Select-Object @{N='Impact'; E={$_.x_RecommendationImpact}}, @{N='ResourceType'; E={$_.x_ResourceType}} |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Impact) -and -not [string]::IsNullOrWhiteSpace($_.ResourceType) } |
                    Group-Object -Property Impact, ResourceType |
                    Select-Object @{Name = 'Impact'; Expression = {$_.Values[0]}},
                                  @{Name = 'ResourceType'; Expression = {$_.Values[1]}},
                                  @{Name = 'ImpactedResources'; Expression = {$_.Count}} |
                    Sort-Object -Property Impact, ResourceType

                # Display the summary table
                $summary | Format-Table -AutoSize
                Write-Log -Message "Displayed KQL recommendations summary." -Level "INFO"

            } catch {
                 Write-Log -Message "Could not generate KQL recommendations summary: $_. Property names might be inconsistent (e.g., 'x_RecommendationImpact', 'x_ResourceType')." -Level "WARNING"
                 Write-Host "Could not generate KQL recommendations summary due to error." -ForegroundColor Yellow
            }
        } else {
             Write-Host "`nNo KQL recommendations found to summarize." -ForegroundColor Yellow
             Write-Log -Message "No KQL recommendations found to summarize." -Level "INFO"
        }

        # Display KQL query errors, if any
        if ($kqlResults.QueryErrors.Count -gt 0) {
            Write-Host "`nThe following $($kqlResults.QueryErrors.Count) KQL query errors occurred:" -ForegroundColor Red
            foreach ($error in $kqlResults.QueryErrors) {
                Write-Host "- File: $($error.File)" -ForegroundColor Red
                Write-Host "  Error: $($error.Error)" -ForegroundColor Red
                 # Log the error details as well
                 Write-Log -Message "KQL Query Error - File: $($error.File), Error: $($error.Error)" -Level "ERROR"
                 # Optionally log the failed query if needed (can be long)
                 # Write-Log -Message "Failed KQL Query: $($error.Query)" -Level "DEBUG"
            }
        }

        # Final completion message
        Write-Log -Message "Script execution completed." -Level "INFO"
        Write-Host "`nScript execution finished. Results are in: $ExcelFilePath" -ForegroundColor Green
        Write-Host "Log file is located at: $logFile" -ForegroundColor Green

    }
    catch {
        # Catch any unhandled exceptions from the main block
        Write-Log -Message "A critical error occurred during script execution: $_" -Level "ERROR"
        Write-Host "A critical error occurred: $($_.Exception.Message)" -ForegroundColor Red
        # Optionally re-throw if needed for external error handling
        # throw
    }
    finally{
         Write-Log -Message "Script execution finished." -Level "INFO" # Log end even if errors occurred
    }
}

# Execute the main function
CostRecommendations
