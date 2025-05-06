# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Creates PBIT files for each Power BI project.

    .PARAMETER Name
    Name of the report to build. Wildcards supported. Default = * (all).

    .PARAMETER -KQL
    Indicates if the KQL reports should be generated. Default = false (will build all if no types are selected).

    .PARAMETER -Storage
    Indicates if the storage reports should be generated. Default = false (will build all if no types are selected).

    .EXAMPLE
    ./Build-PowerBI

    Generates all PBIT files.

    .EXAMPLE
    ./Build-PowerBI CostSummary -Storage

    Generates the Cost summary storage PBIT file.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-build-powerbi
#>
param(
    [Parameter(Position = 0)]
    [string]
    $Name = "*",

    [switch]
    $KQL,

    [switch]
    $Storage
)

$srcDir = "$PSScriptRoot/../power-bi"
$relDir = "$PSScriptRoot/../../release"
$pbipDir = "$relDir/pbip"
$pbitDir = "$relDir/pbit"

$version = & "$PSScriptRoot/Get-Version"

if (-not $KQL -and -not $Storage) { $KQL = $Storage = $true }

# Cleanup
Write-Verbose "Removing existing ZIP files..."
if ($KQL)
{ 
    Remove-Item "$pbitDir/../PowerBI-kql.zip" -Force -ErrorAction SilentlyContinue
    Remove-Item "$pbitDir/*.kql.pbit" -Force -ErrorAction SilentlyContinue
}
if ($Storage)
{ 
    Remove-Item "$pbitDir/../PowerBI-storage.zip" -Force -ErrorAction SilentlyContinue
    Remove-Item "$pbitDir/*.storage.pbit" -Force -ErrorAction SilentlyContinue
}

# Select report types
$types = @()
if ($KQL) { $types += "*$Name*.kql.pbip" } # cSpell:ignore PBIP
if ($Storage) { $types += "*$Name*.storage.pbip" }

# Get reports
$reports = Get-ChildItem $srcDir -Recurse -Include $types
Write-Host "Building $($reports.Count) Power BI report template$(if ($reports.Count -ne 1) { 's' })..."

function Write-UTF16LE($File, $Content, $Json)
{
    Write-Verbose "  Writing UTF-16LE file: $($File.Name)..."
    if ($Json) { $Content = [PSCustomObject]$Json | ConvertTo-Json -Depth 5 -Compress }
    [System.IO.File]::WriteAllBytes($File, [System.Text.Encoding]::Unicode.GetBytes($Content))
}

# Setup dependencies
if (-not (Get-Package Microsoft.AnalysisServices -ErrorAction SilentlyContinue))
{
    # $adminCheck = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    # $isAdmin = $adminCheck.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    # Write-Host "The Microsoft.AnalysisServices package is required to build the data model."
    # if ($isAdmin)
    # {
    #     Write-Host "  This window cannot run admin commands."
    #     Write-Host "  ⚠️ Please run this command in an admin elevated prompt: Install-Package Microsoft.AnalysisServices -ProviderName NuGet"
    #     return
    # }
    # else
    # {
    #     Write-Host "  Installing the the Analysis Services package..."
    #     Install-Package Microsoft.AnalysisServices -Force
    # }

    Write-Verbose "  Installing the the Analysis Services package..."
    Write-Verbose "  PRO TIP: Install via an admin prompt to speed up future runs!"
    Install-Package -Name Microsoft.AnalysisServices -ProviderName NuGet -Scope CurrentUser -Force
}

$dllPath = "$((Get-Item (Get-Package Microsoft.AnalysisServices).Source).Directory)/lib/net8.0/Microsoft.AnalysisServices.Tabular.dll"
Write-Verbose "  Adding type from $dllPath"
Add-Type -Path $dllPath

# Loop thru reports
$reports | ForEach-Object {
    $inputFile = $_
    $reportName = $inputFile.Name.Split('.')[0]
    $folder = $inputFile.DirectoryName
    $reportDir = "$folder/$reportName.Report"
    $datasetDir = "$folder/Shared.Dataset"
    $reportType = $inputFile.Name.Split('.')[1] # Extract "kql" or "storage" from filename
    Write-Verbose "Processing $($inputFile.Name)..."

    $metadata = @{
        CostSummary          = @{
            Intro       = "The Cost summary report provides several summaries of your effective (amortized) and billed costs based on the FinOps Open Cost and Usage Specification (FOCUS). Amortization breaks down reservation and savings plan purchases and allocates costs to the resources that received the benefit. Effective costs will not match your invoice."
            Tables      = @("Costs", "Prices", "PricingUnits")
            Expressions = @("▶️  START HERE", "Cluster URL", "[storage]Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Deprecated: Perform Extra Query Optimizations", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
        }
        DataIngestion        = @{
            Intro       = "The Data ingestion report provides details about the data you've ingested into your FinOps hub storage account."
            Tables      = @("Costs", "HubScopes", "HubSettings", "Prices", "PricingUnits", "StorageData", "StorageErrors")
            Expressions = @("▶️  START HERE", "Cluster URL", "Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Deprecated: Perform Extra Query Optimizations", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
        }
        Governance           = @{
            Intro       = "The Cloud policy and governance report summarizes your Microsoft Cloud governance posture. It offers the standard metrics aligned with the Cloud Adoption Framework to facilitate identifying issues, applying recommendations, and resolving compliance gaps."
            Tables      = @("AdvisorRecommendations", "Compliance calculation", "Costs", "Disks", "ManagementGroups", "NetworkInterfaces", "NetworkSecurityGroups", "PolicyAssignments", "PolicyDefinitions", "PolicyStates", "Prices", "PricingUnits", "PublicIPAddresses", "Regions", "Resources", "ResourceTypes", "SqlDatabases", "Subscriptions", "VirtualMachines")
            Expressions = @("▶️  START HERE", "Cluster URL", "[storage]Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Remove Duplicate Resource IDs", "Deprecated: Perform Extra Query Optimizations", "ftk_DemoFilter", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
        }
        RateOptimization     = @{
            Intro       = "The Rate optimization report provides insights into any workload optimization opportunities, like reservations, savings plans, and Azure Hybrid Benefit. This reports uses effective cost, which amortizes and breaks reservation and savings plan purchases down and allocates costs out to the resources that received the benefit. Effective cost will not match your invoice."
            Tables      = @("Costs", "InstanceSizeFlexibility", "Prices", "PricingUnits", "ReservationRecommendations")
            Expressions = @("▶️  START HERE", "Cluster URL", "[storage]Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Deprecated: Perform Extra Query Optimizations", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
        }
        WorkloadOptimization = @{
            Intro       = "The Workload optimization report provides insights into resource utilization and efficiency opportunities based on historical usage patterns. Use this report to determine if resources can be scaled down or even shutdown during off-peak hours to minimize wasteful usage and spending. Also consider cheaper alternatives when available and ensure all workloads have some direct or indirect link to business value to avoid unnecessary usage and costs that don't contribute to the mission."
            Tables      = @("AdvisorRecommendations", "Costs", "Disks", "Prices", "PricingUnits", "Resources", "Subscriptions")
            Expressions = @("▶️  START HERE", "Cluster URL", "[storage]Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Remove Duplicate Resource IDs", "Deprecated: Perform Extra Query Optimizations", "ftk_DemoFilter", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
        }
    }[$reportName]

    # Create folder structure
    $targetFile = "$pbitDir/$($inputFile.Name.Replace('.pbip', ''))"
    Remove-Item $targetFile -Recurse -Force -ErrorAction SilentlyContinue
    & "$PSScriptRoot/New-Directory.ps1" $targetFile
    & "$PSScriptRoot/New-Directory.ps1" "$targetFile/Report"

    # DataModelSchema
    $model = [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeDatabaseFromFolder("$datasetDir/definition") # cSpell:ignore TMDL
    $modelJson = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($model) | ConvertFrom-Json -Depth 100 -AsHashtable
    $modelJson.name = [guid]::NewGuid()
    $modelJson.model.expressions `
    | ForEach-Object {
        $exp = $_
        if ($exp.name.EndsWith(' URL'))
        {
            $exp.expression = $exp.expression -replace '^\\"[^\\"]+\\" meta ', 'null meta '
        }
        if ($exp.name -eq 'ftk_DemoFilter')
        {
            $exp.expression = '() => "" // To filter out subscriptions, replace with: "| where subscriptionId in (''<sub1>'', ''<sub2>'')"'
        }
    }
    $modelJson.model.tables = $modelJson.model.tables | Where-Object { $metadata.Tables -contains $_.name -or $metadata.Tables -contains "[$reportType]$($_.name)" }
    $modelJson.model.relationships `
    | Where-Object { -not (($metadata.Tables -contains $_.fromTable -or $metadata.Tables -contains "[$reportType]$($_.fromTable)") -and ($metadata.Tables -contains $_.toTable -or $metadata.Tables -contains "[$reportType]$($_.toTable)")) } `
    | ForEach-Object { Write-Verbose "  Removing relationship: $($_.fromTable) -> $($_.toTable)" }
    $modelJson.model.relationships = @($modelJson.model.relationships | Where-Object { ($metadata.Tables -contains $_.fromTable -or $metadata.Tables -contains "[$reportType]$($_.fromTable)") -and ($metadata.Tables -contains $_.toTable -or $metadata.Tables -contains "[$reportType]$($_.toTable)") })
    $modelJson.model.expressions = $modelJson.model.expressions | Where-Object { $metadata.Expressions -contains $_.name -or $metadata.Expressions -contains "[$reportType]$($_.name)" }
    $modelJson.model.annotations = $modelJson.model.annotations `
    | ForEach-Object {
        $ann = $_
        if ($ann.name -eq 'PBI_QueryOrder')
        {
            $ann.value = ($metadata.Expressions + $metadata.Tables) | ConvertTo-Json -Depth 1 -Compress | ConvertTo-Json -Depth 1
        }
        return $ann
    }
    Write-UTF16LE -File "$targetFile/DataModelSchema" -Content ($modelJson | ConvertTo-Json -Depth 100)

    # DiagramLayout
    Write-UTF16LE -File "$targetFile/DiagramLayout" -Json (Get-Content "$datasetDir/diagramLayout.json" -Raw | ConvertFrom-Json -Depth 100)

    # Report/Layout
    $reportJson = (Get-Content "$reportDir/report.json" -Raw) `
        -replace '\$\$ftkver\$\$', $version `
        -replace '\$\$build-date\$\$', (Get-Date -Format 'yyyy-MM-dd')
    Write-UTF16LE -File "$targetFile/Report/Layout" -Json ($reportJson | ConvertFrom-Json -Depth 100)

    # Report/StaticResources
    Copy-Item "$reportDir/StaticResources" "$targetFile/Report/StaticResources" -Recurse -Force

    # Metadata
    # TODO: Where does "Version" come from?
    # TODO: Add all intro paragraphs
    # TODO: Add Load button guidance
    $desktopVersion = $modelJson.model.annotations | Where-Object { $_.name -eq 'PBIDesktopVersion' } | ForEach-Object { $_.value }
    Write-Verbose "  Desktop version: '$desktopVersion'"
    Write-UTF16LE -File "$targetFile/Metadata" -Json @{
        Version                  = 5
        AutoCreatedRelationships = @()
        FileDescription          = "$($metadata.Intro)`n`nTo customize queries or data source settings, select the Edit option in the Load button.`n`nLearn more at https://aka.ms/ftk/pbi/$reportName"
        CreatedFrom              = "Cloud"
        # TODO: Validate "CreatedFromRelease"
        CreatedFromRelease       = "20$($desktopVersion -replace '^[^\(]+\(([0-9]{2}\.[0-2][0-9])\)[^\)]+$','$1')"
    }

    # Settings
    $editorSettings = Get-Content "$datasetDir/.pbi/editorSettings.json" | ConvertFrom-Json
    Write-UTF16LE -File "$targetFile/Settings" -Json @{
        Version         = 4
        ReportSettings  = @{
            UserConsentsToCompositeModels            = $true
            ShouldNotifyUserOfNameConflictResolution = $false
        }
        QueriesSettings = @{
            TypeDetectionEnabled      = $editorSettings.typeDetectionEnabled
            RelationshipImportEnabled = $editorSettings.relationshipImportEnabled
            # TODO: Validate "Version"
            Version                   = $desktopVersion.Split(' ')[0]
        }
    }

    # Version
    # TODO: Where the "Version" file content come from?
    Write-UTF16LE -File "$targetFile/Version" -Content "1.30"

    # [Content_Types].xml
    @(
        '<?xml version="1.0" encoding="utf-8"?>',
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
        '<Default Extension="svg" ContentType="" />',
        '<Default Extension="png" ContentType="" />',
        '<Default Extension="json" ContentType="" />',
        '<Override PartName="/Version" ContentType="" />',
        '<Override PartName="/DataModelSchema" ContentType="" />',
        '<Override PartName="/DiagramLayout" ContentType="" />',
        '<Override PartName="/Report/Layout" ContentType="" />',
        '<Override PartName="/Settings" ContentType="application/json" />',
        '<Override PartName="/Metadata" ContentType="application/json" />',
        '</Types>'
    ) -join , '' `
    | Out-File -LiteralPath "$targetFile/[Content_Types].xml" -Encoding utf8

    # Create PBIT file
    Compress-Archive -Path "$targetFile/*" -DestinationPath "$targetFile.pbit"

    Remove-Item $targetFile -Recurse -Force
}

# Zip files
$genAllReports = $Name -eq '*'
if ($KQL -and $genAllReports) { Compress-Archive -Path "$pbitDir/*.kql.pbit" -DestinationPath "$pbitDir/../PowerBI-kql.zip" }
if ($Storage -and $genAllReports) { Compress-Archive -Path "$pbitDir/*.storage.pbit" -DestinationPath "$pbitDir/../PowerBI-storage.zip" }
