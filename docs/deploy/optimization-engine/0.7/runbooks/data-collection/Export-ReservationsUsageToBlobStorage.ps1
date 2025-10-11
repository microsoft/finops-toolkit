param(
    [Parameter(Mandatory = $false)]
    [string] $TargetScope,

    [Parameter(Mandatory = $false)]
    [string] $BillingAccountID,

    [Parameter(Mandatory = $false)]
    [string] $BillingProfileID,

    [Parameter(Mandatory = $false)]
    [string] $externalCloudEnvironment,

    [Parameter(Mandatory = $false)]
    [string] $externalTenantId,

    [Parameter(Mandatory = $false)]
    [string] $externalCredentialName,

    [Parameter(Mandatory = $false)] 
    [string] $targetStartDate, # YYYY-MM-DD format

    [Parameter(Mandatory = $false)] 
    [string] $targetEndDate # YYYY-MM-DD format
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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_ReservationsContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "reservationsexports"
}

$BillingAccountIDVar = Get-AutomationVariable -Name  "AzureOptimization_BillingAccountID" -ErrorAction SilentlyContinue
$BillingProfileIDVar = Get-AutomationVariable -Name  "AzureOptimization_BillingProfileID" -ErrorAction SilentlyContinue

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    $externalCredential = Get-AutomationPSCredential -Name $externalCredentialName
}

$consumptionOffsetDays = [int] (Get-AutomationVariable -Name  "AzureOptimization_ConsumptionOffsetDays")

if ([string]::IsNullOrEmpty($BillingAccountID) -and -not([string]::IsNullOrEmpty($BillingAccountIDVar)))
{
    $BillingAccountID = $BillingAccountIDVar
}

if ([string]::IsNullOrEmpty($BillingProfileID) -and -not([string]::IsNullOrEmpty($BillingProfileIDVar)))
{
    $BillingProfileID = $BillingProfileIDVar
}

$mcaBillingAccountIdRegex = "([A-Za-z0-9]+(-[A-Za-z0-9]+)+):([A-Za-z0-9]+(-[A-Za-z0-9]+)+)_[0-9]{4}-[0-9]{2}-[0-9]{2}"
$mcaBillingProfileIdRegex = "([A-Za-z0-9]+(-[A-Za-z0-9]+)+)"

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

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    "Logging in to Azure with $externalCredentialName external credential..."
    Connect-AzAccount -ServicePrincipal -EnvironmentName $externalCloudEnvironment -Tenant $externalTenantId -Credential $externalCredential 
    $cloudEnvironment = $externalCloudEnvironment   
}

$tenantId = (Get-AzContext).Tenant.Id

# compute start+end dates

if ([string]::IsNullOrEmpty($targetStartDate) -or [string]::IsNullOrEmpty($targetEndDate))
{
    $targetStartDate = (Get-Date).Date.AddDays($consumptionOffsetDays * -1).ToString("yyyy-MM-dd")
    $targetEndDate = $targetStartDate    
}

if (-not([string]::IsNullOrEmpty($TargetScope)))
{
    $scope = $TargetScope
}
else
{
    if ([string]::IsNullOrEmpty($BillingAccountID))
    {
        throw "Billing Account ID undefined. Use either the AzureOptimization_BillingAccountID variable or the BillingAccountID parameter"
    }
    if ($BillingAccountID -match $mcaBillingAccountIdRegex)
    {
        if ([string]::IsNullOrEmpty($BillingProfileID))
        {
            throw "Billing Profile ID undefined for MCA. Use either the AzureOptimization_BillingProfileID variable or the BillingProfileID parameter"
        }
        if (-not($BillingProfileID -match $mcaBillingProfileIdRegex))
        {
            throw "Billing Profile ID does not follow pattern for MCA: ([A-Za-z0-9]+(-[A-Za-z0-9]+)+)"
        }
        $scope = "/providers/Microsoft.Billing/billingaccounts/$BillingAccountID/billingProfiles/$BillingProfileID"
    }
    else
    {
        $scope = "/providers/Microsoft.Billing/billingaccounts/$BillingAccountID"
    }
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Starting reservations export process from $targetStartDate to $targetEndDate for scope $scope..."

# get reservations details

$reservationsDetailsResponse = $null
$reservationsDetails = @()
$reservationsDetailsPath = "$scope/reservations?api-version=2020-05-01&&refreshSummary=true"

do
{
    if (-not([string]::IsNullOrEmpty($reservationsDetailsResponse.nextLink)))
    {
        $reservationsDetailsPath = $reservationsDetailsResponse.nextLink.Substring($reservationsDetailsResponse.nextLink.IndexOf("/providers/"))
    }

    $result = Invoke-AzRestMethod -Path $reservationsDetailsPath -Method GET

    if (-not($result.StatusCode -in (200, 201, 202)))
    {
        throw "Error while getting reservations details: $($result.Content)"
    }

    $reservationsDetailsResponse = $result.Content | ConvertFrom-Json
    if ($reservationsDetailsResponse.value)
    {
        $reservationsDetails += $reservationsDetailsResponse.value
    }
}
while (-not([string]::IsNullOrEmpty($reservationsDetailsResponse.nextLink)))

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Found $($reservationsDetails.Count) reservation details."

# get reservations usage

$reservationsUsage = @()
if ($BillingAccountID -match $mcaBillingAccountIdRegex)
{
    $reservationsUsagePath = "$scope/providers/Microsoft.Consumption/reservationSummaries?api-version=2023-05-01&startDate=$targetStartDate&endDate=$targetEndDate&grain=daily"
}
else
{
    $reservationsUsagePath = "$scope/providers/Microsoft.Consumption/reservationSummaries?api-version=2023-05-01&`$filter=properties/UsageDate ge $targetStartDate and properties/UsageDate le $targetEndDate&grain=daily"
}

$result = Invoke-AzRestMethod -Path $reservationsUsagePath -Method GET

if (-not($result.StatusCode -in (200, 201, 202)))
{
    throw "Error while getting reservations usage: $($result.Content)"
}

$reservationsUsageResponse = $result.Content | ConvertFrom-Json
if ($reservationsUsageResponse.value)
{
    $reservationsUsage += $reservationsUsageResponse.value
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Found $($reservationsUsage.Count) reservation usages."

$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

$reservations = @()

foreach ($usage in $reservationsUsage)
{
    $reservationResourceId = "/providers/microsoft.capacity/reservationorders/$($usage.properties.reservationOrderId)/reservations/$($usage.properties.reservationId)"
    $reservationDetail = $reservationsDetails | Where-Object { $_.id -eq $reservationResourceId }
    $reservationEntry = New-Object PSObject -Property @{
        ReservationResourceId = $reservationResourceId
        ReservationOrderId = $usage.properties.reservationOrderId
        ReservationId = $usage.properties.reservationId
        DisplayName = $reservationDetail.properties.displayName
        SKUName = $usage.properties.skuName
        Location = $reservationDetail.location
        ResourceType = $reservationDetail.properties.reservedResourceType
        AppliedScopeType = $reservationDetail.properties.userFriendlyAppliedScopeType
        Term = $reservationDetail.properties.term
        ProvisioningState = $reservationDetail.properties.displayProvisioningState
        RenewState = $reservationDetail.properties.userFriendlyRenewState
        PurchaseDate = $reservationDetail.properties.purchaseDate
        ExpiryDate = $reservationDetail.properties.expiryDate
        Archived = $reservationDetail.properties.archived
        ReservedHours = $usage.properties.reservedHours
        UsedHours = $usage.properties.usedHours
        UsageDate = $usage.properties.usageDate
        MinUtilPercentage = $usage.properties.minUtilizationPercentage
        AvgUtilPercentage = $usage.properties.avgUtilizationPercentage
        MaxUtilPercentage = $usage.properties.maxUtilizationPercentage
        PurchasedQuantity = $usage.properties.purchasedQuantity
        RemainingQuantity = $usage.properties.remainingQuantity
        TotalReservedQuantity = $usage.properties.totalReservedQuantity
        UsedQuantity = $usage.properties.usedQuantity
        UtilizedPercentage = $usage.properties.utilizedPercentage
        UtilTrend = $reservationDetail.properties.utilization.trend
        Util1Days = ($reservationDetail.properties.utilization.aggregates | Where-Object { $_.grain -eq 1 }).value
        Util7Days = ($reservationDetail.properties.utilization.aggregates | Where-Object { $_.grain -eq 7 }).value
        Util30Days = ($reservationDetail.properties.utilization.aggregates | Where-Object { $_.grain -eq 30 }).value
        Scope = $scope
        TenantGuid = $tenantId
        Cloud = $cloudEnvironment
        CollectedDate = $timestamp
        Timestamp = $timestamp
    }
    $reservations += $reservationEntry
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Generated $($reservations.Count) entries..."

if ($BillingAccountID -match $mcaBillingAccountIdRegex)
{
    $csvExportPath = "$targetStartDate-$BillingProfileID.csv"   
}
else
{
    $csvExportPath = "$targetStartDate-$BillingAccountID-$($scope.Split('/')[-1]).csv"
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploading CSV to Storage"

$ci = [CultureInfo]::new([System.Threading.Thread]::CurrentThread.CurrentCulture.Name)
if ($ci.NumberFormat.NumberDecimalSeparator -ne '.')
{
    Write-Output "Current culture ($($ci.Name)) does not use . as decimal separator"    
    $ci.NumberFormat.NumberDecimalSeparator = '.'
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $ci
}

$reservations | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath
$csvProperties = @{"ContentType" = "text/csv"};
Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force
    
$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."    