###########################################################################
# GET-AHBOPPORTUNITIES.PS1
# AZURE FINOPS MULTITOOL - Azure Hybrid Benefit Gap Detection
###########################################################################
# Purpose: Use Resource Graph to find VMs and SQL resources that are NOT
#          using Azure Hybrid Benefit (AHB) but could be. AHB saves up
#          to 85% on Windows Server and SQL Server licensing costs.
#
# Eligible resources:
#   - Windows VMs without licenseType = 'Windows_Server'
#   - SQL Server VMs without licenseType = 'AHUB'
#   - SQL Databases/Managed Instances without licenseType = 'BasePrice'
#
# Reference: https://learn.microsoft.com/en-us/azure/azure-sql/azure-hybrid-benefit
###########################################################################

function Get-AHBOpportunities {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    $subIds = $Subscriptions | ForEach-Object { $_.Id }

    # -- Windows VMs without AHB ----------------------------------------
    $windowsVMs = @()
    try {
        Write-Host "  Scanning Windows VMs for AHB eligibility..." -ForegroundColor Cyan
        $vmQuery = @"
resources
| where type == 'microsoft.compute/virtualmachines'
| where properties.storageProfile.osDisk.osType =~ 'Windows'
| where isempty(properties.licenseType) or properties.licenseType !~ 'Windows_Server'
| project name, resourceGroup, subscriptionId, location,
          vmSize = properties.hardwareProfile.vmSize,
          currentLicense = coalesce(tostring(properties.licenseType), 'None'),
          osType = tostring(properties.storageProfile.imageReference.offer)
| order by subscriptionId asc, name asc
"@
        $result = Search-AzGraphSafe -Query $vmQuery -Subscription $subIds -First 1000
        $windowsVMs = if ($result) { @($result.Data) } else { @() }
    } catch {
        Write-Warning "Windows VM AHB scan failed: $($_.Exception.Message)"
    }

    # -- SQL Server VMs without AHB -------------------------------------
    $sqlVMs = @()
    try {
        Write-Host "  Scanning SQL Server VMs for AHB eligibility..." -ForegroundColor Cyan
        $sqlVMQuery = @"
resources
| where type == 'microsoft.sqlvirtualmachine/sqlvirtualmachines'
| where isempty(properties.sqlServerLicenseType) or properties.sqlServerLicenseType !~ 'AHUB'
| project name, resourceGroup, subscriptionId, location,
          currentLicense = coalesce(tostring(properties.sqlServerLicenseType), 'None'),
          sqlEdition = tostring(properties.sqlImageSku)
| order by subscriptionId asc, name asc
"@
        $result = Search-AzGraphSafe -Query $sqlVMQuery -Subscription $subIds -First 1000
        $sqlVMs = if ($result) { @($result.Data) } else { @() }
    } catch {
        Write-Warning "SQL VM AHB scan failed: $($_.Exception.Message)"
    }

    # -- SQL Databases without AHB --------------------------------------
    $sqlDBs = @()
    try {
        Write-Host "  Scanning SQL Databases for AHB eligibility..." -ForegroundColor Cyan
        $sqlDBQuery = @"
resources
| where type == 'microsoft.sql/servers/databases'
| where sku.tier != 'Free' and name != 'master'
| where isempty(properties.licenseType) or properties.licenseType !~ 'BasePrice'
| project name, resourceGroup, subscriptionId, location,
          currentLicense = coalesce(tostring(properties.licenseType), 'LicenseIncluded'),
          sku = strcat(tostring(sku.tier), ' / ', tostring(sku.name)),
          maxSizeGB = tolong(properties.maxSizeBytes) / 1073741824
| order by subscriptionId asc, name asc
"@
        $result = Search-AzGraphSafe -Query $sqlDBQuery -Subscription $subIds -First 1000
        $sqlDBs = if ($result) { @($result.Data) } else { @() }
    } catch {
        Write-Warning "SQL Database AHB scan failed: $($_.Exception.Message)"
    }

    # -- Summary --------------------------------------------------------
    $totalOpportunities = $windowsVMs.Count + $sqlVMs.Count + $sqlDBs.Count

    return [PSCustomObject]@{
        WindowsVMs          = $windowsVMs
        SQLVMs              = $sqlVMs
        SQLDatabases        = $sqlDBs
        TotalOpportunities  = $totalOpportunities
        Summary             = "Found $($windowsVMs.Count) Windows VMs, $($sqlVMs.Count) SQL VMs, $($sqlDBs.Count) SQL DBs eligible for AHB"
    }
}
