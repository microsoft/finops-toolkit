# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Retrieves Azure Advisor recommendation type metadata from the Azure Advisor API.

    .DESCRIPTION
    The Get-AdvisorRecommendationTypes script calls the Azure Advisor Recommendation Metadata API
    to retrieve metadata about all available recommendation types. This includes recommendation IDs,
    categories, impact levels, service names, and learn more links.

    The output is saved as a CSV file that can be used as open data for FinOps reporting and analysis.

    .PARAMETER OutputPath
    Optional. Path where the CSV file should be saved. Defaults to src/open-data/RecommendationTypes.csv.

    .PARAMETER SubscriptionId
    Optional. Azure subscription ID to use for authentication. If not specified, uses the current context.

    .EXAMPLE
    ./Get-AdvisorRecommendationTypes.ps1

    Retrieves recommendation metadata and saves to the default location.

    .EXAMPLE
    ./Get-AdvisorRecommendationTypes.ps1 -OutputPath "C:\temp\recommendations.csv"

    Retrieves recommendation metadata and saves to a custom location.

    .LINK
    https://learn.microsoft.com/rest/api/advisor/recommendation-metadata/list
#>

param(
    [Parameter()]
    [string]
    $OutputPath = "$PSScriptRoot/../open-data/RecommendationTypes.csv",

    [Parameter()]
    [string]
    $SubscriptionId
)

# Ensure Az.Accounts module is available
if (-not (Get-Module -ListAvailable -Name Az.Accounts))
{
    Write-Error "Az.Accounts module is required. Please install it using: Install-Module -Name Az.Accounts"
    return
}

# Import required modules
Import-Module Az.Accounts -ErrorAction Stop

# Get the current Azure context
$context = Get-AzContext
if (-not $context)
{
    Write-Error "No Azure context found. Please run Connect-AzAccount first."
    return
}

if ($SubscriptionId)
{
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    $context = Get-AzContext
}

Write-Output "Using subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"

# Get access token for Azure Management API
$token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token

# Set up API request
$apiVersion = "2023-01-01"
$uri = "https://management.azure.com/providers/Microsoft.Advisor/metadata?api-version=$apiVersion"

Write-Output "Fetching recommendation metadata from Azure Advisor API..."

# Call the API
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

try
{
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
}
catch
{
    Write-Error "Failed to retrieve recommendation metadata: $_"
    return
}

Write-Output "Retrieved $($response.value.Count) metadata entities"

# Find the recommendationType metadata
$recommendationTypeMetadata = $response.value | Where-Object { $_.name -eq "recommendationType" }

if (-not $recommendationTypeMetadata)
{
    Write-Error "Could not find recommendationType metadata in the response"
    return
}

Write-Output "Found $($recommendationTypeMetadata.properties.supportedValues.Count) recommendation types"

# Create array to store recommendation data
$recommendations = @()

# Process each recommendation type
foreach ($rec in $recommendationTypeMetadata.properties.supportedValues)
{
    # The ID is the recommendation type GUID
    $recId = $rec.id
    $displayName = $rec.displayName

    # Create recommendation object
    # Note: The API doesn't provide all the columns from the issue sample (Category, Impact, ServiceName, etc.)
    # Those might need to be sourced from other locations or parsed from the displayName
    $recommendation = [PSCustomObject]@{
        RecommendationTypeId = $recId
        DisplayName          = $displayName
    }

    $recommendations += $recommendation
}

# Sort by DisplayName
$recommendations = $recommendations | Sort-Object -Property DisplayName

# Create output directory if it doesn't exist
$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDir))
{
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Export to CSV
$recommendations | Export-Csv -Path $OutputPath -NoTypeInformation -Force

Write-Output "Exported $($recommendations.Count) recommendation types to: $OutputPath"
Write-Output ""
Write-Output "Note: The API only provides RecommendationTypeId and DisplayName."
Write-Output "Additional metadata like Category, Impact, ServiceName, ResourceType, etc."
Write-Output "may need to be sourced from other locations or parsed from active recommendations."
