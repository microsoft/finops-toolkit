param(
    [Parameter(Mandatory = $false)]
    [bool] $Simulate = $true
)

$ErrorActionPreference = "Stop"

$cloudEnvironment = Get-AutomationVariable -Name "AzureOptimization_CloudEnvironment" -ErrorAction SilentlyContinue # AzureCloud|AzureChinaCloud
if ([string]::IsNullOrEmpty($cloudEnvironment))
{
    $cloudEnvironment = "AzureCloud"
}
$authenticationOption = Get-AutomationVariable -Name  "AzureOptimization_AuthenticationOption" -ErrorAction SilentlyContinue # ManagedIdentity|UserAssignedManagedIdentity
if ([string]::IsNullOrEmpty($authenticationOption))
{
    $authenticationOption = "ManagedIdentity"
}
if ($authenticationOption -eq "UserAssignedManagedIdentity")
{
    $uamiClientID = Get-AutomationVariable -Name "AzureOptimization_UAMIClientID"
}

$sqlserver = Get-AutomationVariable -Name  "AzureOptimization_SQLServerHostname"
$sqldatabase = Get-AutomationVariable -Name  "AzureOptimization_SQLServerDatabase" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($sqldatabase))
{
    $sqldatabase = "azureoptimization"
}
$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"


$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_RemediationLogsContainer" -ErrorAction SilentlyContinue 
if ([string]::IsNullOrEmpty($storageAccountSinkContainer)) {
    $storageAccountSinkContainer = "remediationlogs"
}

$minFitScore = [double] (Get-AutomationVariable -Name  "AzureOptimization_RemediateLongDeallocatedVMsMinFitScore" -ErrorAction SilentlyContinue)
if (-not($minFitScore -gt 0.0)) {
    $minFitScore = 5.0
}

$minWeeksInARow = [int] (Get-AutomationVariable -Name  "AzureOptimization_RemediateLongDeallocatedVMsMinWeeksInARow" -ErrorAction SilentlyContinue)
if (-not($minWeeksInARow -gt 0)) {
    $minWeeksInARow = 4
}

$tagsFilter = Get-AutomationVariable -Name  "AzureOptimization_RemediateLongDeallocatedVMsTagsFilter" -ErrorAction SilentlyContinue
# example: '[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]'
if (-not($tagsFilter)) {
    $tagsFilter = '{}'
}
$tagsFilter = $tagsFilter | ConvertFrom-Json

$recommendationId = Get-AutomationVariable -Name  "AzureOptimization_RecommendationLongDeallocatedVMsId" -ErrorAction SilentlyContinue
if (-not($recommendationId)) {
    $recommendationId = 'c320b790-2e58-452a-aa63-7b62c383ad8a'
}

$SqlTimeout = 0
$recommendationsTable = "Recommendations"

"Logging in to Azure with $authenticationOption..."

switch ($authenticationOption) {
    "UserAssignedManagedIdentity" { 
        Connect-AzAccount -Identity -EnvironmentName $cloudEnvironment -AccountId $uamiClientID
        break
    }
    Default { #ManagedIdentity
        Connect-AzAccount -Identity -EnvironmentName $cloudEnvironment 
        break
    }
}

$cloudDetails = Get-AzEnvironment -Name $CloudEnvironment
$azureSqlDomain = $cloudDetails.SqlDatabaseDnsSuffix.Substring(1)

# get reference to storage sink

$saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment

Write-Output "Querying for long-deallocated recommendations with fit score >= $minFitScore made consecutively for the last $minWeeksInARow weeks."

$tries = 0
$connectionSuccess = $false
do {
    $tries++
    try {
        $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/"
        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;Encrypt=True;Connection Timeout=$SqlTimeout;") 
        $Conn.AccessToken = $dbToken.Token
        $Conn.Open() 
        $Cmd=new-object system.Data.SqlClient.SqlCommand
        $Cmd.Connection = $Conn
        $Cmd.CommandTimeout = $SqlTimeout
        $Cmd.CommandText = @"
        SELECT InstanceId, Cloud, TenantGuid, COUNT(InstanceId)
        FROM [dbo].[$recommendationsTable] 
        WHERE RecommendationSubTypeId = '$recommendationId' AND FitScore >= $minFitScore AND GeneratedDate >= GETDATE()-(7*$minWeeksInARow)
        GROUP BY InstanceId, Cloud, TenantGuid
        HAVING COUNT(InstanceId) >= $minWeeksInARow
"@    
        $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $sqlAdapter.SelectCommand = $Cmd
        $deallocatedVMs = New-Object System.Data.DataTable
        $sqlAdapter.Fill($deallocatedVMs) | Out-Null            
        $connectionSuccess = $true
    }
    catch {
        Write-Output "Failed to contact SQL at try $tries."
        Write-Output $Error[0]
        Start-Sleep -Seconds ($tries * 20)
    }    
} while (-not($connectionSuccess) -and $tries -lt 3)

if (-not($connectionSuccess))
{
    throw "Could not establish connection to SQL."
}

Write-Output "Found $($deallocatedVMs.Rows.Count) remediation opportunities."

$Conn.Close()    
$Conn.Dispose()            

$logEntries = @()

$datetime = (get-date).ToUniversalTime()
$hour = $datetime.Hour
$min = $datetime.Minute
$timestamp = $datetime.ToString("yyyy-MM-ddT$($hour):$($min):00.000Z")

$ctx = Get-AzContext

foreach ($vm in $deallocatedVMs.Rows)
{
    $isEligible = $false
    $logDetails = $null
    if ([string]::IsNullOrEmpty($tagsFilter))
    {
        $isEligible = $true
    }
    else
    {
        $vmTags = Get-AzTag -ResourceId $vm.InstanceId -ErrorAction SilentlyContinue
        if ($vmTags)
        {
            foreach ($tagFilter in $tagsFilter)
            {
                if ($vmTags.Properties.TagsProperty.($tagFilter.tagName) -eq $tagFilter.tagValue)
                {
                    $isEligible = $true
                }
                else
                {
                    $isEligible = $false
                    break
                }
            }
        }
    }

    $subscriptionId = $vm.InstanceId.Split("/")[2]
    $resourceGroup = $vm.InstanceId.Split("/")[4]
    $instanceName = $vm.InstanceId.Split("/")[8]
    
    if ($isEligible)
    {
        $vmState = "Unknown"
        $hasManagedDisks = $false
        $osDiskSkuName = "Unknown"
        $dataDisksSkuNames = "Unknown"

        Write-Output "Downsizing (SIMULATE=$Simulate) $($vm.InstanceId) disks to Standard_LRS..."
        if ($ctx.Environment.Name -eq $vm.Cloud -and $ctx.Tenant.Id -eq $vm.TenantGuid)
        {
            if ($ctx.Subscription.Id -ne $subscriptionId)
            {
                Select-AzSubscription -SubscriptionId $subscriptionId | Out-Null
                $ctx = Get-AzContext
            }
            $vmObj = Get-AzVM -ResourceGroupName $resourceGroup -VMName $instanceName -Status -ErrorAction SilentlyContinue
            if ($vmObj.PowerState -eq 'VM deallocated')
            {
                $vmState = "Deallocated"
                $osDiskId = $vmObj.StorageProfile.OsDisk.ManagedDisk.Id
                $dataDiskIds = $vmObj.StorageProfile.DataDisks.ManagedDisk.Id
                if ($osDiskId)
                {
                    $hasManagedDisks = $true
                    $disk = Get-AzDisk -ResourceGroupName $osDiskId.Split("/")[4] -DiskName $osDiskId.Split("/")[8]
                    $osDiskSkuName = $disk.Sku.Name
                    if (-not($Simulate) -and $disk.Sku.Name -ne 'Standard_LRS')
                    {
                        $disk.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new('Standard_LRS')
                        $disk | Update-AzDisk | Out-Null
                    }
                    else
                    {
                        Write-Output "Skipping as OS disk is already HDD."                        
                    }
                    foreach ($dataDiskId in $dataDiskIds)
                    {
                        $disk = Get-AzDisk -ResourceGroupName $dataDiskId.Split("/")[4] -DiskName $dataDiskId.Split("/")[8]
                        if ($dataDisksSkuNames -eq 'Unknown')
                        {
                            $dataDisksSkuNames = $disk.Sku.Name
                        }
                        else
                        {
                            if ($dataDisksSkuNames -notlike "*$($disk.Sku.Name)*")
                            {
                                $dataDisksSkuNames += ",$($disk.Sku.Name)"
                            }
                        }
                        
                        if (-not($Simulate) -and $disk.Sku.Name -ne 'Standard_LRS')
                        {
                            $disk.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new('Standard_LRS')
                            $disk | Update-AzDisk | Out-Null
                        }
                        else
                        {
                            Write-Output "Skipping as Data disk is already HDD."                        
                        }                            
                    }
                }
                else
                {
                    Write-Output "Skipping as disks are not Managed Disks."    
                    $hasManagedDisks = $false
                }
            }
            else
            {
                if ($vmObj)
                {
                    Write-Output "Skipping as VM is not deallocated."    
                    $vmState = "Running"
                }
                else
                {
                    Write-Output "Skipping as VM was already removed."    
                    $vmState = "Removed"                        
                }
            }
        }
        else
        {
            Write-Output "Could not apply remediation as VM is in another cloud/tenant."    
        }
    }

    $logDetails = @{
        IsEligible = $isEligible
        VMState = $vmState
        HasManagedDisks = $hasManagedDisks
        OsDiskSkuName = $osDiskSkuName
        DataDisksSkuName = $dataDisksSkuNames
    }

    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $vm.Cloud
        TenantGuid = $vm.TenantGuid
        SubscriptionGuid = $subscriptionId
        ResourceGroupName = $resourceGroup.ToLower()
        InstanceName = $instanceName.ToLower()
        InstanceId = $vm.InstanceId.ToLower()
        Simulate = $Simulate
        LogDetails = $logDetails | ConvertTo-Json -Compress
        RecommendationSubTypeId = $recommendationId
    }
    
    $logEntries += $logentry
}
    
$today = $datetime.ToString("yyyyMMdd")
$csvExportPath = "$today-longdeallocatedvmsfiltered.csv"

$logEntries | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force
