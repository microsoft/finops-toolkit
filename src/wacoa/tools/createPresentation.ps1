# Enhanced PowerPoint Updater Script for Azure Recommendations
# Purpose: Updates PowerPoint presentation with recommendations from a multi-tab Excel file
# Features:
#  - Processes both "Manual Recommendations" and "Recommendations" tabs
#  - Skips the "Well-Architected Assessment" tab
#  - Updates slides 14 (High Impact), 15 (Medium Impact), 16 (Low Impact)
#  - Groups similar recommendations and shows accurate resource counts
#  - Creates a summary of recommendations by impact level
#  - Creates a new PPT file with timestamp

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

# Function to display script progress
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
    # Define constants for MsoTriState (since direct reference is failing)
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
    
    # Import the "Recommendations" sheet
    Write-Progress-Message "Processing 'Recommendations' sheet..."
    $AutomaticRecommendations = Import-Excel -Path $InputPath -WorksheetName "Recommendations"
    Write-Progress-Message "Found $($AutomaticRecommendations.Count) recommendations in 'Recommendations' sheet."
    
    # Import the "Manual Recommendations" sheet
    Write-Progress-Message "Processing 'Manual Recommendations' sheet..."
    $ManualRecommendations = Import-Excel -Path $InputPath -WorksheetName "Manual Recommendations"
    Write-Progress-Message "Found $($ManualRecommendations.Count) recommendations in 'Manual Recommendations' sheet."
    
    # Standardize the Manual Recommendations to match the structure of Automatic Recommendations
    $StandardizedManualRecs = @()
    foreach ($rec in $ManualRecommendations) {
        # Create a standardized object with unified property names
        $standardizedRec = [PSCustomObject]@{
            x_RecommendationDescription = $rec.Description
            x_RecommendationSolution = $rec.RemediationAction
            x_RecommendationImpact = $rec.RecommendationImpact
            x_ResourceType = $rec.RecommendationResourceType
            x_RecommendationProvider = "Manual Recommendation"
            x_RecommendationCategory = $rec.PotentialBenefits
            x_RecommendationControl = $rec.RecommendationControl
            ResourceName = "Manual Recommendation"
            ResourceId = $rec.AcorlGuid
        }
        
        $StandardizedManualRecs += $standardizedRec
    }
    
    # Combine recommendations from both sources
    $AllRecommendations = $AutomaticRecommendations + $StandardizedManualRecs
    Write-Progress-Message "Combined total: $($AllRecommendations.Count) recommendations."
    
    # Group recommendations by impact level
    $HighImpactRecs = $AllRecommendations | Where-Object { $_.x_RecommendationImpact -eq "High" }
    $MediumImpactRecs = $AllRecommendations | Where-Object { $_.x_RecommendationImpact -eq "Medium" }
    $LowImpactRecs = $AllRecommendations | Where-Object { $_.x_RecommendationImpact -eq "Low" }
    
    Write-Progress-Message "Found $($HighImpactRecs.Count) high impact, $($MediumImpactRecs.Count) medium impact, and $($LowImpactRecs.Count) low impact recommendations."
    
    # Group and deduplicate recommendations to avoid duplication
    function Group-UniqueRecommendations {
        param (
            $Recommendations
        )
        
        $groupedRecs = @{}
        
        foreach ($rec in $Recommendations) {
            # Create a unique key based on description and solution
            $key = "$($rec.x_RecommendationDescription)_$($rec.x_RecommendationSolution)_$($rec.x_ResourceType)"
            
            if (-not $groupedRecs.ContainsKey($key)) {
                $groupedRecs[$key] = @{
                    Description = $rec.x_RecommendationDescription
                    Solution = $rec.x_RecommendationSolution
                    ResourceType = $rec.x_ResourceType
                    Provider = $rec.x_RecommendationProvider
                    ResourceCount = 0
                    Resources = @()
                    Source = if ($rec.ResourceName -eq "Manual Recommendation") { "Manual" } else { "Automatic" }
                }
            }
            
            # Increment resource count and add to list (only for automatic recommendations)
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
                Resources = $groupedRecs[$key].Resources -join ", "
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
    
    # Create a summary of recommendations by category and type
    $RecommendationSummary = @{
        "High" = @{
            Count = $HighImpactRecs.Count
            UniqueCount = $UniqueHighImpactRecs.Count
            Categories = @{}
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
    
    # Function to update summary data
    function Update-SummaryData {
        param (
            $Recommendations,
            $ImpactLevel
        )
        
        foreach ($rec in $Recommendations) {
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
    
    Update-SummaryData -Recommendations $HighImpactRecs -ImpactLevel "High"
    Update-SummaryData -Recommendations $MediumImpactRecs -ImpactLevel "Medium"
    Update-SummaryData -Recommendations $LowImpactRecs -ImpactLevel "Low"
    
    # Function to update slide with recommendations
    function Update-RecommendationSlide {
        param (
            $Slide,
            $Recommendations,
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
        
        # Define how many recommendations to include (up to table capacity or available recs)
        $MaxRows = [Math]::Min($Table.Rows.Count - 1, $Recommendations.Count)  # -1 for header row
        
        # Clear existing data in the table (except header row)
        for ($row = 2; $row -le $Table.Rows.Count; $row++) {
            for ($col = 1; $col -le $Table.Columns.Count; $col++) {
                $Table.Cell($row, $col).Shape.TextFrame.TextRange.Text = ""
            }
        }
        
        # Fill in recommendation data
        for ($i = 0; $i -lt $MaxRows; $i++) {
            if ($i -lt $Recommendations.Count) {
                $rec = $Recommendations[$i]
                
                # Add index number
                $Table.Cell($i + 2, 1).Shape.TextFrame.TextRange.Text = ($i + 1).ToString()
                
                # Format the recommendation text with bold "Solution:"
                $textRange = $Table.Cell($i + 2, 2).Shape.TextFrame.TextRange
                
                # Add source indicator for manual recommendations
                $sourcePrefix = if ($rec.Source -eq "Manual") { "[Manual] " } else { "" }
                
                # Add description first
                $textRange.Text = $sourcePrefix + $rec.Description + "`r`n"
                
                # Then add solution text separately so we can format it
                $solutionText = "Solution: " + $rec.Solution
                $solutionRange = $textRange.InsertAfter($solutionText)
                
                # Get the position where "Solution:" starts
                $solutionStart = $textRange.Text.Length - $solutionText.Length + 1
                $solutionEnd = $solutionStart + 8  # "Solution" length
                
                # Bold just the word "Solution:"
                $boldPart = $textRange.Characters($solutionStart, 9)  # "Solution:"
                $boldPart.Font.Bold = $MsoTrue
                
                # Format the Azure Service column
                $serviceInfo = $rec.ResourceType -replace "microsoft.", ""
                $Table.Cell($i + 2, 3).Shape.TextFrame.TextRange.Text = $serviceInfo
                
                # Add the resource count to the table
                $Table.Cell($i + 2, 4).Shape.TextFrame.TextRange.Text = $rec.ResourceCount.ToString()
            }
        }
    }
    
    # Function to create or update a summary slide
    function Update-SummarySlide {
        param (
            $Slide
        )
        
        Write-Progress-Message "Updating summary slide..."
        
        # Find a text placeholder or create a new one
        $TextShape = $null
        foreach ($Shape in $Slide.Shapes) {
            if ($Shape.HasTextFrame) {
                $TextShape = $Shape
                break
            }
        }
        
        if ($null -eq $TextShape) {
            # Define constants for MsoTextOrientation
            $MsoTextOrientationHorizontal = 1  # Value for horizontal text orientation
            
            $TextShape = $Slide.Shapes.AddTextbox(
                $MsoTextOrientationHorizontal,  # Using value directly
                100, 100, 500, 400
            )
        }
        
        # Build the summary text - using PowerPoint-friendly formatting
        $summaryText = ""
        $summaryText += "Azure Recommendations Summary`r`n`r`n"
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
            $highCount = if ($RecommendationSummary['High'].Providers.ContainsKey($provider)) { $RecommendationSummary['High'].Providers[$provider] } else { 0 }
            $mediumCount = if ($RecommendationSummary['Medium'].Providers.ContainsKey($provider)) { $RecommendationSummary['Medium'].Providers[$provider] } else { 0 }
            $lowCount = if ($RecommendationSummary['Low'].Providers.ContainsKey($provider)) { $RecommendationSummary['Low'].Providers[$provider] } else { 0 }
            $totalCount = $highCount + $mediumCount + $lowCount
            
            $summaryText += "• $($provider): $totalCount total ($highCount high, $mediumCount medium, $lowCount low)`r`n"
        }
        $summaryText += "`r`n"
        
        # Add High Impact recommendation details
        $summaryText += "High Impact Recommendation Details:`r`n"
        foreach ($rec in $RecommendationSummary['High'].Details | Sort-Object -Property ResourceCount -Descending) {
            $sourcePrefix = if ($rec.Source -eq "Manual") { "[Manual] " } else { "" }
            $summaryText += "• $sourcePrefix$($rec.Description) ($($rec.ResourceCount) resources)`r`n"
            $summaryText += "  ◦ Solution: $($rec.Solution)`r`n"
            $summaryText += "  ◦ Resource Type: $($rec.ResourceType -replace 'microsoft.', '')`r`n"
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
            $highCount = if ($RecommendationSummary['High'].Types.ContainsKey($type)) { $RecommendationSummary['High'].Types[$type] } else { 0 }
            $mediumCount = if ($RecommendationSummary['Medium'].Types.ContainsKey($type)) { $RecommendationSummary['Medium'].Types[$type] } else { 0 }
            $lowCount = if ($RecommendationSummary['Low'].Types.ContainsKey($type)) { $RecommendationSummary['Low'].Types[$type] } else { 0 }
            $totalCount = $highCount + $mediumCount + $lowCount
            
            $formattedType = $type -replace "microsoft.", ""
            $summaryText += "• $($formattedType): $totalCount total ($highCount high, $mediumCount medium, $lowCount low)`r`n"
        }
        
        # Set the summary text
        $TextShape.TextFrame.TextRange.Text = $summaryText
        
        # Apply formatting
        $textRange = $TextShape.TextFrame.TextRange
        
        # Function to safely find and format text
        function Format-TextInRange {
            param (
                $Range,
                $TextToFind,
                [switch]$Bold,
                [switch]$Underline,
                [int]$Size = 0
            )
            
            $text = $Range.Text
            $position = $text.IndexOf($TextToFind)
            
            if ($position -ge 0) {
                $length = $TextToFind.Length
                $targetRange = $Range.Characters(($position + 1), $length)
                
                if ($Bold) {
                    $targetRange.Font.Bold = $MsoTrue
                }
                
                if ($Underline) {
                    $targetRange.Font.Underline = $MsoTrue
                }
                
                if ($Size -gt 0) {
                    $targetRange.Font.Size = $Size
                }
            }
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
            $position = $text.IndexOf("Solution:", $currentPos)
            if ($position -lt 0) { break }
            
            $targetRange = $textRange.Characters(($position + 1), 9)  # "Solution:"
            $targetRange.Font.Bold = $MsoTrue
            
            $currentPos = $position + 9
        }
        
        # Bold all instances of "[Manual]"
        $text = $textRange.Text
        $currentPos = 0
        while ($true) {
            $position = $text.IndexOf("[Manual]", $currentPos)
            if ($position -lt 0) { break }
            
            $targetRange = $textRange.Characters(($position + 1), 8)  # "[Manual]"
            $targetRange.Font.Bold = $MsoTrue
            
            $currentPos = $position + 8
        }
    }
    
    # Update each slide with appropriate recommendations
    # Note: PowerPoint slides are 1-indexed
    Update-RecommendationSlide -Slide $Presentation.Slides.Item(14) -Recommendations $UniqueHighImpactRecs -ImpactType "High"
    Update-RecommendationSlide -Slide $Presentation.Slides.Item(15) -Recommendations $UniqueMediumImpactRecs -ImpactType "Medium"
    Update-RecommendationSlide -Slide $Presentation.Slides.Item(16) -Recommendations $UniqueLowImpactRecs -ImpactType "Low"
    
    # Create or update summary slide if requested
    if ($CreateSummary) {
        Update-SummarySlide -Slide $Presentation.Slides.Item($SummarySlide)
    }
    
    # Save the presentation to the new file
    Write-Progress-Message "Saving presentation to: $OutputPath"
    $Presentation.SaveAs($OutputPath)
    
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
    Write-Host "An error occurred: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    
    # Clean up in case of error
    if ($null -ne $Presentation) {
        $Presentation.Close()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Presentation) | Out-Null
    }
    
    if ($null -ne $PowerPoint) {
        $PowerPoint.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($PowerPoint) | Out-Null
    }
    
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}