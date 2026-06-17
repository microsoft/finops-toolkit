# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Multi-threaded Azure VM quota analysis script that queries compute resource SKU availability,
    quota usage, and availability zone restrictions across subscriptions using Azure CLI.

.DESCRIPTION
    This script analyzes Azure VM quota usage and availability zone restrictions across multiple
    subscriptions and regions. It provides detailed information about:
    - Current quota usage vs. limits for VM families
    - Available and restricted availability zones per SKU
    - Region-level restrictions for specific VM SKUs
    - Physical vs. logical availability zone mappings

    The Catalogs API is the primary SKU source. The deprecated meter data CSV is used only as a
    fallback when Catalogs API lookup fails and the SKUs parameter is not provided.

    The script supports multi-threading for faster execution across large numbers of subscriptions
    and can normalize zone information to physical zones for cross-subscription deployment planning.

    This is the Azure CLI variant of Get-AzVMQuotaUsage.ps1. It uses `az` commands exclusively
    and does not require the Azure PowerShell (Az) module.

.PARAMETER SKUs
    Array of VM SKU names to analyze. If not specified, resolves VM SKUs from the Azure Catalogs
    API first and falls back to the deprecated meter data CSV only if that lookup fails.
    Example: @('Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_E4s_v5')

.PARAMETER Locations
    Array of Azure regions to analyze. If not specified, queries all physical Azure regions.
    Example: @('eastus', 'westus2', 'centralus')

.PARAMETER SubscriptionIds
    Array of subscription IDs to analyze. If not specified, queries all accessible subscriptions.
    Example: @('00000000-0000-0000-0000-000000000000')

.PARAMETER MeterDataUri
    Deprecated fallback source URI for normalized VM SKU data from Cost Management connector data.
    Used only when the Catalogs API lookup fails and the SKUs parameter is not provided.

.PARAMETER CatalogLocation
    Azure region used for Catalogs API requests when resolving VM SKU names from the primary SKU
    source.

.PARAMETER UsePhysicalZones
    Switch to normalize availability zone output to physical zones instead of logical zones.
    Useful for cross-subscription deployment planning where logical zones may differ.

.PARAMETER Threads
    Number of concurrent threads for processing subscriptions. Set to 0 for auto-detection.
    Higher values speed up execution but may hit API rate limits.

.PARAMETER OutputFile
    Name of the output CSV file containing the analysis results.

.EXAMPLE
    .\Get-AzVMQuotaUsageCli.ps1 -SKUs @('Standard_D2s_v5','Standard_E4s_v5') -Locations @('eastus','westus2')

    Analyzes specific VM SKUs in specific regions across all accessible subscriptions.

.EXAMPLE
    .\Get-AzVMQuotaUsageCli.ps1 -UsePhysicalZones -Threads 4 -OutputFile "MyQuotaAnalysis.csv"

    Runs full analysis with physical zone mapping using 4 threads.

.NOTES
    Requires Azure CLI (`az`) installed and an authenticated session (`az login`) with Reader
    access to target subscriptions. The Az PowerShell module is not required.
    Catalogs API access also requires the Microsoft.Capacity/catalogs/read permission.
    Output CSV contains columns: TenantId, SubscriptionId, SubscriptionName, Location, Family, Size,
    RegionRestricted, ZonesPresent, ZonesRestricted, CoresUsed, CoresTotal, CoresRequested, ZonesRequested
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "e.g. @('Standard_D2s_v3', 'Standard_D4s_v3')")]
    [string[]]$SKUs = @(),

    [Parameter(Mandatory = $false, HelpMessage = "e.g. @('eastus', 'westus')")]
    [string[]]$Locations = @(),

    [Parameter(Mandatory = $false, HelpMessage = "e.g. @('00000000-0000-0000-0000-000000000000')")]
    [string[]]$SubscriptionIds = @(),

    [Parameter(Mandatory = $false, HelpMessage = "Deprecated fallback URL to download normalized VM SKU list")]
    [string]$MeterDataUri = "https://ccmstorageprod.blob.core.windows.net/instancesizeflexibility-data/isfratioblob.csv",

    [Parameter(Mandatory = $false, HelpMessage = "Azure region to query for VM catalog data")]
    [string]$CatalogLocation = "eastus",

    [Parameter(Mandatory = $false, HelpMessage = "Normalize output to physical availability zones")]
    [switch]$UsePhysicalZones = $false,

    [Parameter(Mandatory = $false, HelpMessage = "Concurrent threads to use.  Set to '0' for auto-detect")]
    [ValidateRange(0, 40)]
    [int]$Threads = 2,

    [Parameter(Mandatory = $false, HelpMessage = "Output file name")]
    [string]$OutputFile = "QuotaQuery.csv"
)

# ================================================================================
# HELPER FUNCTIONS
# ================================================================================

<#
.SYNOPSIS
    Retrieves normalized VM SKU names from the Azure Catalogs API, with CSV as fallback.

.DESCRIPTION
    Queries the Azure Catalogs API for normalized VM SKU names and uses that as the
    primary source for quota analysis. If the Catalogs API call fails, falls back to
    AutofitComboMeterData.csv. Filters out SQL-related SKUs and returns unique SKU names.

.OUTPUTS
    Array of normalized VM SKU names (e.g., 'Standard_D2s_v3', 'Standard_E4s_v5')
#>
function Get-SKUDetails {
    try {
        Write-Host "Querying Azure Catalogs API for VM SKU details in $CatalogLocation"
        $catalogData = Get-VMCatalogData -SubscriptionId $SubscriptionIds[0] -Location $CatalogLocation
        [string[]]$skuNames = @(
            ($catalogData | Select-Object -Property ArmSkuName -Unique | Where-Object { $_.ArmSkuName -notlike "*sql*" }).ArmSkuName |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        if ($skuNames.Count -eq 0) {
            throw "Catalogs API returned zero VM SKUs"
        }

        Write-Host "Retrieved $($skuNames.Count) unique VM SKUs from Catalogs API"
        return $skuNames
    }
    catch {
        Write-Warning "Catalogs API failed: $($_.Exception.Message)"
        Write-Warning "Falling back to CSV download from $MeterDataUri"

        # Extract filename from URI for local storage
        [string]$meterDataFile = $MeterDataUri.Split('/')[-1]

        # Download the Cost Management connector data file
        Invoke-WebRequest -Uri $MeterDataUri -OutFile $meterDataFile

        # Parse CSV and extract unique, non-SQL VM SKUs
        $meterData = Get-Content $meterDataFile | ConvertFrom-Csv
        [string[]]$skuNames = @(
            ($meterData | Select-Object -Property ArmSkuName -Unique | Where-Object { $_.ArmSkuName -notlike "*sql*" }).ArmSkuName |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        return $skuNames
    }
}

<#
.SYNOPSIS
    Retrieves VM catalog data from the Azure Microsoft.Capacity catalogs API using Azure CLI.

.DESCRIPTION
    Calls the Azure catalogs endpoint for VirtualMachines in the specified subscription
    and location using `az rest`. Follows any nextLink values until all pages are
    retrieved and returns only entries that contain the required instance size
    flexibility properties.

.PARAMETER SubscriptionId
    The Azure subscription ID used to scope the catalogs API request.

.PARAMETER Location
    The Azure region name used in the catalogs API filter.

.OUTPUTS
    Array of PSCustomObject values with InstanceSizeFlexibilityGroup, ArmSkuName, and Ratio properties.
#>
function Get-VMCatalogData {
    param (
        [string]$SubscriptionId,
        [string]$Location
    )

    $catalogItems = [System.Collections.Generic.List[object]]::new()

    # Get the resource manager endpoint for the current cloud (supports sovereign clouds)
    $resourceManagerUrl = (az cloud show --query endpoints.resourceManager -o tsv).TrimEnd('/')

    $uri = "{0}/subscriptions/{1}/providers/Microsoft.Capacity/catalogs?api-version=2022-11-01&reservedResourceType=VirtualMachines&location={2}" -f $resourceManagerUrl, $SubscriptionId, $Location

    do {
        $response = az rest --method GET --url $uri -o json | ConvertFrom-Json

        foreach ($item in @($response.value)) {
            $groupProperty = @($item.skuProperties | Where-Object { $_.name -eq 'ReservationsAutofitGroup' } | Select-Object -First 1)
            $ratioProperty = @($item.skuProperties | Where-Object { $_.name -eq 'ReservationsAutofitRatio' } | Select-Object -First 1)

            if ([string]::IsNullOrWhiteSpace([string]$item.name) -or
                $groupProperty.Count -eq 0 -or
                $ratioProperty.Count -eq 0 -or
                [string]::IsNullOrWhiteSpace([string]$groupProperty[0].value) -or
                [string]::IsNullOrWhiteSpace([string]$ratioProperty[0].value)) {
                continue
            }

            $catalogItems.Add([PSCustomObject]@{
                    InstanceSizeFlexibilityGroup = $groupProperty[0].value
                    ArmSkuName                   = $item.name
                    Ratio                        = $ratioProperty[0].value
                })
        }

        $uri = $response.nextLink
    } while (-not [string]::IsNullOrWhiteSpace($uri))

    return $catalogItems.ToArray()
}

<#
.SYNOPSIS
    Retrieves all accessible subscription IDs within the current tenant using Azure CLI.

.DESCRIPTION
    Gets all Azure subscriptions that the current authenticated user has access to
    within the current tenant context. Uses `az account list` filtered by the current
    tenant ID obtained from `az account show`.

.OUTPUTS
    Array of subscription ID strings
#>
function Get-SubscriptionIds {
    Write-Host "Listing Subscriptions"

    # Get the current tenant ID from the active CLI session
    $tenantId = az account show --query tenantId -o tsv

    # List all subscriptions in this tenant and return their IDs
    $subscriptions = az account list --query "[?tenantId=='$tenantId'].id" -o json | ConvertFrom-Json
    return $subscriptions
}

<#
.SYNOPSIS
    Extracts the last character from a string.

.DESCRIPTION
    Utility function used to extract physical zone identifiers from availability zone mappings.
    Physical zones are typically identified by the last character of the physical zone string.

.PARAMETER inputString
    The input string to extract the last character from.

.OUTPUTS
    The last character of the input string, or empty string if input is null/empty.
#>
function Get-LastChar {
    param (
        [string]$inputString
    )

    if ([string]::IsNullOrEmpty($inputString)) {
        return ""
    }
    return $inputString[-1]
}

<#
.SYNOPSIS
    Retrieves all physical Azure regions using Azure CLI.

.DESCRIPTION
    Gets all Azure regions that are physical locations (not logical regions)
    and have a defined physical location. Uses `az account list-locations` with
    a JMESPath query to filter out logical regions and regions without physical presence.

.OUTPUTS
    Array of Azure region names (e.g., 'eastus', 'westus2', 'centralus')
#>
function Get-Locations {
    Write-Host "Listing Locations"

    # Query physical regions only — exclude logical regions and those without a physical location.
    # The Az module equivalent filters on RegionType == 'Physical' and PhysicalLocation != ''.
    # az account list-locations exposes this via metadata.regionType and metadata.physicalLocation.
    $locations = az account list-locations --query "[?metadata.regionType=='Physical' && metadata.physicalLocation!=''].name" -o json | ConvertFrom-Json
    return $locations
}

<#
.SYNOPSIS
    Retrieves availability zone peering information for a subscription using Azure CLI.

.DESCRIPTION
    Gets the logical-to-physical availability zone mappings for all regions
    within a specific subscription. This information is crucial for understanding
    how logical zones (1, 2, 3) map to physical zones across different subscriptions.

.PARAMETER SubscriptionId
    The Azure subscription ID to query for zone peering information.

.OUTPUTS
    Array of location objects containing availability zone mapping details.

.NOTES
    Uses the Azure REST API via `az rest` as this information is not available through
    standard Azure CLI commands. The resource manager endpoint is obtained from `az cloud show`.
#>
function Get-ZonePeers {
    param (
        [string]$SubscriptionId
    )
    Write-Host "Get Zone Peering Information for subscription $SubscriptionId"

    # Get the resource manager endpoint for the current cloud (supports sovereign clouds)
    # TrimEnd('/') ensures sovereign clouds (AzureUSGovernment, AzureChinaCloud) that omit
    # a trailing slash don't produce a malformed URI like "https://...netsubscriptions/..."
    $resourceManagerUrl = (az cloud show --query endpoints.resourceManager -o tsv).TrimEnd('/')

    # Construct REST API URI for location zone mappings
    $uri = "${resourceManagerUrl}/subscriptions/${SubscriptionId}/locations?api-version=2022-12-01"

    # Call Azure REST API to get zone peering data; pass --subscription to avoid context issues
    $response = az rest --method GET --url $uri --subscription $SubscriptionId -o json | ConvertFrom-Json
    return $response.value
}

<#
.SYNOPSIS
    Analyzes VM quota usage and restrictions for a specific subscription using Azure CLI.

.DESCRIPTION
    Core function that performs detailed quota analysis for a single subscription.
    Queries compute resource SKUs, VM usage statistics, and availability zone
    restrictions across specified locations and SKUs using `az` CLI commands.

    Unlike the Az module variant, this function passes --subscription to each
    az command rather than calling az account set, which avoids race conditions
    when running in parallel across multiple subscriptions.

    UsePhysicalZones is accepted as a parameter (not inherited from script scope)
    so that parallel runspaces can correctly receive the switch value via $using:.

.PARAMETER SubscriptionId
    The Azure subscription ID to analyze.

.PARAMETER Locations
    Array of Azure regions to analyze within this subscription.

.PARAMETER SKUs
    Array of VM SKU names to analyze.

.PARAMETER OutputFile
    Name of the CSV file to append results to.

.OUTPUTS
    Appends CSV rows to the output file with quota and restriction details.

.NOTES
    This function is designed to run in parallel across multiple subscriptions
    for optimal performance. Each execution handles one subscription completely.
    Pass --subscription to every az command; do not use az account set inside
    parallel runspaces as it is process-global and causes race conditions.
#>
function Get-QuotaDetails {
    param (
        [string]$SubscriptionId,
        [string[]]$Locations,
        [string[]]$SKUs,
        [string]$OutputFile,
        [bool]$UsePhysicalZones = $false
    )

    $start = Get-Date
    try {
        # Get subscription details and validate access using Azure CLI.
        # Pass --subscription so we never change the global az context.
        $subscriptionJson = az account show --subscription $SubscriptionId -o json 2>$null | ConvertFrom-Json
        if ($null -eq $subscriptionJson) {
            throw "Subscription not found"
        }

        # Build a subscription object with the same field names used throughout the function
        $Subscription = [PSCustomObject]@{
            Id     = $subscriptionJson.id
            Name   = $subscriptionJson.name
            TenantId = $subscriptionJson.tenantId
        }

        # Get zone peering information if physical zone mapping is requested
        if ($UsePhysicalZones) {
            $zonePeers = Get-ZonePeers -SubscriptionId $SubscriptionId
            if ($zonePeers.Count -eq 0) {
                Write-Host "No Zone Peering Information found for subscription $SubscriptionId" -ForegroundColor Yellow
            }
        }

        # Process each location within the subscription
        foreach ($Location in $Locations) {
            "Querying: $SubscriptionId - $($Subscription.Name) - $Location"

            # Get all VM SKUs available in this location using Azure CLI.
            # az vm list-skus returns objects where resourceType is lowercase.
            $computeSKUs = az vm list-skus --location $Location --resource-type virtualMachines --subscription $SubscriptionId -o json 2>$null | ConvertFrom-Json

            # Get current VM quota usage for this location using Azure CLI.
            # Returns objects with currentValue, limit, and name.value / name.localizedValue.
            $vmUsage = az vm list-usage --location $Location --subscription $SubscriptionId -o json 2>$null | ConvertFrom-Json

            # Get availability zone mappings for this location (if using physical zones)
            $availabilityZoneMappings = ($zonePeers | Where-Object { $_.name -like $Location -and $_.type -eq "Region" }).availabilityZoneMappings

            # Process each requested SKU
            foreach ($SKU in $SKUs) {
                # Find the specific SKU data for this location.
                # az vm list-skus locationInfo is an array; check locationInfo[0].location.
                $filteredSku = $computeSKUs | Where-Object {
                    $_.name.ToLowerInvariant() -eq $SKU.ToLowerInvariant() -and
                    $_.locationInfo.Count -gt 0 -and
                    $_.locationInfo[0].location -like $Location
                }

                # Skip if SKU not found in this location
                if ($null -eq $filteredSku) {
                    continue
                }

                # Find the quota usage data for this SKU's family.
                # In az vm list-usage output: name.value holds the family identifier (e.g. standardDSv5Family)
                # and name.localizedValue holds the human-readable label.
                $skuUsage = $vmUsage | Where-Object { $_.name.value -eq $filteredSku.family }

                # Skip if quota usage data not found
                if ($null -eq $skuUsage) {
                    continue
                }

                # Process availability zones (logical or physical).
                # az vm list-skus stores zones in locationInfo[0].zones.
                # Guard against empty locationInfo to avoid index-out-of-bounds on SKUs
                # that have no location info entries (returns empty array instead of throwing).
                $zones = if ($filteredSku.locationInfo.Count -gt 0) { @($filteredSku.locationInfo[0].zones) } else { @() }
                if ($UsePhysicalZones) {
                    # Convert logical zones to physical zones
                    for ($i = 0; $i -lt $zones.Length; $i++) {
                        $zones[$i] = Get-LastChar(($availabilityZoneMappings | Where-Object { $_.LogicalZone -like $zones[$i] }).physicalZone)
                    }
                }

                # Create the quota analysis object
                $auditedSku = [PSCustomObject]@{
                    TenantId         = $Subscription.TenantId
                    SubscriptionId   = $Subscription.Id
                    SubscriptionName = $Subscription.Name
                    Location         = $Location
                    Family           = $skuUsage.name.localizedValue  # VM family name (e.g., "Dv3 Family vCPUs")
                    Size             = $filteredSku.name               # Specific SKU (e.g., "Standard_D2s_v3")
                    RegionRestricted = 'False'                         # Whether SKU is restricted in this entire region
                    ZonesPresent     = ($zones | Sort-Object) -join "," # Available zones for this SKU
                    ZonesRestricted  = ''                              # Zones where SKU is restricted
                    CoresUsed        = $skuUsage.currentValue          # Current quota usage
                    CoresTotal       = $skuUsage.limit                 # Total quota limit
                    CoresRequested   = ''                              # Placeholder for future use
                    ZonesRequested   = ''                              # Placeholder for future use
                }

                # Process any restrictions on this SKU.
                # az vm list-skus restrictions[].type is lowercase (e.g. "Zone", "Location").
                foreach ($restriction in $filteredSku.restrictions) {
                    if ($restriction.type -like "Zone") {
                        # Handle zone-specific restrictions.
                        # az vm list-skus stores restricted zones in restrictionInfo.zones.
                        $zoneRestrictions = @($restriction.restrictionInfo.zones)
                        if ($UsePhysicalZones) {
                            # Convert restricted logical zones to physical zones
                            for ($i = 0; $i -lt $zoneRestrictions.Length; $i++) {
                                $zoneRestrictions[$i] = Get-LastChar(($availabilityZoneMappings | Where-Object { $_.LogicalZone -like $zoneRestrictions[$i] }).physicalZone)
                            }
                        }
                        $auditedSku.ZonesRestricted = ($zoneRestrictions | Sort-Object) -join ","
                    }
                    elseif ($restriction.type -like "Location") {
                        # Handle region-wide restrictions
                        $auditedSku.RegionRestricted = 'True'
                    }
                }

                # Append the result to the CSV file
                $auditedSku | ConvertTo-Csv -NoHeader | Out-File -Force -Append -FilePath .\$OutputFile
            }
        }
    }
    catch {
        Write-Host "Failed Querying Subscription ID: $SubscriptionId" -ForegroundColor Yellow
        $_.Exception.Message
    }
    finally {
        # Report processing time for this subscription
        $end = Get-Date
        "Processed: $SubscriptionId - $($Subscription.Name) in $([math]::Round((New-TimeSpan -Start $start -End $end).TotalSeconds, 2)) seconds"
    }
}

# ================================================================================
# MAIN SCRIPT EXECUTION
# ================================================================================

# Set error handling and output preferences
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'
$begin = Get-Date

# Define CSV header structure for output file
$csvHeaderString = "TenantId,SubscriptionId,SubscriptionName,Location,Family,Size,RegionRestricted,ZonesPresent,ZonesRestricted,CoresUsed,CoresTotal,CoresRequested,ZonesRequested"

# Auto-detect optimal thread count if not specified.
# Uses [Environment]::ProcessorCount (cross-platform) instead of WMI (Windows-only).
if ($Threads -eq 0) {
    try {
        $Threads = [Math]::Max(1, [Environment]::ProcessorCount / 2)
    }
    catch {
        # Fallback to single-threaded if CPU detection fails
        $Threads = 1
    }
}

# Populate subscription list if not provided
if ($SubscriptionIds.Count -eq 0) {
    $SubscriptionIds = Get-SubscriptionIds
}

# Populate locations list if not provided, otherwise sort provided list
if ($Locations.Count -eq 0) {
    $Locations = Get-Locations | Sort-Object
} else {
    $Locations = $Locations | Sort-Object
}

# Populate SKUs list if not provided
if ($SKUs.Count -eq 0) {
    $SKUs = Get-SKUDetails
}

# Display configuration information
if ($UsePhysicalZones) {
    Write-Host "Output will be normalized to physical availability zones"
}
else {
    Write-Host "Output will not be normalized to physical availability zones"
}

Write-Host "Querying $($SubscriptionIds.Count) subscriptions with $($SKUs.Count) SKUs in $($Locations.Count) locations using $Threads threads"

# Execute quota analysis using parallel processing.
# Function definition is serialized as a string and re-imported in each runspace,
# because parallel runspaces do not inherit the calling scope's function definitions.
# IMPORTANT: az account set is NOT used inside the parallel block. Every az command
# receives --subscription explicitly to avoid process-global context race conditions.
$funcDef = ${function:Get-QuotaDetails}.ToString()
$lastCharFuncDef = ${function:Get-LastChar}.ToString()
$getZonePeersFuncDef = ${function:Get-ZonePeers}.ToString()

$SubscriptionIds | Foreach-Object -ThrottleLimit $Threads -Parallel {
    # Import all required function definitions into the parallel runspace
    ${function:Get-QuotaDetails} = $using:funcDef
    ${function:Get-LastChar} = $using:lastCharFuncDef
    ${function:Get-ZonePeers} = $using:getZonePeersFuncDef

    # Use separate output files for multi-threaded execution to avoid write conflicts
    if ($USING:Threads -gt 1) {
        $outFile = "QuotaQuery_{0}.csv" -f $PSItem
    } else {
        $outFile = $USING:OutputFile
    }

    # Write CSV header to output file
    $USING:csvHeaderString | Out-File -Force $outFile

    # Execute quota analysis for this subscription
    Get-QuotaDetails -SubscriptionId $_ -Locations $USING:Locations -SKUs $USING:SKUs -OutputFile $outFile -UsePhysicalZones ([bool]$USING:UsePhysicalZones)
}

# Merge multiple CSV files if multi-threaded execution was used
if ($Threads -gt 1) {
    Write-Host "Merging CSV files"

    # Create consolidated output file with header
    $csvHeaderString | Out-File -Force -FilePath $OutputFile

    # Append content from all thread-specific files (skipping headers)
    Get-ChildItem -Path .\QuotaQuery_*.csv | ForEach-Object {
        Get-Content $_.FullName | Select-Object -Skip 1 | Add-Content $OutputFile
        Remove-Item $_.FullName  # Clean up temporary files
    }
}

# Display completion summary
Write-Host "Output written to $OutputFile"
$end = Get-Date
Write-Host "Processed $($SubscriptionIds.Count) subscriptions in $([math]::Round((New-TimeSpan -Start $begin -End $end).TotalSeconds, 2)) seconds"
