Function CostRecommendations {
    param (
        [string]$subscriptionIds,
        [string]$resourceGroupName,
        [switch]$Verbose
    )

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
            Import-Module -Name $module -ErrorAction Stop
            Write-Log -Message "Imported module: $module" -Level "INFO"
        }
    }

    # Function to authenticate to Azure
    function Connect-ToAzure {
        try {
            $context = Get-AzContext -ErrorAction Stop
            if (-not $context) {
                Write-Log -Message "Logging into Azure..." -Level "INFO"
                Connect-AzAccount -ErrorAction Stop
                Write-Log -Message "Logged into Azure successfully." -Level "INFO"
            }
            else {
                Write-Log -Message "Already logged into Azure." -Level "INFO"
            }
        }
        catch {
            Write-Log -Message "Failed to log into Azure: $_" -Level "ERROR"
            throw
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
        Remove-Item -Path $zipFilePath -Force -ErrorAction Stop
        Write-Log -Message "Download and extraction completed successfully." -Level "INFO"
    }

    # Function to read cached scope
    function Read-CachedScope {
        $cacheFilePath = Join-Path $PSScriptRoot 'ScopeCache.txt'
        if (Test-Path -Path $cacheFilePath) {
            $cachedScope = Get-Content -Path $cacheFilePath -Raw | ConvertFrom-Json
            return $cachedScope
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
        $Scope | ConvertTo-Json | Set-Content -Path $cacheFilePath -ErrorAction Stop
    }

    # Function to prompt for scope selection
    function Get-Scope {
        # Check if there is a cached scope
        $cachedScope = Read-CachedScope

        if ($cachedScope) {
            Write-Host "A cached scope was found from the last run:" -ForegroundColor Cyan
            Write-Host "Scope Type: $($cachedScope.ScopeType)" -ForegroundColor Cyan
            Write-Host "Scope Value: $($cachedScope.ScopeValue)" -ForegroundColor Cyan

            $reuseScope = Read-Host "Would you like to reuse the same scope? (Yes/No or Y/N)"
            $reuseScope = $reuseScope.ToLower()

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
            1 {
                Write-Log -Message "Running script across the entire environment (no filters)." -Level "INFO"
                $scope = @{
                    ScopeType         = "EntireEnvironment"
                    ScopeValue        = "EntireEnvironment"
                    SubscriptionIds   = $null
                    ResourceGroupName = $null
                }
            }
            2 {
                $subscriptionIds = Read-Host "Enter the subscription ID(s), separated by commas"
                Write-Log -Message "Filtering by subscription ID(s): $subscriptionIds" -Level "INFO"
                $scope = @{
                    ScopeType         = "SubscriptionIDs"
                    ScopeValue        = $subscriptionIds
                    SubscriptionIds   = $subscriptionIds
                    ResourceGroupName = $null
                }
            }
            3 {
                $subscriptionIds = Read-Host "Enter the subscription ID where the resource group resides"
                $resourceGroupName = Read-Host "Enter the resource group name"
                Write-Log -Message "Filtering by resource group '$resourceGroupName' in subscription '$subscriptionIds'." -Level "INFO"
                $scope = @{
                    ScopeType         = "ResourceGroup"
                    ScopeValue        = $resourceGroupName
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

    # Function to process KQL files
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
    
        # Build subscription filter outside parallel block
        $subscriptionFilter = $null
        if ($subscriptionIds) {
            $subscriptionList = $subscriptionIds -split ',' | ForEach-Object { "'$($_.Trim())'" }
            $subscriptionFilter = $subscriptionList -join ","
        }

        $kqlFiles | ForEach-Object -Parallel {
            $file = $_
            $subscriptionFilter = $using:subscriptionFilter
            $resourceGroupName = $using:ResourceGroupName
            
            # Create a local function for logging within the parallel block
            function Write-ParallelLog {
                param (
                    [string]$Message,
                    [string]$Level = "INFO"
                )
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $logMessage = "$timestamp [$Level] $Message"
                $logFile = $using:logFile
                Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
            }
            
            try {
                $query = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
    
                # Dynamically append filters to the query based on scope
                if ($subscriptionFilter -and $resourceGroupName) {
                    $query = "$query | where SubAccountId in ($subscriptionFilter) and x_ResourceGroupName == '$resourceGroupName'"
                }
                elseif ($subscriptionFilter) {
                    $query = "$query | where SubAccountId in ($subscriptionFilter)"
                }
    
                # Execute the query using Azure Resource Graph
                try {
                    $result = Search-AzGraph -Query $query -First 1000 -ErrorAction Stop
                    $fileResources = @($result)
                    while ($result.SkipToken) {
                        $result = Search-AzGraph -Query $query -SkipToken $result.SkipToken -First 1000 -ErrorAction Stop
                        $fileResources += $result
                    }
                    return $fileResources
                }
                catch {
                    $errorMessage = "Query failed for file '$($file.FullName)': $($_.Exception.Message)"
                    Write-ParallelLog -Message $errorMessage -Level "ERROR"
                    return @{ 
                        Error = $errorMessage
                        Query = $query
                    }
                }
            }
            catch {
                $errorMessage = "An error occurred while processing file '$($file.FullName)': $_"
                Write-ParallelLog -Message $errorMessage -Level "ERROR"
                return @{
                    Error = $errorMessage
                }
            }
        } -ThrottleLimit 5 -AsJob | Receive-Job -Wait -AutoRemoveJob | ForEach-Object {
            if ($_.Error) {
                $queryErrors += $_
            }
            else {
                $allResources += $_
            }
        }
    
        # Log query errors outside of the parallel block
        foreach ($error in $queryErrors) {
            Write-Log -Message $error.Error -Level "ERROR"
            if ($error.Query) {
                Write-Log -Message "Query: $($error.Query)" -Level "ERROR"
            }
        }
    
        Write-Log -Message "Found $($allResources.Count) recommendations in the environment." -Level "INFO"
        Write-Host "Found $($allResources.Count) recommendations in the environment." -ForegroundColor Cyan
    
        return @{
            AllResources = $allResources
            QueryErrors  = $queryErrors
        }
    }
    
    # Function to get Assessment file path
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

# Function to process CustomCost folder YAML files without ARG validation
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
    $yamlFiles = Get-ChildItem -Path $foundPath -Filter *.yaml -ErrorAction Stop
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
                $yamlObjects = $yamlContent | ConvertFrom-Yaml
                
                # Process each YAML object
                foreach ($yamlObject in @($yamlObjects)) {
                    $customCostData += $yamlObject
                }
                
                Write-Log -Message "Successfully processed CustomCost file: $($file.Name)" -Level "INFO"
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

    # Function to process YAML files and append them to the Excel file
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
            $yamlFiles = Get-ChildItem -Path $BasePath -Recurse -Exclude "CustomCost" -Filter *.yaml -ErrorAction Stop
            Write-Log -Message "Found $($yamlFiles.Count) YAML files for validation." -Level "INFO"

            # Build subscription filter outside parallel block
            $subscriptionFilter = $null
            if ($SubscriptionIds) {
                $subscriptionList = $SubscriptionIds -split ',' | ForEach-Object { "'$($_.Trim())'" }
                $subscriptionFilter = $subscriptionList -join ","
            }

            # Extract unique resource types from YAML files
            $uniqueResourceTypes = @()
            $yamlFiles | ForEach-Object -Parallel {
                $file = $_
                $logFile = $using:logFile
                
                # Create a local function for logging within the parallel block
                function Write-ParallelLog {
                    param (
                        [string]$Message,
                        [string]$Level = "INFO"
                    )
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $logMessage = "$timestamp [$Level] $Message"
                    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
                }
                
                try {
                    # Read the YAML file
                    $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop

                    # Convert YAML to PowerShell object
                    $yamlObject = $yamlContent | ConvertFrom-Yaml

                    # Add the recommendationResourceType to the array
                    if ($yamlObject.recommendationResourceType) {
                        # Split the recommendationResourceType into individual resource types
                        $resourceTypes = $yamlObject.recommendationResourceType -split ' '
                        return $resourceTypes
                    }
                }
                catch {
                    Write-ParallelLog -Message "Failed to process YAML file '$($file.FullName)': $_" -Level "ERROR"
                }
            } -ThrottleLimit 5 -AsJob | Receive-Job -Wait -AutoRemoveJob | ForEach-Object {
                $uniqueResourceTypes += $_
            }

            # Remove duplicates and sort
            $uniqueResourceTypes = $uniqueResourceTypes | Sort-Object -Unique

            # Debug: Print the unique resource types
            Write-Host "Unique resource types in YAML files: $($uniqueResourceTypes -join ', ')" -ForegroundColor Cyan
            Write-Log -Message "Unique resource types in YAML files: $($uniqueResourceTypes -join ', ')" -Level "INFO"

            # Construct the resource type filter
            $resourceTypeConditions = $uniqueResourceTypes | ForEach-Object { "type == '$_'" }
            $resourceTypeFilter = $resourceTypeConditions -join ' or '

            # Query Azure Resource Graph for specific resource types
            $query = "resources | where $resourceTypeFilter"
            if ($subscriptionFilter -and $ResourceGroupName) {
                $query += " | where subscriptionId in ($subscriptionFilter) and resourceGroup == '$ResourceGroupName'"
            }
            elseif ($subscriptionFilter) {
                $query += " | where subscriptionId in ($subscriptionFilter)"
            }
            $query += " | summarize count() by type"

            Write-Log -Message "Querying Azure Resource Graph for specific resource types." -Level "INFO"
            Write-Log -Message "Query: $query" -Level "DEBUG"
            $resourceTypesInScope = Search-AzGraph -Query $query -First 1000

            # Debug: Print the resource types found in scope
            Write-Host "Resource types found in scope: $($resourceTypesInScope.type -join ', ')" -ForegroundColor Cyan
            Write-Log -Message "Resource types found in scope: $($resourceTypesInScope.type -join ', ')" -Level "INFO"

            # Initialize an array to store relevant YAML data
            $yamlData = @()

            # Process each YAML file
            $yamlFiles | ForEach-Object -Parallel {
                $file = $_
                $resourceTypesInScope = $using:resourceTypesInScope
                $logFile = $using:logFile
                
                # Create a local function for logging within the parallel block
                function Write-ParallelLog {
                    param (
                        [string]$Message,
                        [string]$Level = "INFO"
                    )
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $logMessage = "$timestamp [$Level] $Message"
                    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
                }
                
                try {
                    # Read the YAML file
                    $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop

                    # Convert YAML to PowerShell object
                    $yamlObject = $yamlContent | ConvertFrom-Yaml

                    # Split the recommendationResourceType into individual resource types
                    $resourceTypes = $yamlObject.recommendationResourceType -split ' '

                    # Check if any of the resource types exist in scope
                    $matchFound = $false
                    foreach ($resourceType in $resourceTypes) {
                        if ($resourceType -in $resourceTypesInScope.type) {
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
                    $yamlData += $_
                }
            }

            # Combine validated recommendations with CustomCost recommendations
            $combinedData = $yamlData + $customCostRecommendations
            
            # Convert YAML data to a format suitable for Excel
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
                    Tags                        = $_.tags
                    LearnMoreLink               = ($_.learnMoreLink | ForEach-Object { "$($_.name): $($_.url)" }) -join "; "
                }
            }

            # Append YAML data to the Excel file
            if ($excelData.Count -gt 0) {
                Write-Log -Message "Appending $($excelData.Count) manual recommendations to the Excel file." -Level "INFO"
                $excelData | Export-Excel -Path $ExcelFilePath -WorksheetName 'Manual Recommendations' -AutoSize -TableName 'ManualRecommendations' -TableStyle 'Light19'
            }
            else {
                Write-Log -Message "No manual recommendations found to append." -Level "WARNING"
            }
        }
        catch {
            Write-Log -Message "Error in Manual-Validations function: $_" -Level "ERROR"
            throw
        }
    }

    # Function to export Assessment results to Excel
    function Export-ResultsToExcel {
        param (
            [array]$AllResources,
            [string]$AssessmentFilePath,
            [string]$ExcelFilePath
        )

        # Export KQL results to Excel
        $AllResources | Export-Excel -Path $ExcelFilePath -WorksheetName 'Recommendations' -AutoSize -TableName 'Table1' -TableStyle 'Light19'
        Write-Log -Message "Results exported to Excel file: $ExcelFilePath" -Level "INFO"

        # Add assessment data if provided
        if ($AssessmentFilePath) {
            try {
                $assessmentData = Import-Csv -Path $AssessmentFilePath -ErrorAction Stop
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
        Write-Log -Message "Starting script execution." -Level "INFO"
        Install-AndImportModules -Modules @('Az.Accounts', 'Az.ResourceGraph', 'ImportExcel', 'powershell-yaml')
        Connect-ToAzure

        $workingFolderPath = $PSScriptRoot
        Set-Location -Path $workingFolderPath
        Write-Log -Message "Set working directory to: $workingFolderPath" -Level "INFO"

        # Hardcoded GitHub repository folder URL
        $repoUrl = "https://github.com/arthurclares/costbestpractices/raw/refs/heads/Dev/content/azure-resources.zip"
        
        # Define the destination directory (ensure it ends with "/azure-resources/")
        $tempDir = Join-Path $workingFolderPath "Temp\azure-resources"

        # Download and extract the zip file if the folder doesn't exist
        if (-not (Test-Path -Path $tempDir)) {
            Write-Log -Message "Downloading and extracting zip file." -Level "INFO"
            Download-GitHubFolder -RepoUrl $repoUrl -Destination $tempDir
        }
        else {
            Write-Log -Message "Folder already exists. Skipping download." -Level "INFO"
        }

        # Prompt to include Well-Architected Cost Optimization assessment
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

        # Process YAML files and append to the Excel file
        $runManualChecks = Read-Host "Would you like to run manual checks? (Yes/No or Y/N)"
        if ($runManualChecks -eq "yes" -or $runManualChecks -eq "y") {
            Write-Log -Message "Running manual checks." -Level "INFO"

            # Process YAML files and append to the Excel file
            Manual-Validations -BasePath $tempDir -ExcelFilePath $ExcelFilePath -SubscriptionIds $subscriptionIds -ResourceGroupName $resourceGroupName
        }
        else {
            Write-Log -Message "Skipping manual checks as per user request." -Level "INFO"
            # No processing of CustomCost recommendations when manual checks are skipped
        }

        # Process KQL files
        $results = Process-KQLFiles -BasePath $tempDir -SubscriptionIds $subscriptionIds -ResourceGroupName $resourceGroupName

        # Summarize recommendations by priority and resourceType
        $summary = $results.AllResources | Group-Object -Property @{
            Expression = {
                "$($_.x_RecommendationPriority) | $($_.x_ResourceType)"
            }
        } | ForEach-Object {
            [PSCustomObject]@{
                Priority     = ($_.x_RecommendationImpact -split ' \| ')[0]
                ResourceType = ($_.Name -split ' \| ')[1]
                ImpactedResources        = $_.Count
            }
        }

        # Display the summary
        Write-Host "`nRecommendations Summary:" -ForegroundColor Cyan
        $summary | Format-Table -AutoSize
        if ($results.QueryErrors.Count -gt 0) {
            Write-Host "`nThe following query errors occurred:" -ForegroundColor Red
            foreach ($error in $results.QueryErrors) {
                Write-Host "- $error" -ForegroundColor Red
            }
        }

        # Export KQL results to Excel
        if ($results.AllResources.Count -gt 0) {
            Export-ResultsToExcel -AllResources $results.AllResources -AssessmentFilePath $assessmentFilePath -ExcelFilePath $ExcelFilePath
        }
        else {
            Write-Log -Message "No resources found to export." -Level "WARNING"
        }

        Write-Log -Message "Script execution completed." -Level "INFO"
    }
    catch {
        Write-Log -Message "An error occurred: $_" -Level "ERROR"
    }
}

# Execute the main function
CostRecommendations
