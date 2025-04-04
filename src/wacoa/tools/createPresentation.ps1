# Enhanced PowerPoint Updater Script for Azure Recommendations (Original Structure + Version Check + Missing Sheet Fix)
# Purpose: Updates PowerPoint presentation with recommendations from a multi-tab Excel file
# Features:
#  - Processes both "Manual Recommendations" and "Recommendations" tabs
#  - Skips the "Well-Architected Assessment" tab
#  - Updates slides 14 (High Impact), 15 (Medium Impact), 16 (Low Impact)
#  - Groups similar recommendations and shows accurate resource counts
#  - Creates a summary of recommendations by impact level
#  - Creates a new PPT file with timestamp
#  - Includes version check functionality
#  - Handles missing Excel sheets gracefully

param (
    [Parameter(Mandatory=$true)]
    [string]$InputPath,

    [Parameter(Mandatory=$true)]
    [string]$PowerPointPath,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath,

    [Parameter(Mandatory=$false)]
    [switch]$CreateSummary,

    [Parameter(Mandatory=$false)]
    [int]$SummarySlide = 13
)

# --- BEGIN NEW VERSION CHECK VARIABLES ---
# Define the current version of this script. Update this whenever you make significant changes.
$ScriptVersion = "1.0.1" # Current version as specified

# URL to the raw content of the version.txt file in the specified GitHub repository for THIS script
$RemoteVersionFileUrl = "https://github.com/microsoft/finops-toolkit/raw/refs/heads/features/wacoascripts/src/wacoa/tools/pptversion.txt"


# --- Define Write-Log function (needed for Version Check function) ---
# Function to log messages (Minimal version for compatibility with Check-ScriptVersion)
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
    # For simplicity, just write to host based on level for this script
    switch ($Level) {
        "INFO"    { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "DEBUG"   { Write-Host $logMessage -ForegroundColor Gray }
        default   { Write-Host $logMessage }
    }
    # NOTE: This version doesn't write to a file like in CollectCostRecommendations.ps1
}
# --- End Write-Log definition ---


# --- BEGIN NEW VERSION CHECK FUNCTION (with Pause) ---
# Function to check if the current script version is the latest
# Prompts the user to continue or exit if outdated. Includes a pause if continuing.
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
            Write-Host "ACTION REQUIRED: A newer version of this script (CreatePresentation.ps1) is available!" -ForegroundColor Yellow
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
                        Write-Host "Proceeding with current version $CurrentVersion in 3 seconds..." -ForegroundColor Cyan
                        # --- ADDED PAUSE HERE ---
                        Start-Sleep -Seconds 3
                        # --- END ADDED PAUSE ---
                        return # Exit the function, script execution continues
                    }
                    elseif ($choice -eq 's') {
                        Write-Log -Message "User chose to stop and download the latest version ($latestVersionString)." -Level "INFO"
                        Write-Host "`nTo download the latest version, please run the following command:" -ForegroundColor Green
                        Write-Host "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/microsoft/finops-toolkit/features/wacoascripts/src/wacoa/tools/CreatePresentation.ps1' -OutFile 'CreatePresentation.ps1'" -ForegroundColor Cyan
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

function Write-Progress-Message {
    param (
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if required modules are installed 
function Check-RequiredModules {
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Host "Installing ImportExcel module..." -ForegroundColor Yellow
        Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
    }
    # Original script didn't explicitly import here, relied on autoload or later import.
    # To maintain original behavior, we won't add an explicit Import-Module here.
}

# Function to generate a unique output filename with timestamp 
function Get-UniqueOutputPath {
    param (
        [string]$InputPath
    )

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $directory = [System.IO.Path]::GetDirectoryName($InputPath)
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    $extension = [System.IO.Path]::GetExtension($InputPath)

    return "$directory\$filename-$timestamp$extension"
}

# Main script starts here
try {
    # --- Start Log Message with Version ---
    Write-Log -Message "Starting script execution (Version $ScriptVersion)." -Level "INFO"

    # --- Perform Version Check ---
    Check-ScriptVersion -CurrentVersion $ScriptVersion -RemoteVersionUrl $RemoteVersionFileUrl

    # Define constants for MsoTriState (Original values)
    $MsoTrue = 1  # msoTrue value
    $MsoFalse = 0 # msoFalse value

    # Initialize PowerPoint application 
    Write-Progress-Message "Initializing PowerPoint application..."
    $PowerPoint = New-Object -ComObject PowerPoint.Application
    $PowerPoint.Visible = $MsoTrue  # Using the value directly instead of the enum

    # Open the presentation 
    Write-Progress-Message "Opening PowerPoint presentation: $PowerPointPath"
    $Presentation = $PowerPoint.Presentations.Open($PowerPointPath)

    # Generate unique output path if not specified  
    if (-not $OutputPath) {
        $OutputPath = Get-UniqueOutputPath -InputPath $PowerPointPath
        Write-Progress-Message "Generated unique output path: $OutputPath"
    }

    # Check required modules  
    Check-RequiredModules

    # Import recommendation data from multiple sheets
    Write-Progress-Message "Importing Excel data from: $InputPath"

    # --- MODIFIED Import Section for Missing Sheets ---
    # Initialize variables as empty arrays to prevent null reference errors
    $AutomaticRecommendations = @()
    $ManualRecommendations = @()

    # Import the "Recommendations" sheet safely
    Write-Progress-Message "Processing 'Recommendations' sheet..."
    try {
        # Use -ErrorAction Stop within try block to catch errors like file not found or sheet not found
        $importedAutoRecs = Import-Excel -Path $InputPath -WorksheetName "Recommendations" -ErrorAction Stop
        # Check if Import-Excel returned data (it might return $null even without error in some cases)
        if ($null -ne $importedAutoRecs) {
            $AutomaticRecommendations = $importedAutoRecs
        }
        # Use Write-Progress-Message as in original script
        Write-Progress-Message "Found $($AutomaticRecommendations.Count) recommendations in 'Recommendations' sheet."
    }
    catch {
        # Log a warning if the sheet is missing or another error occurs
        Write-Progress-Message "Warning: Sheet 'Recommendations' not found or could not be imported from '$InputPath'. Error: $($_.Exception.Message)" -Color Yellow
        # $AutomaticRecommendations remains @()
    }

    # Import the "Manual Recommendations" sheet safely
    Write-Progress-Message "Processing 'Manual Recommendations' sheet..."
    try {
        # Use -ErrorAction Stop within try block
        $importedManualRecs = Import-Excel -Path $InputPath -WorksheetName "Manual Recommendations" -ErrorAction Stop
        # Check if Import-Excel returned data
        if ($null -ne $importedManualRecs) {
            $ManualRecommendations = $importedManualRecs
        }
        # This line is now safe because $ManualRecommendations is guaranteed to be an array (@())
        Write-Progress-Message "Found $($ManualRecommendations.Count) recommendations in 'Manual Recommendations' sheet."
    }
    catch {
        # Log a warning if the sheet is missing or another error occurs
        Write-Progress-Message "Warning: Sheet 'Manual Recommendations' not found or could not be imported from '$InputPath'. Error: $($_.Exception.Message)" -Color Yellow
        # $ManualRecommendations remains @() - this prevents the "Cannot index into a null array" error later
    }
    # --- END MODIFIED Import Section ---


    # Standardize the Manual Recommendations (Original logic, now safe due to init)
    $StandardizedManualRecs = @()
    # The foreach loop works fine even if $ManualRecommendations is an empty array @()
    foreach ($rec in $ManualRecommendations) {
        # Create a standardized object with unified property names (Original structure)
        $standardizedRec = [PSCustomObject]@{
            x_RecommendationDescription = $rec.Description
            x_RecommendationSolution    = $rec.RemediationAction
            x_RecommendationImpact      = $rec.RecommendationImpact
            x_ResourceType              = $rec.RecommendationResourceType
            x_RecommendationProvider    = "Manual Recommendation" # Original default
            x_RecommendationCategory    = $rec.PotentialBenefits # Original mapping
            x_RecommendationControl     = $rec.RecommendationControl
            ResourceName                = "Manual Recommendation" # Original identifier
            ResourceId                  = $rec.AcorlGuid
        }

        $StandardizedManualRecs += $standardizedRec
    }


    # Combine recommendations from both sources (Original logic, now safe)
	$AutomaticRecommendations = @($AutomaticRecommendations) # Ensure array type
	$StandardizedManualRecs = @($StandardizedManualRecs) # Ensure array type
	$AllRecommendations = $AutomaticRecommendations + $StandardizedManualRecs


    Write-Progress-Message "Combined total: $($AllRecommendations.Count) recommendations."

    # Group recommendations by impact level  
    # Assumes x_RecommendationImpact property exists, script might fail here if it doesn't and AllRecommendations isn't empty
    $HighImpactRecs = $AllRecommendations | Where-Object { $_.x_RecommendationImpact -eq "High" }
    $MediumImpactRecs = $AllRecommendations | Where-Object { $_.x_RecommendationImpact -eq "Medium" }
    $LowImpactRecs = $AllRecommendations | Where-Object { $_.x_RecommendationImpact -eq "Low" }

    Write-Progress-Message "Found $($HighImpactRecs.Count) high impact, $($MediumImpactRecs.Count) medium impact, and $($LowImpactRecs.Count) low impact recommendations."

    # Group and deduplicate recommendations to avoid duplication (Original function structure)
    function Group-UniqueRecommendations {
        param (
            $Recommendations # Original didn't strongly type
        )

        $groupedRecs = @{} # Original used standard hashtable

        foreach ($rec in $Recommendations) {
            # Create a unique key based on description and solution  
            # Assumes properties exist
            $key = "$($rec.x_RecommendationDescription)_$($rec.x_RecommendationSolution)_$($rec.x_ResourceType)"

            if (-not $groupedRecs.ContainsKey($key)) {
                $groupedRecs[$key] = @{
                    Description = $rec.x_RecommendationDescription
                    Solution = $rec.x_RecommendationSolution
                    ResourceType = $rec.x_ResourceType
                    Provider = $rec.x_RecommendationProvider
                    ResourceCount = 0
                    Resources = @() # Original used standard array
                    Source = if ($rec.ResourceName -eq "Manual Recommendation") { "Manual" } else { "Automatic" }
                }
            }

            # Increment resource count and add to list  
            $groupedRecs[$key].ResourceCount++

            # For manual recommendations, set resource count to 1 to avoid inflating counts  
            if ($rec.ResourceName -ne "Manual Recommendation") {
                $groupedRecs[$key].Resources += $rec.ResourceName
            }
        }

        # Convert hashtable to list of objects  
        $uniqueRecs = @()
        foreach ($key in $groupedRecs.Keys) {
            $uniqueRecs += [PSCustomObject]@{
                Description = $groupedRecs[$key].Description
                Solution = $groupedRecs[$key].Solution
                ResourceType = $groupedRecs[$key].ResourceType
                Provider = $groupedRecs[$key].Provider
                ResourceCount = $groupedRecs[$key].ResourceCount
                Resources = $groupedRecs[$key].Resources -join ", " # Original join logic
                Source = $groupedRecs[$key].Source
            }
        }

        return $uniqueRecs
    }

    # Group recommendations to avoid duplication  
    $UniqueHighImpactRecs = Group-UniqueRecommendations -Recommendations $HighImpactRecs
    $UniqueMediumImpactRecs = Group-UniqueRecommendations -Recommendations $MediumImpactRecs
    $UniqueLowImpactRecs = Group-UniqueRecommendations -Recommendations $LowImpactRecs

    Write-Progress-Message "After grouping: $($UniqueHighImpactRecs.Count) high impact, $($UniqueMediumImpactRecs.Count) medium impact, and $($UniqueLowImpactRecs.Count) low impact unique recommendations."

    # Create a summary of recommendations by category and type (Original structure)
    $RecommendationSummary = @{
        "High" = @{
            Count = $HighImpactRecs.Count
            UniqueCount = $UniqueHighImpactRecs.Count
            Categories = @{} # Original used standard hashtable
            Types = @{}
            Providers = @{}
            Details = $UniqueHighImpactRecs
            ManualCount = ($HighImpactRecs | Where-Object { $_.ResourceName -eq "Manual Recommendation" }).Count
            AutomaticCount = ($HighImpactRecs | Where-Object { $_.ResourceName -ne "Manual Recommendation" }).Count
        }
        "Medium" = @{
            Count = $MediumImpactRecs.Count
            UniqueCount = $UniqueMediumImpactRecs.Count
            Categories = @{}
            Types = @{}
            Providers = @{}
            Details = $UniqueMediumImpactRecs
            ManualCount = ($MediumImpactRecs | Where-Object { $_.ResourceName -eq "Manual Recommendation" }).Count
            AutomaticCount = ($MediumImpactRecs | Where-Object { $_.ResourceName -ne "Manual Recommendation" }).Count
        }
        "Low" = @{
            Count = $LowImpactRecs.Count
            UniqueCount = $UniqueLowImpactRecs.Count
            Categories = @{}
            Types = @{}
            Providers = @{}
            Details = $UniqueLowImpactRecs
            ManualCount = ($LowImpactRecs | Where-Object { $_.ResourceName -eq "Manual Recommendation" }).Count
            AutomaticCount = ($LowImpactRecs | Where-Object { $_.ResourceName -ne "Manual Recommendation" }).Count
        }
    }

    # Function to update summary data (Original function structure)
    function Update-SummaryData {
        param (
            $Recommendations, # Original didn't strongly type
            $ImpactLevel
        )

        foreach ($rec in $Recommendations) {
            # Original logic assumes these properties exist
            $category = $rec.x_RecommendationCategory
            $type = $rec.x_ResourceType
            $provider = $rec.x_RecommendationProvider

            if ($category) {
                if (-not $RecommendationSummary[$ImpactLevel].Categories.ContainsKey($category)) {
                    $RecommendationSummary[$ImpactLevel].Categories[$category] = 0
                }
                $RecommendationSummary[$ImpactLevel].Categories[$category]++
            }

            if ($type) {
                if (-not $RecommendationSummary[$ImpactLevel].Types.ContainsKey($type)) {
                    $RecommendationSummary[$ImpactLevel].Types[$type] = 0
                }
                $RecommendationSummary[$ImpactLevel].Types[$type]++
            }

            if ($provider) {
                if (-not $RecommendationSummary[$ImpactLevel].Providers.ContainsKey($provider)) {
                    $RecommendationSummary[$ImpactLevel].Providers[$provider] = 0
                }
                $RecommendationSummary[$ImpactLevel].Providers[$provider]++
            }
        }
    }

    # Original calls to Update-SummaryData
    Update-SummaryData -Recommendations $HighImpactRecs -ImpactLevel "High"
    Update-SummaryData -Recommendations $MediumImpactRecs -ImpactLevel "Medium"
    Update-SummaryData -Recommendations $LowImpactRecs -ImpactLevel "Low"

    # Function to update slide with recommendations (Original function structure)
    function Update-RecommendationSlide {
        param (
            $Slide, # Original didn't strongly type
            $Recommendations, # Original didn't strongly type
            $ImpactType
        )

        Write-Progress-Message "Updating $ImpactType impact recommendations slide..."

        # Find the table on the slide  
        $Table = $null
        foreach ($Shape in $Slide.Shapes) {
            if ($Shape.HasTable) {
                $Table = $Shape.Table
                break
            }
        }

        if ($null -eq $Table) {
            Write-Warning "No table found on the $ImpactType impact slide!"
            return
        }

        # Define how many recommendations to include  
        $MaxRows = [Math]::Min($Table.Rows.Count - 1, $Recommendations.Count)  # -1 for header row

        # Clear existing data in the table  
        for ($row = 2; $row -le $Table.Rows.Count; $row++) {
            for ($col = 1; $col -le $Table.Columns.Count; $col++) {
                $Table.Cell($row, $col).Shape.TextFrame.TextRange.Text = ""
            }
        }

        # Fill in recommendation data  
        for ($i = 0; $i -lt $MaxRows; $i++) {
            # Original script didn't check if $i was within bounds of $Recommendations, but $MaxRows handles this
            $rec = $Recommendations[$i]

            # Add index number  
            $Table.Cell($i + 2, 1).Shape.TextFrame.TextRange.Text = ($i + 1).ToString()

            # Format the recommendation text with bold "Solution:"  
            $textRange = $Table.Cell($i + 2, 2).Shape.TextFrame.TextRange

            # Add source indicator for manual recommendations  
            $sourcePrefix = if ($rec.Source -eq "Manual") { "[Manual] " } else { "" }

            # Add description first  
            $textRange.Text = $sourcePrefix + $rec.Description + "`r`n" # Original used `r`n

            # Then add solution text separately so we can format it  
            $solutionText = "Solution: " + $rec.Solution
            $solutionRange = $textRange.InsertAfter($solutionText) # Original insert logic

            # Get the position where "Solution:" starts  
            # This calculation might be fragile if description contains "Solution:"
            $solutionStart = $textRange.Text.Length - $solutionText.Length + 1
            $solutionEnd = $solutionStart + 8  # "Solution" length (Original used 8)

            # Bold just the word "Solution:"  
            $boldPart = $textRange.Characters($solutionStart, 9)  # "Solution:" (Length 9)
            $boldPart.Font.Bold = $MsoTrue # Original used MsoTrue variable

            # Format the Azure Service column  
            $serviceInfo = $rec.ResourceType -replace "microsoft.", "" # Original replacement logic
            $Table.Cell($i + 2, 3).Shape.TextFrame.TextRange.Text = $serviceInfo

            # Add the resource count to the table  
            $Table.Cell($i + 2, 4).Shape.TextFrame.TextRange.Text = $rec.ResourceCount.ToString()

            # Original script didn't explicitly set font sizes here
        }
    }

    # Function to create or update a summary slide (Original function structure)
    function Update-SummarySlide {
        param (
            $Slide # Original didn't strongly type
        )

        Write-Progress-Message "Updating summary slide..."

        # Find a text placeholder or create a new one  
        $TextShape = $null
        foreach ($Shape in $Slide.Shapes) {
            if ($Shape.HasTextFrame) {
                $TextShape = $Shape
                break # Original took the first text frame found
            }
        }

        if ($null -eq $TextShape) {
            # Define constants for MsoTextOrientation  
            $MsoTextOrientationHorizontal = 1  # Value for horizontal text orientation

            $TextShape = $Slide.Shapes.AddTextbox(
                $MsoTextOrientationHorizontal,  # Using value directly
                100, 100, 500, 400 # Original position/size
            )
        }

        # Build the summary text - using PowerPoint-friendly formatting  
        $summaryText = ""
        $summaryText += "Azure Recommendations Summary`r`n`r`n" # Original used `r`n
        $summaryText += "Impact Distribution:`r`n"
        $summaryText += "• High Impact: $($RecommendationSummary['High'].Count) resources with $($RecommendationSummary['High'].UniqueCount) unique recommendations`r`n"
        $summaryText += "    ◦ $($RecommendationSummary['High'].ManualCount) manual, $($RecommendationSummary['High'].AutomaticCount) automated recommendations`r`n"
        $summaryText += "• Medium Impact: $($RecommendationSummary['Medium'].Count) resources with $($RecommendationSummary['Medium'].UniqueCount) unique recommendations`r`n"
        $summaryText += "    ◦ $($RecommendationSummary['Medium'].ManualCount) manual, $($RecommendationSummary['Medium'].AutomaticCount) automated recommendations`r`n"
        $summaryText += "• Low Impact: $($RecommendationSummary['Low'].Count) resources with $($RecommendationSummary['Low'].UniqueCount) unique recommendations`r`n"
        $summaryText += "    ◦ $($RecommendationSummary['Low'].ManualCount) manual, $($RecommendationSummary['Low'].AutomaticCount) automated recommendations`r`n"
        $summaryText += "• Total: $($AllRecommendations.Count) total resource recommendations`r`n`r`n"

        # Add recommendations provider breakdown  
        $summaryText += "Recommendation Providers:`r`n"
        $allProviders = @($RecommendationSummary['High'].Providers.Keys +
                        $RecommendationSummary['Medium'].Providers.Keys +
                        $RecommendationSummary['Low'].Providers.Keys) |
                        Select-Object -Unique | Sort-Object

        foreach ($provider in $allProviders) {
            # Original logic assumes keys exist or returns null which becomes 0 when added
            $highCount = if ($RecommendationSummary['High'].Providers.ContainsKey($provider)) { $RecommendationSummary['High'].Providers[$provider] } else { 0 }
            $mediumCount = if ($RecommendationSummary['Medium'].Providers.ContainsKey($provider)) { $RecommendationSummary['Medium'].Providers[$provider] } else { 0 }
            $lowCount = if ($RecommendationSummary['Low'].Providers.ContainsKey($provider)) { $RecommendationSummary['Low'].Providers[$provider] } else { 0 }
            $totalCount = $highCount + $mediumCount + $lowCount

            $summaryText += "• $($provider): $totalCount total ($highCount high, $mediumCount medium, $lowCount low)`r`n"
        }
        $summaryText += "`r`n"

        # Add High Impact recommendation details  
        $summaryText += "High Impact Recommendation Details:`r`n"
        # Original sort might fail if ResourceCount doesn't exist on all objects
        foreach ($rec in $RecommendationSummary['High'].Details | Sort-Object -Property ResourceCount -Descending) {
            $sourcePrefix = if ($rec.Source -eq "Manual") { "[Manual] " } else { "" }
            # Original logic assumes properties exist
            $summaryText += "• $sourcePrefix$($rec.Description) ($($rec.ResourceCount) resources)`r`n"
            $summaryText += "  ◦ Solution: $($rec.Solution)`r`n"
            $summaryText += "  ◦ Resource Type: $($rec.ResourceType -replace 'microsoft.', '')`r`n" # Original replacement
            $summaryText += "  ◦ Provider: $($rec.Provider)`r`n"
            $summaryText += "`r`n"
        }

        # Add resource type breakdown  
        $summaryText += "Affected Resource Types:`r`n"
        $allTypes = @($RecommendationSummary['High'].Types.Keys +
                      $RecommendationSummary['Medium'].Types.Keys +
                      $RecommendationSummary['Low'].Types.Keys) |
                      Select-Object -Unique | Sort-Object

        foreach ($type in $allTypes) {
             # Original logic assumes keys exist or returns null which becomes 0 when added
            $highCount = if ($RecommendationSummary['High'].Types.ContainsKey($type)) { $RecommendationSummary['High'].Types[$type] } else { 0 }
            $mediumCount = if ($RecommendationSummary['Medium'].Types.ContainsKey($type)) { $RecommendationSummary['Medium'].Types[$type] } else { 0 }
            $lowCount = if ($RecommendationSummary['Low'].Types.ContainsKey($type)) { $RecommendationSummary['Low'].Types[$type] } else { 0 }
            $totalCount = $highCount + $mediumCount + $lowCount

            $formattedType = $type -replace "microsoft.", "" # Original replacement
            $summaryText += "• $($formattedType): $totalCount total ($highCount high, $mediumCount medium, $lowCount low)`r`n"
        }

        # Set the summary text  
        $TextShape.TextFrame.TextRange.Text = $summaryText
        # Original script didn't set font size here

        # Apply formatting (Original function structure)
        $textRange = $TextShape.TextFrame.TextRange

        # Function to safely find and format text (Original function structure)
        function Format-TextInRange {
            param (
                $Range,
                $TextToFind,
                [switch]$Bold,
                [switch]$Underline,
                [int]$Size = 0
            )
            # Original function used MsoTrue variable defined earlier
            $MsoTrue = 1 # Define locally for safety

            $text = $Range.Text
            $position = $text.IndexOf($TextToFind) # Case-sensitive IndexOf

            if ($position -ge 0) {
                $length = $TextToFind.Length
                $targetRange = $Range.Characters(($position + 1), $length) # 1-based index

                if ($Bold) {
                    $targetRange.Font.Bold = $MsoTrue
                }

                if ($Underline) {
                    # Original used $MsoTrue, but underline can have different types
                    # Using simple True might map to single underline
                    $targetRange.Font.Underline = $MsoTrue
                }

                if ($Size -gt 0) {
                    $targetRange.Font.Size = $Size
                }
            }
            # Original function didn't loop or return anything
        }

        # Format headings  
        Format-TextInRange -Range $textRange -TextToFind "Azure Recommendations Summary" -Bold -Size 24
        Format-TextInRange -Range $textRange -TextToFind "Impact Distribution:" -Bold -Underline -Size 16
        Format-TextInRange -Range $textRange -TextToFind "Recommendation Providers:" -Bold -Underline -Size 16
        Format-TextInRange -Range $textRange -TextToFind "High Impact Recommendation Details:" -Bold -Underline -Size 16
        Format-TextInRange -Range $textRange -TextToFind "Affected Resource Types:" -Bold -Underline -Size 16

        # Bold all instances of "Solution:"  
        $text = $textRange.Text
        $currentPos = 0
        while ($true) {
            $position = $text.IndexOf("Solution:", $currentPos) # Case-sensitive
            if ($position -lt 0) { break }

            $targetRange = $textRange.Characters(($position + 1), 9)  # "Solution:"
            $targetRange.Font.Bold = $MsoTrue

            $currentPos = $position + 9 # Move past "Solution:"
        }

        # Bold all instances of "[Manual]"  
        $text = $textRange.Text
        $currentPos = 0
        while ($true) {
            $position = $text.IndexOf("[Manual]", $currentPos) # Case-sensitive
            if ($position -lt 0) { break }

            $targetRange = $textRange.Characters(($position + 1), 8)  # "[Manual]"
            $targetRange.Font.Bold = $MsoTrue

            $currentPos = $position + 8 # Move past "[Manual]"
        }
    }

    # Update each slide with appropriate recommendations  
    # Note: PowerPoint slides are 1-indexed
    # Original script didn't check if slide indices were valid
    Update-RecommendationSlide -Slide $Presentation.Slides.Item(14) -Recommendations $UniqueHighImpactRecs -ImpactType "High"
    Update-RecommendationSlide -Slide $Presentation.Slides.Item(15) -Recommendations $UniqueMediumImpactRecs -ImpactType "Medium"
    Update-RecommendationSlide -Slide $Presentation.Slides.Item(16) -Recommendations $UniqueLowImpactRecs -ImpactType "Low"

    # Create or update summary slide if requested (Original call)
    # Original script didn't check if slide index was valid
    if ($CreateSummary) {
        Update-SummarySlide -Slide $Presentation.Slides.Item($SummarySlide)
    }

    # Save the presentation to the new file  
    Write-Progress-Message "Saving presentation to: $OutputPath"
    $Presentation.SaveAs($OutputPath) # Original didn't resolve path

    # Clean up  
    $Presentation.Close()
    $PowerPoint.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Presentation) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($PowerPoint) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    Write-Progress-Message "PowerPoint update completed successfully!" -Color "Green"
    Write-Progress-Message "New presentation saved to: $OutputPath" -Color "Green"

} catch {
    # Original catch block
    Write-Host "An error occurred: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red

    # Clean up in case of error  
    if ($null -ne $Presentation) {
        $Presentation.Close() # Original didn't specify save options on close during error
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Presentation) | Out-Null
    }

    if ($null -ne $PowerPoint) {
        $PowerPoint.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($PowerPoint) | Out-Null
    }

    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}
