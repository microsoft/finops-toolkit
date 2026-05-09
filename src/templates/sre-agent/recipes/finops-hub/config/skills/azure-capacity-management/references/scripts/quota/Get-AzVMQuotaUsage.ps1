
<#
.SYNOPSIS
    Multi-threaded Azure VM quota analysis script that queries compute resource SKU availability, 
    quota usage, and availability zone restrictions across subscriptions.

.DESCRIPTION
    This script analyzes Azure VM quota usage and availability zone restrictions across multiple 
    subscriptions and regions. It provides detailed information about:
    - Current quota usage vs. limits for VM families
    - Available and restricted availability zones per SKU
    - Region-level restrictions for specific VM SKUs
    - Physical vs. logical availability zone mappings

    The script supports multi-threading for faster execution across large numbers of subscriptions
    and can normalize zone information to physical zones for cross-subscription deployment planning.

.PARAMETER SKUs
    Array of VM SKU names to analyze. If not specified, downloads and uses all available SKUs.
    Example: @('Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_E4s_v5')

.PARAMETER Locations
    Array of Azure regions to analyze. If not specified, queries all physical Azure regions.
    Example: @('eastus', 'westus2', 'centralus')

.PARAMETER SubscriptionIds
    Array of subscription IDs to analyze. If not specified, queries all accessible subscriptions.
    Example: @('00000000-0000-0000-0000-000000000000')

.PARAMETER MeterDataUri
    URL to download normalized VM SKU list from Cost Management connector data.
    Used when SKUs parameter is not provided.

.PARAMETER UsePhysicalZones
    Switch to normalize availability zone output to physical zones instead of logical zones.
    Useful for cross-subscription deployment planning where logical zones may differ.

.PARAMETER Threads
    Number of concurrent threads for processing subscriptions. Set to 0 for auto-detection.
    Higher values speed up execution but may hit API rate limits.

.PARAMETER OutputFile
    Name of the output CSV file containing the analysis results.

.EXAMPLE
    .\Get-AzVMQuotaUsage.ps1 -SKUs @('Standard_D2s_v5','Standard_E4s_v5') -Locations @('eastus','westus2')
    
    Analyzes specific VM SKUs in specific regions across all accessible subscriptions.

.EXAMPLE
    .\Get-AzVMQuotaUsage.ps1 -UsePhysicalZones -Threads 4 -OutputFile "MyQuotaAnalysis.csv"
    
    Runs full analysis with physical zone mapping using 4 threads.

.NOTES
    Requires Azure PowerShell module and authenticated session with Reader access to target subscriptions.
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

    [Parameter(Mandatory = $false, HelpMessage = "Location to download normalized list of VM SKUs")]
    [string]$MeterDataUri = "https://ccmstorageprod.blob.core.windows.net/costmanagementconnector-data/AutofitComboMeterData.csv",

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
    Downloads and parses the normalized VM SKU list from Cost Management data.

.DESCRIPTION
    Retrieves the AutofitComboMeterData.csv file containing normalized VM SKU names.
    Filters out SQL-related SKUs and returns unique SKU names for quota analysis.

.OUTPUTS
    Array of normalized VM SKU names (e.g., 'Standard_D2s_v3', 'Standard_E4s_v5')
#>
function Get-SKUDetails {
    Write-Host "Downloading VM SKU Details"
    
    # Extract filename from URI for local storage
    [string]$meterDataFile = $MeterDataUri.Split('/')[-1]
    
    # Download the Cost Management connector data file
    Invoke-WebRequest -Uri $MeterDataUri -OutFile $meterDataFile
    
    # Parse CSV and extract unique, non-SQL VM SKUs
    $meterData = Get-Content $meterDataFile | ConvertFrom-Csv
    return ($meterData | Select-Object -Property NormalizedSKU -Unique | Where-Object { $_.NormalizedSKU -notlike "*sql*" }).NormalizedSKU
}

<#
.SYNOPSIS
    Retrieves all accessible subscription IDs within the current tenant.

.DESCRIPTION
    Gets all Azure subscriptions that the current authenticated user has access to
    within the current tenant context.

.OUTPUTS
    Array of subscription ID strings
#>
function Get-SubscriptionIds {
    Write-Host "Listing Subscriptions"
    return (Get-AzSubscription -TenantId ((Get-AzContext).Tenant.TenantId) | Select-Object -ExpandProperty SubscriptionId)
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
    Retrieves all physical Azure regions.

.DESCRIPTION
    Gets all Azure regions that are physical locations (not logical regions)
    and have a defined physical location. Filters out logical regions and
    regions without physical presence.

.OUTPUTS
    Array of Azure region names (e.g., 'eastus', 'westus2', 'centralus')
#>
function Get-Locations {
    Write-Host "Listing Locations"
    return (Get-AzLocation | Where-Object { $_.RegionType -eq 'Physical' -and $_.PhysicalLocation -ne "" -and $_.Location } | Select-Object -Property Location -Unique).Location
}

<#
.SYNOPSIS
    Retrieves availability zone peering information for a subscription.

.DESCRIPTION
    Gets the logical-to-physical availability zone mappings for all regions
    within a specific subscription. This information is crucial for understanding
    how logical zones (1, 2, 3) map to physical zones across different subscriptions.

.PARAMETER SubscriptionId
    The Azure subscription ID to query for zone peering information.

.OUTPUTS
    Array of location objects containing availability zone mapping details.

.NOTES
    Uses the Azure REST API directly as this information is not available through
    standard PowerShell cmdlets.
#>
function Get-ZonePeers {
    param (
        [string]$SubscriptionId
    )
    Write-Host "Get Zone Peering Information for subscription $SubscriptionId"
    
    # Construct REST API URI for location zone mappings
    $uri = "{0}subscriptions/{1}/locations?api-version=2022-12-01" -f (Get-AzContext).Environment.ResourceManagerUrl, $SubscriptionId
    
    # Call Azure REST API to get zone peering data
    $response = Invoke-AzRest -Method GET -Uri $uri
    return ($response.Content | ConvertFrom-Json).value
}

<#
.SYNOPSIS
    Analyzes VM quota usage and restrictions for a specific subscription.

.DESCRIPTION
    Core function that performs detailed quota analysis for a single subscription.
    Queries compute resource SKUs, VM usage statistics, and availability zone
    restrictions across specified locations and SKUs.

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
#>
function Get-QuotaDetails {
    param (
        [string]$SubscriptionId,
        [string[]]$Locations,
        [string[]]$SKUs,
        [string]$OutputFile
    )

    $start = Get-Date
    try {
        # Get subscription details and validate access
        $Subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -WarningAction SilentlyContinue
        if ($null -eq $Subscription) {
            throw "Subscription not found"
        }

        # Set context to target subscription for all subsequent queries
        Set-AzContext -SubscriptionId $Subscription.Id -WarningAction SilentlyContinue | Out-Null

        # Get zone peering information if physical zone mapping is requested
        if($UsePhysicalZones)
        {
            $zonePeers = Get-ZonePeers -SubscriptionId $SubscriptionId
            if ($zonePeers.Count -eq 0) {
                Write-Host "No Zone Peering Information found for subscription $SubscriptionId" -ForegroundColor Yellow
            }
        }

        # Process each location within the subscription
        foreach ($Location in $Locations) {
            "Querying: $SubscriptionId - $($Subscription.Name) - $Location"
            
            # Get all VM SKUs available in this location
            $computeSKUs = Get-AzComputeResourceSku -Location $Location -ErrorAction SilentlyContinue | Where-Object { $_.ResourceType -eq 'virtualMachines' }
            
            # Get current VM quota usage for this location
            $vmUsage = Get-AZVMUsage -Location $Location -ErrorAction SilentlyContinue
            
            # Get availability zone mappings for this location (if using physical zones)
            $availabilityZoneMappings = ($zonePeers | Where-Object { $_.name -like $Location -and $_.type -eq "Region"}).availabilityZoneMappings
            
            # Process each requested SKU
            foreach ($SKU in $SKUs) {
                # Find the specific SKU data for this location
                $filteredSku = $computeSKUs | Where-Object { $_.Name.ToLowerInvariant() -eq $SKU.ToLowerInvariant() -and $_.LocationInfo.Location -like $Location }
                
                # Find the quota usage data for this SKU's family
                $skuUsage = $vmUsage | Select-Object -ExpandProperty Name -Property CurrentValue, Limit | Where-Object { $_.Value -eq $filteredSku.Family }
                
                # Skip if SKU not found in this location
                if ($null -eq $filteredSku ) {
                    continue
                }

                # Skip if quota usage data not found
                if ($null -eq $skuUsage) {
                    continue
                }

                # Process availability zones (logical or physical)
                $zones = @($filteredSku.LocationInfo.Zones)
                if($UsePhysicalZones)
                {
                    # Convert logical zones to physical zones
                    for ($i = 0; $i -lt $zones.Length; $i++) {
                        $zones[$i] = Get-LastChar(($availabilityZoneMappings | Where-Object {$_.LogicalZone -like $zones[$i]}).physicalZone)
                    }
                }
                
                # Create the quota analysis object
                $auditedSku = [PSCustomObject]@{
                    TenantId         = $Subscription.TenantId
                    SubscriptionId   = $Subscription.Id
                    SubscriptionName = $Subscription.Name
                    Location         = $Location
                    Family           = $skuUsage.LocalizedValue          # VM family name (e.g., "Dv3 Family vCPUs")
                    Size             = $filteredSku.Name                 # Specific SKU (e.g., "Standard_D2s_v3")
                    RegionRestricted = 'False'                          # Whether SKU is restricted in this entire region
                    ZonesPresent     = ($zones | Sort-Object) -join ","  # Available zones for this SKU
                    ZonesRestricted  = ''                               # Zones where SKU is restricted
                    CoresUsed        = $skuUsage.CurrentValue           # Current quota usage
                    CoresTotal       = $skuUsage.Limit                  # Total quota limit
                    CoresRequested   = ''                               # Placeholder for future use
                    ZonesRequested  = ''                                # Placeholder for future use
                }

                # Process any restrictions on this SKU
                foreach ($restriction in $filteredSku.Restrictions) {
                    if ($restriction.Type -like "Zone") {
                        # Handle zone-specific restrictions
                        $zoneRestrictions = @($restriction.RestrictionInfo.Zones)
                        if($UsePhysicalZones)
                        {
                            # Convert restricted logical zones to physical zones
                            for ($i = 0; $i -lt $zoneRestrictions.Length; $i++) {
                                $zoneRestrictions[$i] = Get-LastChar(($availabilityZoneMappings | Where-Object {$_.LogicalZone -like $zoneRestrictions[$i]}).physicalZone)
                            }
                        }
                        $auditedSku.ZonesRestricted = ($zoneRestrictions | Sort-Object) -join ","
                    }
                    elseif ($restriction.Type -like "Location") {
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

# Auto-detect optimal thread count if not specified
if($Threads -eq 0)
{
    try {
        # Use WMI to detect CPU configuration
        $spec = Get-WmiObject -Class Win32_Processor | Select-Object -Property NumberOfCores, NumberOfLogicalProcessors
        if($spec.NumberOfLogicalProcessors -gt $spec.NumberOfCores) {
            # Hyper-threading enabled: Use physical cores to avoid e-core performance issues
            $Threads = $spec.NumberOfLogicalProcessors - $spec.NumberOfCores
        }
        else {
            # Hyper-threading disabled: Use all available cores
            $Threads = $spec.NumberOfCores
        }
    }
    catch {
        # Fallback to single-threaded if CPU detection fails
        $Threads = 1
    }
}

# Populate SKUs list if not provided
if ($SKUs.Count -eq 0) {
    $SKUs = Get-SKUDetails
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

# Display configuration information
if($UsePhysicalZones)
{
    Write-Host "Output will be normalized to physical availability zones"
}
else {
    Write-Host "Output will not be normalized to physical availability zones"
}

Write-Host "Querying $($SubscriptionIds.Count) subscriptions with $($SKUs.Count) SKUs in $($Locations.Count) locations using $Threads threads"

# Execute quota analysis using parallel processing
$funcDef = ${function:Get-QuotaDetails}.ToString()
$SubscriptionIds | Foreach-Object -ThrottleLimit $Threads -Parallel {
    # Import function definition into parallel runspace
    ${function:Get-QuotaDetails} = $using:funcDef
    
    # Use separate output files for multi-threaded execution to avoid conflicts
    if($USING:Threads -gt 1) { 
        $outFile = "QuotaQuery_{0}.csv" -f $PSItem 
    } else { 
        $outFile = $USING:OutputFile 
    }
    
    # Write CSV header to output file
    $USING:csvHeaderString | Out-File -Force $outFile
    
    # Execute quota analysis for this subscription
    Get-QuotaDetails -SubscriptionId $_ -Locations $USING:Locations -SKUs $USING:SKUs -outputFile $outFile
}

# Merge multiple CSV files if multi-threaded execution was used
if($Threads -gt 1) {
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