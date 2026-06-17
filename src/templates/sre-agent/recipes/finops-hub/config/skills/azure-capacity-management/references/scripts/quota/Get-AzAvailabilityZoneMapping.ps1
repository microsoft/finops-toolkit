
<#
.SYNOPSIS
    Maps logical availability zones to physical zones across Azure subscriptions.

.DESCRIPTION
    This script analyzes the relationship between logical and physical availability zones
    across multiple Azure subscriptions. Logical zones (1, 2, 3) may map to different
    physical zones in different subscriptions, which is critical for understanding when
    planning multi-subscription deployments that require specific zone alignment.

    The script outputs a detailed CSV mapping that shows:
    - How logical zones map to physical zones per subscription
    - The actual physical zone identifiers and names
    - Location information for zone planning

    This data is essential for:
    - Cross-subscription deployment planning
    - Understanding zone distribution across subscriptions
    - Ensuring proper zone alignment for multi-subscription architectures
    - Compliance with data residency requirements

.PARAMETER SubscriptionIds
    Array of Azure subscription IDs to analyze for zone mappings.
    If not specified, analyzes all accessible subscriptions in the current tenant.
    Example: @('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111')

.PARAMETER OutputFile
    Name of the output CSV file containing the zone mapping analysis.
    Default: "ZonePeers.csv"

.EXAMPLE
    .\Get-AzAvailabilityZoneMapping.ps1
    
    Analyzes zone mappings for all accessible subscriptions and outputs to ZonePeers.csv.

.EXAMPLE
    .\Get-AzAvailabilityZoneMapping.ps1 -SubscriptionIds @('sub1-id','sub2-id') -OutputFile "CrossSubZones.csv"
    
    Analyzes specific subscriptions and outputs to a custom filename.

.NOTES
    Requires Azure PowerShell module and authenticated session with Reader access to target subscriptions.
    Output CSV contains columns: TenantId, SubscriptionId, SubscriptionName, Location, 
    LogicalZone, PhysicalZone, PhysicalZoneName

    Zone Mapping Concepts:
    - Logical Zone: The zone number (1, 2, 3) that applications see
    - Physical Zone: The actual physical datacenter identifier (often a single character)
    - Physical Zone Name: The full physical zone name (e.g., "eastus-az1", "eastus-az2")
    
    Different subscriptions may have different logical-to-physical zone mappings for the same region.
    This is by design to ensure even distribution of resources across physical infrastructure.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "e.g. @('00000000-0000-0000-0000-000000000000')")]
    [string[]]$SubscriptionIds = @(),
    
    [Parameter(Mandatory = $false, HelpMessage = "Output CSV filename")]
    [string]$OutputFile = "ZonePeers.csv"
)
# ================================================================================
# HELPER FUNCTIONS
# ================================================================================

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

.EXAMPLE
    Get-LastChar("eastus-az1")
    Returns: "1"
    
.EXAMPLE
    Get-LastChar("westus2-azA") 
    Returns: "A"
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
    available through standard PowerShell cmdlets. The API returns comprehensive
    location data including availabilityZoneMappings for regions that support zones.
    
    The returned data structure includes:
    - Location information (name, type, etc.)
    - availabilityZoneMappings array with logicalZone -> physicalZone mappings
#>
function Get-ZonePeers {
    param (
        [string]$SubscriptionId
    )
    
    # Construct REST API URI for location zone mappings using subscription-specific endpoint
    $uri = "{0}subscriptions/{1}/locations?api-version=2022-12-01" -f $resourceManagerUrl, $SubscriptionId
    
    # Call Azure REST API to get comprehensive location and zone mapping data
    $response = Invoke-AzRest -Method GET -Uri $uri
    return ($response.Content | ConvertFrom-Json).value
}

# ================================================================================
# MAIN SCRIPT EXECUTION
# ================================================================================

# Set error handling and output preferences
$ErrorActionPreference = 'Stop'           # Stop execution on any error
$VerbosePreference = 'SilentlyContinue'   # Suppress verbose output for cleaner execution

# Define CSV header structure for the zone mapping output
$csvHeaderString = "TenantId,SubscriptionId,SubscriptionName,Location,LogicalZone,PhysicalZone,PhysicalZoneName"

# Initialize output file with CSV headers
$csvHeaderString | Out-File -Force -FilePath $OutputFile

# Get the Azure Resource Manager URL for the current Azure environment
# This is needed for constructing REST API calls and may vary by cloud (Public, Government, etc.)
$resourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl

# Populate subscription list if not provided by user
if ($SubscriptionIds.Count -eq 0) {
    $SubscriptionIds = Get-SubscriptionIds
}

# Initialize array to collect all zone mapping data
$zoneMaps = @()

# Process each subscription to extract zone mapping information
ForEach ($subscriptionId in $SubscriptionIds){
    Write-Output "Get zone peer details for $subscriptionId"
    
    # Get comprehensive zone peering data for this subscription
    $zonePeers = Get-ZonePeers -SubscriptionId $subscriptionId
    
    # Extract availability zone mappings from regions only (filter out other location types)
    # Only regions have availability zone mappings - other location types don't support zones
    $zoneMappings = ($zonePeers | Where-Object { $_.type -eq "Region"}).availabilityZoneMappings
    
    # Get subscription details for output labeling
    $subscription = Get-AzSubscription -SubscriptionId $subscriptionId

    # Process each zone mapping within this subscription
    foreach($mapping in $zoneMappings) {
        # Skip mappings with missing zone information
        # Some regions may have incomplete or null zone mapping data
        if([string]::IsNullOrEmpty($mapping.logicalZone) -or [string]::IsNullOrEmpty($mapping.physicalZone)) {
            continue
        }
        
        # Create zone mapping record with comprehensive details
        $zoneMap = [PSCustomObject]@{
            TenantId         = $Subscription.TenantId                          # Azure tenant identifier
            SubscriptionId   = $Subscription.Id                               # Subscription GUID
            SubscriptionName = $Subscription.Name                             # Human-readable subscription name
            Location         = $mapping.physicalZone.Split("-")[0]            # Region name (e.g., "eastus" from "eastus-az1")
            LogicalZone      = $mapping.logicalZone                          # Logical zone number (1, 2, 3)
            PhysicalZone     = Get-LastChar($mapping.physicalZone)           # Physical zone identifier (A, B, C or 1, 2, 3)
            PhysicalZoneName = $mapping.physicalZone                         # Full physical zone name (e.g., "eastus-az1")
        }
        
        # Add this mapping to the collection
        $zoneMaps += $zoneMap
    }
}

# Output all collected zone mapping data to CSV file
# Using -NoHeader since we already wrote headers at the beginning
$zoneMaps | ConvertTo-Csv -NoHeader | Out-File -Force -Append -FilePath $OutputFile

Write-Host "Zone mapping analysis complete. Results written to: $OutputFile"
Write-Host "Total zone mappings found: $($zoneMaps.Count)"