<#
.SYNOPSIS
    Azure Cost Recommendations script.
.DESCRIPTION
    This script collects cost optimization recommendations from Azure using Azure Resource Graph queries and YAML files.
.NOTES
    Version: 2.0
    Author: arclares
#>

param (
    [string]$subscriptionIds,
    [string]$resourceGroupName,
    [switch]$Verbose
)

function Update-Scripts {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MainScriptUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$PrerequisitesScriptUrl,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        $mainScriptPath = $PSCommandPath 
        if (-not $mainScriptPath) { 
            Write-Host "FATAL: Could not determine the script's own path using \$PSCommandPath. Update cannot proceed." -ForegroundColor Red
            return $false
        }
        $mainScriptDir = Split-Path -Parent $mainScriptPath
        $prerequisitesScriptPath = Join-Path $mainScriptDir "CostRecommendations-Prerequisites.ps1"
        
        Write-Host "WARNING: Downloading and executing scripts from remote URLs." -ForegroundColor Yellow
        Write-Host "WARNING: This operation trusts content from: $($MainScriptUrl -replace '/[^/]+$', '')" -ForegroundColor Yellow
        Write-Host "WARNING: Ensure you trust this source before proceeding." -ForegroundColor Yellow
        Write-Host ""
        
        Write-Host "Downloading latest script versions..." -ForegroundColor Cyan
        
        $tempMainScriptPath = Join-Path $env:TEMP "CostRecommendations.ps1.new"
        Invoke-WebRequest -Uri $MainScriptUrl -OutFile $tempMainScriptPath -ErrorAction Stop
        
        $tempPrerequisitesScriptPath = Join-Path $env:TEMP "CostRecommendations-Prerequisites.ps1.new"
        Invoke-WebRequest -Uri $PrerequisitesScriptUrl -OutFile $tempPrerequisitesScriptPath -ErrorAction Stop
        
        # Verify downloaded files are not empty
        $mainScriptSize = (Get-Item $tempMainScriptPath).Length
        $prereqScriptSize = (Get-Item $tempPrerequisitesScriptPath).Length
        
        if ($mainScriptSize -lt 100 -or $prereqScriptSize -lt 100) {
            Write-Host "ERROR: Downloaded scripts appear to be too small or empty. Update aborted." -ForegroundColor Red
            Remove-Item -Path $tempMainScriptPath -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $tempPrerequisitesScriptPath -Force -ErrorAction SilentlyContinue
            return $false
        }
        
        Write-Host "Downloaded main script: $mainScriptSize bytes" -ForegroundColor Cyan
        Write-Host "Downloaded prerequisites script: $prereqScriptSize bytes" -ForegroundColor Cyan
        
        Copy-Item -Path $tempMainScriptPath -Destination $mainScriptPath -Force
        Copy-Item -Path $tempPrerequisitesScriptPath -Destination $prerequisitesScriptPath -Force
        
        Remove-Item -Path $tempMainScriptPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempPrerequisitesScriptPath -Force -ErrorAction SilentlyContinue
        
        Write-Host "Scripts updated successfully!" -ForegroundColor Green
        
        $restart = (Read-Host "Do you want to restart the script with the new version? (Yes/No or Y/N)").Trim().ToLower()
        if ($restart -eq "yes" -or $restart -eq "y") {
            Write-Host "Restarting script..." -ForegroundColor Cyan
            & $mainScriptPath
            return $true
        }
        
        return $true
    }
    catch {
        Write-Host "Error updating scripts: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Load-Settings {
    $settingsPath = Join-Path $PSScriptRoot "settings.json"
    
    if (-not (Test-Path -Path $settingsPath)) {
        $defaultSettings = @{
            scriptVersion = "2.0"
            repositoryUrls = @{
                mainScript = "https://raw.githubusercontent.com/microsoft/finops-toolkit/refs/heads/features/wacoascripts/src/wacoa/tools/CostRecommendations.ps1"
                prerequisitesScript = "https://raw.githubusercontent.com/microsoft/finops-toolkit/refs/heads/features/wacoascripts/src/wacoa/tools/CostRecommendations-Prerequisites.ps1"
                versionFile = "https://raw.githubusercontent.com/microsoft/finops-toolkit/refs/heads/features/wacoascripts/src/wacoa/tools/version.txt"
                resourcesZip = "https://github.com/microsoft/finops-toolkit/raw/refs/heads/features/wacoascripts/src/wacoa/content/azure-resources.zip"
            }
            paths = @{
                tempDir = "Temp"
                resourcesDir = "Temp/azure-resources"
                cacheFile = "ScopeCache.txt"
            }
            defaultSettings = @{
                parallelThrottleLimit = 5
                excelTableStyle = "Light19"
                logLevel = "INFO"
            }
        }
        
        $defaultSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath
        return $defaultSettings
    }
    
    try {
        $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        
        # Ensure scriptVersion exists and is not empty
        if (-not $settings.scriptVersion -or [string]::IsNullOrWhiteSpace($settings.scriptVersion)) {
            Write-Host "Warning: settings.json is missing scriptVersion. Using default version 2.0" -ForegroundColor Yellow
            $settings | Add-Member -NotePropertyName scriptVersion -NotePropertyValue "2.0" -Force
        }
        
        # Ensure repositoryUrls exists
        if (-not $settings.repositoryUrls) {
            Write-Host "Warning: settings.json is missing repositoryUrls. Adding defaults." -ForegroundColor Yellow
            $settings | Add-Member -NotePropertyName repositoryUrls -NotePropertyValue @{
                mainScript = "https://raw.githubusercontent.com/microsoft/finops-toolkit/refs/heads/features/wacoascripts/src/wacoa/tools/CostRecommendations.ps1"
                prerequisitesScript = "https://raw.githubusercontent.com/microsoft/finops-toolkit/refs/heads/features/wacoascripts/src/wacoa/tools/CostRecommendations-Prerequisites.ps1"
                versionFile = "https://raw.githubusercontent.com/microsoft/finops-toolkit/refs/heads/features/wacoascripts/src/wacoa/tools/version.txt"
                resourcesZip = "https://github.com/microsoft/finops-toolkit/raw/refs/heads/features/wacoascripts/src/wacoa/content/azure-resources.zip"
            } -Force
        }
        
        # Ensure paths exists
        if (-not $settings.paths) {
            Write-Host "Warning: settings.json is missing paths. Adding defaults." -ForegroundColor Yellow
            $settings | Add-Member -NotePropertyName paths -NotePropertyValue @{
                tempDir = "Temp"
                resourcesDir = "Temp/azure-resources"
                cacheFile = "ScopeCache.txt"
            } -Force
        }
        
        # Ensure defaultSettings exists
        if (-not $settings.defaultSettings) {
            Write-Host "Warning: settings.json is missing defaultSettings. Adding defaults." -ForegroundColor Yellow
            $settings | Add-Member -NotePropertyName defaultSettings -NotePropertyValue @{
                parallelThrottleLimit = 5
                excelTableStyle = "Light19"
                logLevel = "INFO"
            } -Force
        }
        
        # Save the updated settings back to file if any changes were made
        try {
            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath
        }
        catch {
            Write-Host "Warning: Could not update settings.json: $_" -ForegroundColor Yellow
        }
        
        return $settings
    }
    catch {
        Write-Host "Error loading settings: $_" -ForegroundColor Red
        exit
    }
}

function Process-KQLFiles {
    param (
        [string]$BasePath,
        [object]$ScopeObject
    )

    # Get all KQL files initially
    $allKqlFiles = Get-ChildItem -Path $BasePath -Recurse -Filter *.kql -ErrorAction Stop

    # Define the specific reservation recommendation files
    $oneYearKqlFileName = 'be9223ef-ba16-43ce-9f99-2ed3e2ad155c.kql'
    $threeYearKqlFileName = 'd40c22a2-2b9d-4445-b137-7905403b2908.kql'
    $reservationKqlFiles = @($oneYearKqlFileName, $threeYearKqlFileName)

    # Separate the general KQL files from the specific reservation ones
    $kqlFiles = $allKqlFiles | Where-Object { $reservationKqlFiles -notcontains $_.Name }
    
    # Check if either of the reservation recommendation files exists before prompting the user
    $oneYearFile = $allKqlFiles | Where-Object { $_.Name -eq $oneYearKqlFileName }
    $threeYearFile = $allKqlFiles | Where-Object { $_.Name -eq $threeYearKqlFileName }

    if ($oneYearFile -or $threeYearFile) {
        while ($true) {
            Write-Host "`nAdvisor Reservation Recommendations:" -ForegroundColor Cyan
            $termChoice = Read-Host "Do you want to see recommendations for a [1]-year or [3]-year term? (Enter 1 or 3)"
            if ($termChoice -eq '1' -and $oneYearFile) {
                $kqlFiles += $oneYearFile
                Write-Log -Message "User selected 1-year term. Adding 1-year Advisor KQL file to processing list." -Level "INFO"
                break
            }
            elseif ($termChoice -eq '3' -and $threeYearFile) {
                $kqlFiles += $threeYearFile
                Write-Log -Message "User selected 3-year term. Adding 3-year Advisor KQL file to processing list." -Level "INFO"
                break
            }
            else {
                Write-Host "Invalid input or the selected KQL file does not exist. Please enter '1' or '3'." -ForegroundColor Red
            }
        }
    }

    Write-Log -Message "Found $($kqlFiles.Count) KQL recommendation files to process." -Level "INFO"
    Write-Host "`nFound $($kqlFiles.Count) KQL recommendation files to process." -ForegroundColor Cyan

    $allResources = @()
    $queryErrors = @()

    $kqlFilterStringForParallel = ""

    if (-not $ScopeObject) {
        Write-Log -Message "Process-KQLFiles: ScopeObject parameter is null or empty. No specific KQL scope filter will be applied." -Level "WARNING"
    }
    elseif ($ScopeObject.ScopeType -eq "EntireEnvironment") {
        Write-Log -Message "KQL Processing: Entire Environment. No specific KQL scope filter will be applied." -Level "INFO"
    }
    elseif ($ScopeObject.ScopeType -eq "CustomList" -and $ScopeObject.IndividualScopes -and $ScopeObject.IndividualScopes.Count -gt 0) {
        $scopeConditions = @()
        
        foreach ($scope in $ScopeObject.IndividualScopes) {
            if ($scope.Type -eq "Subscription") {
                # Escape single quotes in subscription ID to prevent KQL injection
                $escapedSubId = $scope.SubscriptionId -replace "'", "''"
                $scopeConditions += "(SubAccountId == '$escapedSubId')"
            }
            elseif ($scope.Type -eq "ResourceGroup") {
                # Escape single quotes to prevent KQL injection
                $escapedSubId = $scope.SubscriptionId -replace "'", "''"
                $escapedRgName = $scope.ResourceGroupName -replace "'", "''"
                $scopeConditions += "(SubAccountId == '$escapedSubId' and x_ResourceGroupName == '$escapedRgName')"
            }
        }
        
        if ($scopeConditions.Count -gt 0) {
            $kqlFilterStringForParallel = "(" + ($scopeConditions -join " or ") + ")"
            Write-Log -Message "KQL Processing: Applying filter: $kqlFilterStringForParallel" -Level "DEBUG"
        }
    }
    else {
        Write-Log -Message "KQL Processing: Unrecognized scope type or empty individual scopes. No filter will be applied." -Level "WARNING"
    }

    $results = $kqlFiles | ForEach-Object -Parallel {
        $file = $_
        $filterToApply = $using:kqlFilterStringForParallel
        $logFilePath = $using:logFile

        function Write-ParallelLog {
            param (
                [string]$Message,
                [string]$Level = "INFO",
                [string]$PathToLogFile
            )
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "$timestamp [$Level] [Thread $([System.Threading.Thread]::CurrentThread.ManagedThreadId)] $Message"
            # Change to Continue so we see if there are write failures
            Add-Content -Path $PathToLogFile -Value $logMessage -ErrorAction Continue
        }

        try {
            $query = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            
            if ($filterToApply) {
                $query = "$query | where $filterToApply"
            }
            
            Write-ParallelLog -Message "Final KQL query for $($file.Name):`n$query" -Level "DEBUG" -PathToLogFile $logFilePath

            try {
                Write-ParallelLog -Message "Executing KQL query for $($file.Name)..." -Level "DEBUG" -PathToLogFile $logFilePath
                $resultPage = Search-AzGraph -Query $query -First 1000 -ErrorAction Stop
                $fileResourcesFound = @($resultPage)

                while ($resultPage -ne $null -and $resultPage.SkipToken) {
                    Write-ParallelLog -Message "Fetching next KQL page for $($file.Name)..." -Level "DEBUG" -PathToLogFile $logFilePath
                    $resultPage = Search-AzGraph -Query $query -SkipToken $resultPage.SkipToken -First 1000 -ErrorAction Stop
                    $fileResourcesFound += $resultPage
                }

                Write-ParallelLog -Message "Completed KQL query for $($file.Name), found $($fileResourcesFound.Count) resources." -Level "DEBUG" -PathToLogFile $logFilePath
                return $fileResourcesFound
            }
            catch {
                $errorMessage = "KQL Query failed for file '$($file.FullName)': $($_.Exception.Message)"
                Write-ParallelLog -Message $errorMessage -Level "ERROR" -PathToLogFile $logFilePath
                return [PSCustomObject]@{ IsError = $true; Error = $errorMessage; Query = $query; File = $file.FullName }
            }
        }
        catch {
            $errorMessage = "An error occurred while processing KQL file '$($file.FullName)': $($_.Exception.Message)"
            Write-ParallelLog -Message $errorMessage -Level "ERROR" -PathToLogFile $logFilePath
            return [PSCustomObject]@{ IsError = $true; Error = $errorMessage; File = $file.FullName }
        }
    } -ThrottleLimit $script:settings.defaultSettings.parallelThrottleLimit -AsJob | Receive-Job -Wait -AutoRemoveJob

    foreach ($item in $results) {
        if ($item -is [PSCustomObject] -and $item.PSObject.Properties['IsError']) {
            $queryErrors += $item
        }
        elseif ($item -ne $null) {
            $allResources += @($item)
        }
    }

    foreach ($error in $queryErrors) {
        Write-Log -Message "Error processing KQL file $($error.File): $($error.Error)" -Level "ERROR"
        if ($error.Query) {
            Write-Log -Message "Failed KQL Query: $($error.Query)" -Level "DEBUG"
        }
    }

    Write-Log -Message "Found $($allResources.Count) KQL recommendations in the environment." -Level "INFO"
    Write-Host "Found $($allResources.Count) KQL recommendations in the environment." -ForegroundColor Cyan

    return @{
        AllResources = $allResources
        QueryErrors  = $queryErrors
    }
}

function Process-CustomCostRecommendations {
    param (
        [string]$BasePath 
    )

    $customCostPath = Join-Path $BasePath "CustomCost"
    $nestedCustomCostPath = Join-Path $BasePath "azure-resources\CustomCost"

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

    $yamlFiles = Get-ChildItem -Path $foundPath -Filter *.yaml -ErrorAction Stop
    if ($yamlFiles.Count -eq 0) {
        Write-Log -Message "No YAML files found in CustomCost folder." -Level "WARNING"
        return @()
    }

    Write-Log -Message "Found $($yamlFiles.Count) YAML files in CustomCost folder." -Level "INFO"
    Write-Host "Found $($yamlFiles.Count) YAML files in CustomCost folder." -ForegroundColor Cyan

    $customCostData = @()

    foreach ($file in $yamlFiles) {
        try {
            $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop

            try {
                 $yamlObject = $yamlContent | ConvertFrom-Yaml
                 $customCostData += $yamlObject
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

function Manual-Validations {
    param (
        [string]$BasePath, 
        [string]$ExcelFilePath, 
        [object]$ScopeObject 
    )

    try {
        $customCostRecommendations = Process-CustomCostRecommendations -BasePath $BasePath
        Write-Log -Message "Found $($customCostRecommendations.Count) CustomCost recommendations." -Level "INFO"

        $yamlFiles = Get-ChildItem -Path $BasePath -Recurse -Exclude "CustomCost" -Filter *.yaml -ErrorAction Stop
        Write-Log -Message "Found $($yamlFiles.Count) YAML files for validation." -Level "INFO"

        $uniqueResourceTypes = @()
        $yamlFiles | ForEach-Object -Parallel {
            $file = $_
            $logFile = $using:logFile

            function Write-ParallelLog {
                param (
                    [string]$Message,
                    [string]$Level = "INFO"
                )
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $logMessage = "$timestamp [$Level] [Thread $([System.Threading.Thread]::CurrentThread.ManagedThreadId)] $Message"
                # Change to Continue so we see if there are write failures
                Add-Content -Path $logFile -Value $logMessage -ErrorAction Continue
            }

            try {
                $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
                $yamlObject = $yamlContent | ConvertFrom-Yaml

                if ($yamlObject.recommendationResourceType) {
                    $resourceTypes = $yamlObject.recommendationResourceType -split ' '
                    return $resourceTypes
                }
            }
            catch {
                Write-ParallelLog -Message "Failed to process YAML file '$($file.FullName)': $_" -Level "ERROR"
            }
        } -ThrottleLimit $script:settings.defaultSettings.parallelThrottleLimit -AsJob | Receive-Job -Wait -AutoRemoveJob | ForEach-Object {
            if ($_ -is [array]) {
                $uniqueResourceTypes += $_
            } elseif ($_) {
                $uniqueResourceTypes += @($_)
            }
        }

        $uniqueResourceTypes = $uniqueResourceTypes | Sort-Object -Unique

        Write-Host "Unique resource types in YAML files: $($uniqueResourceTypes -join ', ')" -ForegroundColor Cyan
        Write-Log -Message "Unique resource types in YAML files: $($uniqueResourceTypes -join ', ')" -Level "INFO"

        # Validate and escape resource types to prevent KQL injection
        $validResourceTypes = @()
        foreach ($resourceType in $uniqueResourceTypes) {
            if (Test-ResourceType -ResourceType $resourceType) {
                $validResourceTypes += $resourceType
            } else {
                Write-Log -Message "Invalid resource type format detected and skipped: $resourceType" -Level "WARNING"
            }
        }
        
        if ($validResourceTypes.Count -eq 0) {
            Write-Log -Message "No valid resource types found in YAML files." -Level "ERROR"
            return @()
        }
        
        $resourceTypeConditions = $validResourceTypes | ForEach-Object { 
            $escapedType = $_ -replace "'", "''"
            "type == '$escapedType'"
        }
        $resourceTypeFilter = $resourceTypeConditions -join ' or '

        $query = "resources | where $resourceTypeFilter"
        
        if ($ScopeObject.ScopeType -eq "CustomList" -and $ScopeObject.IndividualScopes -and $ScopeObject.IndividualScopes.Count -gt 0) {
            $scopeConditions = @()
            
            foreach ($scope in $ScopeObject.IndividualScopes) {
                if ($scope.Type -eq "Subscription") {
                    # Escape single quotes in subscription ID to prevent KQL injection
                    $escapedSubId = $scope.SubscriptionId -replace "'", "''"
                    $scopeConditions += "(subscriptionId == '$escapedSubId')"
                }
                elseif ($scope.Type -eq "ResourceGroup") {
                    # Escape single quotes to prevent KQL injection
                    $escapedSubId = $scope.SubscriptionId -replace "'", "''"
                    $escapedRgName = $scope.ResourceGroupName -replace "'", "''"
                    $scopeConditions += "(subscriptionId == '$escapedSubId' and resourceGroup == '$escapedRgName')"
                }
            }
            
            if ($scopeConditions.Count -gt 0) {
                $query += " | where " + ($scopeConditions -join " or ")
            }
        }
        elseif ($ScopeObject.SubscriptionIds -and $ScopeObject.ResourceGroupName) {
            $subscriptionList = $ScopeObject.SubscriptionIds -split ',' | ForEach-Object { "'$($_.Trim())'" }
            $subscriptionFilter = $subscriptionList -join ","
            $query += " | where subscriptionId in ($subscriptionFilter) and resourceGroup == '$($ScopeObject.ResourceGroupName)'"
        }
        elseif ($ScopeObject.SubscriptionIds) {
            $subscriptionList = $ScopeObject.SubscriptionIds -split ',' | ForEach-Object { "'$($_.Trim())'" }
            $subscriptionFilter = $subscriptionList -join ","
            $query += " | where subscriptionId in ($subscriptionFilter)"
        }
        
        $query += " | summarize count() by type"

        Write-Log -Message "Querying Azure Resource Graph for specific resource types." -Level "INFO"
        Write-Log -Message "Query: $query" -Level "DEBUG"
        
        $resourceTypesInScope = Search-AzGraph -Query $query -First 1000

        Write-Host "Resource types found in scope: $($resourceTypesInScope.type -join ', ')" -ForegroundColor Cyan
        Write-Log -Message "Resource types found in scope: $($resourceTypesInScope.type -join ', ')" -Level "INFO"

        $yamlData = @()

        $yamlFiles | ForEach-Object -Parallel {
            $file = $_
            $resourceTypesInScope = $using:resourceTypesInScope
            $logFile = $using:logFile

            function Write-ParallelLog {
                param (
                    [string]$Message,
                    [string]$Level = "INFO"
                )
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $logMessage = "$timestamp [$Level] [Thread $([System.Threading.Thread]::CurrentThread.ManagedThreadId)] $Message"
                # Change to Continue so we see if there are write failures
                Add-Content -Path $logFile -Value $logMessage -ErrorAction Continue
            }

            try {
                $yamlContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
                $yamlObject = $yamlContent | ConvertFrom-Yaml
                $resourceTypes = $yamlObject.recommendationResourceType -split ' '

                $matchFound = $false
                foreach ($resourceType in $resourceTypes) {
                    if ($resourceTypesInScope.type -contains $resourceType) {
                        $matchFound = $true
                        break
                    }
                }

                if ($matchFound) {
                    return $yamlObject
                }
            }
            catch {
                Write-ParallelLog -Message "Failed to process YAML file '$($file.FullName)': $_" -Level "ERROR"
            }
        } -ThrottleLimit $script:settings.defaultSettings.parallelThrottleLimit -AsJob | Receive-Job -Wait -AutoRemoveJob | ForEach-Object {
            if ($_) {
                $yamlData += $_
            }
        }

        $combinedData = $yamlData + $customCostRecommendations

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

        if ($excelData.Count -gt 0) {
            Write-Log -Message "Appending $($excelData.Count) manual recommendations to the Excel file." -Level "INFO"
            $excelData | Export-Excel -Path $ExcelFilePath -WorksheetName 'Manual Recommendations' -AutoSize -TableName 'ManualRecommendations' -TableStyle $script:settings.defaultSettings.excelTableStyle
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

function Export-ResultsToExcel {
    param (
        [array]$AllResources,
        [string]$AssessmentFilePath,
        [string]$ExcelFilePath
    )

    # Map resources to ensure all expected fields are included
    $mappedData = $AllResources | ForEach-Object {
        [PSCustomObject]@{
            ResourceId                 = $_.ResourceId
            ResourceName               = $_.ResourceName
            x_ResourceType             = $_.x_ResourceType
            x_ResourceGroupName        = $_.x_ResourceGroupName
            SubAccountId               = $_.SubAccountId
            SubAccountName             = $_.SubAccountName
            x_RecommendationId          = $_.x_RecommendationId
            x_RecommendationCategory    = $_.x_RecommendationCategory
            x_RecommendationImpact      = $_.x_RecommendationImpact
            x_RecommendationProvider    = $_.x_RecommendationProvider
            x_RecommendationTypeId      = $_.x_RecommendationTypeId
            x_RecommendationControl     = $_.x_RecommendationControl
            x_RecommendationMaturityLevel = $_.x_RecommendationMaturityLevel
            x_RecommendationDescription = $_.x_RecommendationDescription
            x_RecommendationSolution    = $_.x_RecommendationSolution
            x_RecommendationDetails     = $_.x_RecommendationDetails
            x_RecommendationDate        = $_.x_RecommendationDate
        }
    }
    
    $mappedData | Export-Excel -Path $ExcelFilePath -WorksheetName 'Recommendations' -AutoSize -TableName 'Table1' -TableStyle $script:settings.defaultSettings.excelTableStyle
    Write-Log -Message "Results exported to Excel file: $ExcelFilePath" -Level "INFO"

    if ($AssessmentFilePath) {
        try {
            # Read the CSV file content
            $csvContent = Get-Content -Path $AssessmentFilePath -ErrorAction Stop
            
            # Find the line that contains CSV headers (usually contains comma-separated values)
            $headerLineIndex = -1
            for ($i = 0; $i -lt $csvContent.Count; $i++) {
                # Look for a line that has commas and reasonable content (not just empty or whitespace)
                $line = $csvContent[$i].Trim()
                if ($line.Length -gt 0 -and $line.Contains(',') -and -not $line.StartsWith('#')) {
                    $headerLineIndex = $i
                    break
                }
            }
            
            if ($headerLineIndex -eq -1) {
                Write-Log -Message "Could not find CSV header line in assessment file. Trying default skip of 11 lines." -Level "WARNING"
                $assessmentData = $csvContent | Select-Object -Skip 11 | ConvertFrom-Csv -ErrorAction Stop
            } else {
                Write-Log -Message "Found CSV header at line $($headerLineIndex + 1)." -Level "INFO"
                $assessmentData = $csvContent | Select-Object -Skip $headerLineIndex | ConvertFrom-Csv -ErrorAction Stop
            }
            
            if (-not $assessmentData -or $assessmentData.Count -eq 0) {
                Write-Log -Message "No data found in assessment CSV file after parsing." -Level "WARNING"
            } else {
                $assessmentData | Export-Excel -Path $ExcelFilePath -WorksheetName 'Well-Architected Assessment' -AutoSize -TableName 'WAF Assessment' -TableStyle $script:settings.defaultSettings.excelTableStyle
                Write-Log -Message "Added Well-Architected Cost Optimization assessment ($($assessmentData.Count) rows) as a new tab in the Excel file." -Level "INFO"
            }
        }
        catch {
            Write-Log -Message "Failed to import or add the Well-Architected Cost Optimization assessment: $_" -Level "ERROR"
        }
    }
}

function Start-CostRecommendations {
    param (
        [string]$subscriptionIds,
        [string]$resourceGroupName,
        [switch]$Verbose
    )

    try {
        $script:settings = Load-Settings
        
        $script:logFile = Join-Path $PSScriptRoot ('ACORL-Log-' + (Get-Date -Format 'yyyy-MM-dd-HH-mm') + '.log')
        
        $prerequisitesScriptPath = Join-Path $PSScriptRoot "CostRecommendations-Prerequisites.ps1"
        if (-not (Test-Path -Path $prerequisitesScriptPath)) {
            Write-Host "Prerequisites script not found. Attempting to download..." -ForegroundColor Yellow 
            if (-not (Update-Scripts -MainScriptUrl $script:settings.repositoryUrls.mainScript -PrerequisitesScriptUrl $script:settings.repositoryUrls.prerequisitesScript -Force)) {
                Write-Host "ERROR: Failed to download or update prerequisite scripts. The script cannot continue." -ForegroundColor Red
                return 
            }

            if (-not (Test-Path -Path $prerequisitesScriptPath)) {
                Write-Host "ERROR: Prerequisites script '$prerequisitesScriptPath' still not found after download attempt. The script cannot continue." -ForegroundColor Red
                return
            }
            Write-Host "Prerequisites script downloaded successfully." -ForegroundColor Green

        }

        try {
            Write-Host "Loading prerequisites script: $prerequisitesScriptPath" -ForegroundColor Cyan
            . $prerequisitesScriptPath
            Write-Host "Prerequisites script loaded successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "FATAL ERROR: Failed to load the prerequisites script '$prerequisitesScriptPath'." -ForegroundColor Red
            Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "The script cannot continue without its prerequisites." -ForegroundColor Red
            throw "Prerequisites loading failed." 
        }

        Write-Log -Message "Starting script execution (Version $($script:settings.scriptVersion))." -Level "INFO"
        
        Check-ScriptVersion -CurrentVersion $script:settings.scriptVersion -RemoteVersionUrl $script:settings.repositoryUrls.versionFile
        
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-Host "This script requires PowerShell 7 or later. Please upgrade to PowerShell 7." -ForegroundColor Red
            Write-Host "Download PowerShell 7 from: https://aka.ms/powershell-release" -ForegroundColor Yellow
            exit
        }
        
        if (($env:ACC_ENV -eq 'AzureCloudShell') -or ($env:CLOUD_SHELL -eq 'true')) {
            Write-Host "Script running from Azure CloudShell. Testing if Temp folder exist" -ForegroundColor Yellow

            # Get current directory
            $currentPath = Get-Location

            # Define the temp folder path
            $tempFolderPath = Join-Path -Path $currentPath -ChildPath "temp\WACOA"

            # Check if "temp" folder exists; if not, create it
            if (-not (Test-Path -Path $tempFolderPath)) {
                New-Item -ItemType Directory -Path $tempFolderPath | Out-Null
            }

            # Set the TEMP environment variable to the new temp folder path
            $env:TEMP = $tempFolderPath
        }
        
        Install-AndImportModules -Modules @('Az.Accounts', 'Az.ResourceGraph', 'ImportExcel', 'powershell-yaml')
        Connect-ToAzure
        
        $workingFolderPath = $PSScriptRoot
        Set-Location -Path $workingFolderPath
        Write-Log -Message "Set working directory to: $workingFolderPath" -Level "INFO"
        
        $tempBaseDir = Join-Path $workingFolderPath $script:settings.paths.tempDir
        $tempDir = Join-Path $workingFolderPath $script:settings.paths.resourcesDir
        
        if (-not (Test-Path -Path $tempDir -PathType Container)) {
            Write-Log -Message "Downloading and extracting zip file to $tempDir." -Level "INFO"
            if (-not (Test-Path -Path $tempBaseDir -PathType Container)) {
                New-Item -Path $tempBaseDir -ItemType Directory -ErrorAction Stop | Out-Null
            }
            Download-GitHubFolder -RepoUrl $script:settings.repositoryUrls.resourcesZip -Destination $tempBaseDir
        }
        else {
            Write-Log -Message "Folder '$tempDir' already exists. Skipping download." -Level "INFO"
        }
        
        $includeAssessment = (Read-Host "Would you like to include the results of a Well-Architected Cost Optimization assessment? (Yes/No or Y/N)").Trim().ToLower()
        $assessmentFilePath = $null
        if ($includeAssessment -eq "yes" -or $includeAssessment -eq "y") {
            $assessmentFilePath = Get-FilePath
            if (-not $assessmentFilePath) {
                Write-Log -Message "No file selected. Skipping Well-Architected Cost Optimization assessment." -Level "WARNING"
            }
        }
        
        $scope = Get-Scope
        
        $ExcelFilePath = Join-Path $PSScriptRoot ('ACORL-File-' + (Get-Date -Format 'yyyy-MM-dd-HH-mm') + '.xlsx')
        
        $runManualChecks = (Read-Host "Would you like to run manual checks? (Yes/No or Y/N)").Trim().ToLower()
        if ($runManualChecks -eq "yes" -or $runManualChecks -eq "y") {
            Write-Log -Message "Running manual checks." -Level "INFO"
            Manual-Validations -BasePath $tempDir -ExcelFilePath $ExcelFilePath -ScopeObject $scope
        }
        else {
            Write-Log -Message "Skipping manual checks as per user request." -Level "INFO"
        }
        
        $results = Process-KQLFiles -BasePath $tempDir -ScopeObject $scope
        
        $summary = $results.AllResources | Group-Object -Property @{
            Expression = {
                "$($_.x_RecommendationPriority) | $($_.x_ResourceType)"
            }
        } | ForEach-Object {
            $groupParts = $_.Name -split ' \| '
            $priorityValue = if ($groupParts.Count -ge 1) { $groupParts[0] } else { 'Unknown Priority' }
            $resourceTypeValue = if ($groupParts.Count -ge 2) { $groupParts[1] } else { 'Unknown Type' }
            
            [PSCustomObject]@{
                Priority     = $priorityValue
                ResourceType = $resourceTypeValue
                ImpactedResources = $_.Count
            }
        } | Sort-Object Priority, ResourceType
        
        Write-Host "`nRecommendations Summary:" -ForegroundColor Cyan
        $summary | Format-Table -AutoSize
        
        if ($results.QueryErrors.Count -gt 0) {
            Write-Host "`nThe following query errors occurred:" -ForegroundColor Red
            foreach ($error in $results.QueryErrors) {
                Write-Host "- File: $($error.File)" -ForegroundColor Red
                Write-Host "  Error: $($error.Error)" -ForegroundColor Red
            }
        }
        
        if ($results.AllResources.Count -gt 0) {
            Export-ResultsToExcel -AllResources $results.AllResources -AssessmentFilePath $assessmentFilePath -ExcelFilePath $ExcelFilePath
        }
        else {
            Write-Log -Message "No KQL resources found to export." -Level "WARNING"
            if($assessmentFilePath -and (Test-Path $assessmentFilePath)){
                Write-Log -Message "Exporting only Well-Architected Assessment as no KQL results were found." -Level "INFO"
                Export-ResultsToExcel -AllResources @() -AssessmentFilePath $assessmentFilePath -ExcelFilePath $ExcelFilePath
            }
        }
        
        Write-Log -Message "Script execution completed." -Level "INFO"
        Write-Host "`nScript execution finished." -ForegroundColor Green
        Write-Host "Results file: $ExcelFilePath" -ForegroundColor Green
        Write-Host "Log file: $script:logFile" -ForegroundColor Green

        if (($env:ACC_ENV -eq 'AzureCloudShell') -or ($env:CLOUD_SHELL -eq 'true')) {
            Write-Host "`nTo download the Excel report from Cloud Shell, use the 'Download' button in the toolbar and enter the full path:" -ForegroundColor Cyan
            Write-Host $ExcelFilePath -ForegroundColor White
        }
    }
    catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Message "An error occurred: $_" -Level "ERROR"
        } else {
            Write-Host "CRITICAL ERROR (logging unavailable): $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Message "Script execution finished run." -Level "INFO"
        } else {
            Write-Host "Script execution finished run (logging unavailable)." -ForegroundColor Yellow
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-CostRecommendations -subscriptionIds $subscriptionIds -resourceGroupName $resourceGroupName -Verbose:$Verbose
}