
<#
.SYNOPSIS
    Single-threaded Azure VM quota analysis script that queries compute resource SKU availability,
    quota usage, and availability zone restrictions across subscriptions.

.DESCRIPTION
    This script provides simplified quota analysis functionality for Azure VM resources.
    It's designed as a streamlined version for smaller-scale analysis or educational purposes.
    The script analyzes:
    - Current quota usage vs. limits for VM families
    - Available and restricted availability zones per SKU
    - Region-level restrictions for specific VM SKUs
    - Physical vs. logical availability zone mappings (optional)

    Unlike the multi-threaded Get-AzVMQuotaUsage.ps1, this version processes subscriptions
    sequentially and displays results in a formatted table at the end.

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

.PARAMETER OutputFile
    Name of the output CSV file containing the analysis results.
    Default: "QuotaQuery.csv"

.PARAMETER UsePhysicalZones
    Switch to normalize availability zone output to physical zones instead of logical zones.
    Useful for cross-subscription deployment planning where logical zones may differ.

.EXAMPLE
    .\Show-AzVMQuotaReport.ps1 -SKUs @('Standard_D2s_v5','Standard_E4s_v5') -Locations @('eastus','westus2')
    
    Analyzes specific VM SKUs in specific regions and displays results in table format.

.EXAMPLE
    .\Show-AzVMQuotaReport.ps1 -UsePhysicalZones -OutputFile "MyQuotaAnalysis.csv"
    
    Runs full analysis with physical zone mapping and custom output filename.

.NOTES
    Requires Azure PowerShell module and authenticated session with Reader access to target subscriptions.
    This is a simplified, educational version of the quota analysis functionality.
    For production use with large numbers of subscriptions, consider using Get-AzVMQuotaUsage.ps1 instead.
    
    Output CSV contains columns: TenantId, SubscriptionId, SubscriptionName, Location, Family, Size,
    RegionRestricted, ZonesPresent, ZonesRestricted, CoresUsed, CoresTotal
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
    
    [Parameter(Mandatory = $false, HelpMessage = "Output CSV filename")]
    [string]$OutputFile = "QuotaQuery.csv",

    [Parameter(Mandatory = $false, HelpMessage = "Normalize output to physical availability zones")]
    [switch]$UsePhysicalZones = $false
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
    
    # Extract filename from URI for local storage (more robust approach)
    [string]$meterDataFile = $MeterDataUri.Split('/')[$MeterDataUri.Split('/').Length - 1]
    
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
    within the current tenant context. Used when no specific subscription IDs are provided.

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
    Utility function used to extract the physical zone identifier from the full physical zone name.
    Physical zones are typically identified by the last character (e.g., 'A', 'B', 'C') of the 
    full physical zone string (e.g., "eastus-az1" -> "1", "westus2-azA" -> "A").

.PARAMETER inputString
    The input string to extract the last character from.

.OUTPUTS
    The last character of the input string, or empty string if input is null/empty.
#>
function Get-LastChar {
    param (
        [string]$inputString
    )
    
    # Handle null or empty input
    if ([string]::IsNullOrEmpty($inputString)) {
        return ""
    }
    
    # Additional length check for safety (though redundant with IsNullOrEmpty)
    if ($inputString.Length -lt 1) {
        return ""
    }
    
    # Return the last character
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
    Retrieves availability zone peering information for a specific subscription.

.DESCRIPTION
    Queries the Azure REST API to get detailed availability zone mapping information
    for all regions within a subscription. This information shows how logical zones
    (1, 2, 3) map to physical zones for each region.

.PARAMETER SubscriptionId
    The Azure subscription ID to query for zone peering information.

.OUTPUTS
    Array of location objects containing availability zone mapping details for all regions.

.NOTES
    Uses the Azure REST API directly as this detailed zone mapping information is not 
    available through standard PowerShell cmdlets.
#>
function Get-ZonePeers {
    param (
        [string]$SubscriptionId
    )
    Write-Host "Get Zone Peering Information for subscription $SubscriptionId"
    
    # Construct REST API URI for location zone mappings using subscription-specific endpoint
    $uri = "{0}subscriptions/{1}/locations?api-version=2022-12-01" -f $resourceManagerUrl, $SubscriptionId
    
    # Call Azure REST API to get comprehensive location and zone mapping data
    $response = Invoke-AzRest -Method GET -Uri $uri
    return ($response.Content | ConvertFrom-Json).value
}

<#
.SYNOPSIS
    Analyzes VM quota usage and restrictions for a specific subscription.

.DESCRIPTION
    Core function that performs detailed quota analysis for a single subscription.
    This simplified version processes subscriptions sequentially and provides
    detailed console output showing progress through regions and SKUs.

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
    Provides console output showing analysis progress.

.NOTES
    This function includes Microsoft.Capacity resource provider registration
    to ensure quota APIs are available. Also provides visual progress feedback
    with dots for each SKU processed.
#>
function Get-QuotaDetails {
    param (
        [string]$SubscriptionId,
        [string[]]$Locations,
        [string[]]$SKUs,
        [string]$OutputFile
    )

    try {
        # Get subscription details and validate access
        $Subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -WarningAction SilentlyContinue
        if ($null -eq $Subscription) {
            throw "Subscription not found"
        }

        # Set context to target subscription for all subsequent queries
        Set-AzContext -SubscriptionId $Subscription.Id -WarningAction SilentlyContinue | Out-Null
        
        # Ensure Microsoft.Capacity resource provider is registered for quota APIs
        if ((Get-AzResourceProvider -ListAvailable | Where-Object { $_.ProviderNamespace -like 'Microsoft.Capacity' }).RegistrationState -notlike 'Registered') {
            try {
                Register-AzResourceProvider -ProviderNamespace Microsoft.Capacity
            }
            catch {
                Write-Host "Failed Registering Resource Provider: Microsoft.Capacity" -ForegroundColor Yellow
            }
        }

        # Get zone peering information if physical zone mapping is requested
        if($UsePhysicalZones)
        {
            $zonePeers = Get-ZonePeers -SubscriptionId $SubscriptionId
            if ($zonePeers.Count -eq 0) {
                Write-Host "No Zone Peering Information found for subscription $SubscriptionId" -ForegroundColor Yellow
            }
        }
    
        # Process each location within the subscription
        Write-Host "Querying Subscription: $($Subscription.Name)"
        foreach ($Location in $Locations) {
            Write-Host "    Querying Region: $Location"
            
            # Get all VM SKUs available in this location
            $computeSKUs = Get-AzComputeResourceSku -Location $Location -ErrorAction SilentlyContinue | Where-Object { $_.ResourceType -eq 'virtualMachines' }
            
            # Get current VM quota usage for this location
            $vmUsage = Get-AZVMUsage -Location $Location -ErrorAction SilentlyContinue
            
            # Get availability zone mappings for this location (if using physical zones)
            $availabilityZoneMappings = ($zonePeers | Where-Object { $_.name -like $Location -and $_.type -eq "Region"}).availabilityZoneMappings
            
            # Process each requested SKU with visual progress indicator
            foreach ($SKU in $SKUs) {
                Write-Host -NoNewline "."  # Progress indicator for each SKU processed
                
                # Find the specific SKU data for this location
                $filteredSku = $computeSKUs | Where-Object { $_.Name.ToLowerInvariant() -eq $SKU.ToLowerInvariant() -and $_.LocationInfo.Location -like $Location }
                
                # Find the quota usage data for this SKU's family
                $skuUsage = $vmUsage | Select-Object -ExpandProperty Name -Property CurrentValue, Limit | Where-Object { $_.Value -eq $filteredSku.Family }
                
                # Skip if SKU not found in this location
                if ($null -eq $filteredSku) {
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
            Write-Host ""  # New line after completing all SKUs in this region
        }
    }
    catch {
        Write-Host "Failed Querying Subscription ID: $SubscriptionId" -ForegroundColor Yellow
        $_.Exception.Message
    }
}

# ================================================================================
# MAIN SCRIPT EXECUTION
# ================================================================================

# Set error handling and output preferences
$ErrorActionPreference = 'Stop'           # Stop execution on any error
$VerbosePreference = 'SilentlyContinue'   # Suppress verbose output for cleaner execution

# Define CSV header structure for output file
$csvHeaderString = "TenantId,SubscriptionId,SubscriptionName,Location,Family,Size,RegionRestricted,ZonesPresent,ZonesRestricted,CoresUsed,CoresTotal"

# Initialize output file with CSV headers
$csvHeaderString | Out-File -Force -FilePath $OutputFile

# Get the Azure Resource Manager URL for the current Azure environment
# This is needed for constructing REST API calls and may vary by cloud (Public, Government, etc.)
$resourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl

# Populate SKUs list if not provided by user
if ($SKUs.Count -eq 0) {
    $SKUs = Get-SKUDetails
}

# Populate subscription list if not provided by user
if ($SubscriptionIds.Count -eq 0) {
    $SubscriptionIds = Get-SubscriptionIds
}

# Populate locations list if not provided by user
if ($Locations.Count -eq 0) {
    $Locations = Get-Locations
}

# Display configuration information
if($UsePhysicalZones)
{
    Write-Host "Output will be normalized to physical availability zones"
}
else {
    Write-Host "Output will not be normalized to physical availability zones"
}

# Execute quota analysis sequentially for each subscription
# This simplified version processes one subscription at a time for educational clarity
foreach ($SubscriptionId in $SubscriptionIds) {
    Get-QuotaDetails -SubscriptionId $SubscriptionId -Locations $Locations -SKUs $SKUs -outputFile $OutputFile
}

# Display results in formatted table for immediate review
Write-Host ""
Write-Host "Analysis complete. Displaying results:"
Get-Content $OutputFile | ConvertFrom-Csv | Format-Table -AutoSize