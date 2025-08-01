Param (
    [Parameter(Mandatory = $false)]
    [string] $TargetSubscription,

    [Parameter(Mandatory = $true)]
    [string] $ResourceType, # ARM resource type

    [Parameter(Mandatory = $false)]
    [string] $ARGFilter, # e.g., name != 'master' and sku.tier in ('Basic','Standard','Premium')

    [Parameter(Mandatory = $true)]
    [string] $MetricNames, # comma-separated metrics names (use Get-AzMetricDefinition for a list of supported metric names for a given resource)

    [Parameter(Mandatory = $true)]
    [ValidateSet("Maximum", "Minimum", "Average", "Total")]
    [string] $AggregationType,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Default", "Maximum", "Minimum", "Average", "Total")]
    [string] $AggregationOfType = "Default",

    [Parameter(Mandatory = $true)]
    [string] $TimeSpan, # [d.]hh:mm:ss

    [Parameter(Mandatory = $true)]
    [string] $TimeGrain, # [d.]hh:mm:ss (00:01:00, 00:05:00, 00:15:00, 00:30:00, 01:00:00, 06:00:00, 12:00:00, 1.00:00:00, 7.00:00:00, 30.00:00:00)

    [Parameter(Mandatory = $false)]
    [string] $externalCloudEnvironment,

    [Parameter(Mandatory = $false)]
    [string] $externalTenantId,

    [Parameter(Mandatory = $false)]
    [string] $externalCredentialName
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

$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"


$storageAccountSinkEnv = Get-AutomationVariable -Name "AzureOptimization_StorageSinkEnvironment" -ErrorAction SilentlyContinue
if (-not($storageAccountSinkEnv))
{
    $storageAccountSinkEnv = $cloudEnvironment
}
$storageAccountSinkKeyCred = Get-AutomationPSCredential -Name "AzureOptimization_StorageSinkKey" -ErrorAction SilentlyContinue
$storageAccountSinkKey = $null
if ($storageAccountSinkKeyCred)
{
    $storageAccountSink = $storageAccountSinkKeyCred.UserName
    $storageAccountSinkKey = $storageAccountSinkKeyCred.GetNetworkCredential().Password
}

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_AzMonitorContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "azmonitorexports"
}

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    $externalCredential = Get-AutomationPSCredential -Name $externalCredentialName
}

$ARGPageSize = 1000

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

if (-not($storageAccountSinkKey))
{
    Write-Output "Getting Storage Account context with login"

    $saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment
}
else
{
    Write-Output "Getting Storage Account context with key"
    $saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -StorageAccountKey $storageAccountSinkKey -Environment $storageAccountSinkEnv
}

$cloudSuffix = ""

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    "Logging in to Azure with $externalCredentialName external credential..."
    Connect-AzAccount -ServicePrincipal -EnvironmentName $externalCloudEnvironment -Tenant $externalTenantId -Credential $externalCredential
    $cloudSuffix = $externalCloudEnvironment.ToLower() + "-"
    $cloudEnvironment = $externalCloudEnvironment
}

$tenantId = (Get-AzContext).Tenant.Id

if (-not([string]::IsNullOrEmpty($TargetSubscription))) {
    $subscriptions = $TargetSubscription
    $subscriptionSuffix = "-" + $TargetSubscription
}
else {
    $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" } | ForEach-Object { "$($_.Id)"}
    $subscriptionSuffix = "all-" + $tenantId
}

[TimeSpan]::Parse($TimeGrain) | Out-Null
$TimeSpanObj = [TimeSpan]::Parse("-$TimeSpan")

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Querying for $ResourceType with page size $ARGPageSize and target subscription $TargetSubscription..."

$allResources = @()

$resultsSoFar = 0

$argWhere = ""
if (-not([string]::IsNullOrEmpty($ARGFilter)))
{
    $argWhere = " and $ARGFilter"
}

$argQuery = @"
resources
| where type =~ '$ResourceType'$argWhere
| project id, name, subscriptionId, resourceGroup, tenantId
| order by id asc
"@

do {
    if ($resultsSoFar -eq 0) {
        $resources = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else {
        $resources = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($resources -and $resources.GetType().Name -eq "PSResourceGraphResponse")
    {
        $resources = $resources.Data
    }
    $resultsCount = $resources.Count
    $resultsSoFar += $resultsCount
    $allResources += $resources

} while ($resultsCount -eq $ARGPageSize)

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Found $($allResources.Count) resources."

$metrics = $MetricNames.Split(',')

$queryDate = Get-Date
$utcNow = $queryDate.ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
$utcAgo = $queryDate.Add($TimeSpanObj).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")

$customMetrics = @()

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Analyzing resources for $MetricNames metrics ($AggregationType with $TimeGrain time grain) since $utcAgo..."

foreach ($resource in $allResources) {
    $valuesAggregation = @()
    $foundResource = $true
    foreach ($metric in $metrics) {
        $metricValues = Get-AzMetric -ResourceId $resource.id -MetricName $metric -TimeGrain $TimeGrain -AggregationType $AggregationType `
            -StartTime $utcAgo -EndTime $utcNow -WarningAction SilentlyContinue -ErrorAction Continue
        if ($metricValues.Data) {
            if ($valuesAggregation.Count -eq 0) {
                $valuesAggregation = $metricValues.Data."$AggregationType"
            }
            else {
                for ($i = 0; $i -lt $valuesAggregation.Count; $i++) {
                    if ($metricValues.Data.Count -gt 1)
                    {
                        $valuesAggregation[$i] += $metricValues.Data[$i]."$AggregationType"
                    }
                    else
                    {
                        $valuesAggregation += $metricValues.Data."$AggregationType"
                    }
                }
            }
        }

        if (-not($metricValues.Id))
        {
            $foundResource = $false
        }
    }

    if ($foundResource)
    {
        $aggregatedValue = $null
        $finalAggregationType = $AggregationType
        if ($AggregationOfType -ne "Default")
        {
            $finalAggregationType = $AggregationOfType
        }
        if ($valuesAggregation.Count -gt 0) {
            switch ($finalAggregationType) {
                "Maximum" {
                    $aggregatedValue = ($valuesAggregation | Measure-Object -Maximum).Maximum
                }
                "Minimum" {
                    $aggregatedValue = ($valuesAggregation | Measure-Object -Minimum).Minimum
                }
                "Average" {
                    $aggregatedValue = ($valuesAggregation | Measure-Object -Average).Average
                }
                "Total" {
                    $aggregatedValue = ($valuesAggregation | Measure-Object -Sum).Sum
                }
            }
        }

        $customMetric = New-Object PSObject -Property @{
            Timestamp         = $utcNow
            Cloud             = $cloudEnvironment
            TenantGuid        = $resource.tenantId
            SubscriptionGuid  = $resource.subscriptionId
            ResourceGroupName = $resource.resourceGroup.ToLower()
            ResourceName      = $resource.name.ToLower()
            ResourceId        = $resource.id.ToLower()
            MetricNames       = $MetricNames
            AggregationType   = $AggregationType
            AggregationOfType = $AggregationOfType
            MetricValue       = $aggregatedValue
            TimeGrain         = $TimeGrain
            TimeSpan          = $TimeSpan
        }

        $customMetrics += $customMetric
    }
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Found $($customMetrics.Count) resources to collect metrics from..."

$metricMoment = $queryDate.Add($TimeSpanObj).ToUniversalTime().ToString("yyyyMMddHHmmss")
$ResourceTypeName = $ResourceType.Split('/')[1].ToLower()
$MetricName = $MetricNames.Replace(',','').Replace(' ','').Replace('/','').ToLower()
$AggregationOfTypeName = ""
if ($AggregationOfType -ne "Default")
{
    $AggregationOfTypeName = ("-$AggregationOfType").ToLower()
}
$AggregationTypeName = "$($AggregationType.ToLower())$AggregationOfTypeName"
$csvExportPath = "$metricMoment-metrics-$ResourceTypeName-$MetricName-$AggregationTypeName-$subscriptionSuffix.csv"

$ci = [CultureInfo]::new([System.Threading.Thread]::CurrentThread.CurrentCulture.Name)
if ($ci.NumberFormat.NumberDecimalSeparator -ne '.')
{
    Write-Output "Current culture ($($ci.Name)) does not use . as decimal separator"
    $ci.NumberFormat.NumberDecimalSeparator = '.'
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $ci
}

$customMetrics | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."

