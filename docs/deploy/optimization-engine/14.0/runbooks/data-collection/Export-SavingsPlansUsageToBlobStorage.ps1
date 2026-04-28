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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_SavingsPlansContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "savingsplansexports"
}

$BillingAccountIDVar = Get-AutomationVariable -Name  "AzureOptimization_BillingAccountID" -ErrorAction SilentlyContinue
$BillingProfileIDVar = Get-AutomationVariable -Name  "AzureOptimization_BillingProfileID" -ErrorAction SilentlyContinue

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    $externalCredential = Get-AutomationPSCredential -Name $externalCredentialName
}

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
        #$scope = "/providers/Microsoft.BillingBenefits"
        $scope = "/providers/Microsoft.Billing/billingaccounts/$BillingAccountID"
    }
    else
    {
        $scope = "/providers/Microsoft.Billing/billingaccounts/$BillingAccountID"
    }
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Starting savings plans export process for scope $scope..."

$savingsPlansUsage = @()
if ($BillingAccountID -match $mcaBillingAccountIdRegex)
{
    #$savingsPlansUsagePath = "$scope/savingsPlans?api-version=2022-11-01&refreshsummary=true&take=100"
    $savingsPlansUsagePath = "$scope/savingsPlans?api-version=2022-10-01-privatepreview&refreshsummary=true&take=100&`$filter=(properties/billingProfileId eq '/providers/Microsoft.Billing/billingAccounts/$BillingAccountID/billingProfiles/$BillingProfileID')"
}
else
{
    $savingsPlansUsagePath = "$scope/savingsPlans?api-version=2020-12-15-privatepreview&refreshsummary=true&take=100"
}

$result = Invoke-AzRestMethod -Path $savingsPlansUsagePath -Method GET

if (-not($result.StatusCode -in (200, 201, 202)))
{
    throw "Error while getting savings plans usage: $($result.Content)"
}

$savingsPlansUsageResponse = $result.Content | ConvertFrom-Json
if ($savingsPlansUsageResponse.value)
{
    $savingsPlansUsage += $savingsPlansUsageResponse.value
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Found $($savingsPlansUsage.Count) savings plans usages."

$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

$savingsPlans = @()

foreach ($usage in $savingsPlansUsage)
{
    $purchaseDate = $usage.properties.purchaseDateTime
    if ([string]::IsNullOrEmpty($purchaseDate) -and -not([string]::IsNullOrEmpty($usage.properties.purchaseDate)))
    {
        $purchaseDate = (Get-Date -Date $usage.properties.purchaseDate).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    }
    $expiryDate = $usage.properties.expiryDateTime
    if ([string]::IsNullOrEmpty($expiryDate) -and -not([string]::IsNullOrEmpty($usage.properties.expiryDate)))
    {
        $expiryDate = (Get-Date -Date $usage.properties.expiryDate).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    }

    $savingsPlanEntry = New-Object PSObject -Property @{
        SavingsPlanResourceId = $usage.id
        SavingsPlanOrderId = $usage.id.Substring(0,$usage.id.IndexOf("/savingsPlans/"))
        SavingsPlanId = $usage.id.Split("/")[-1]
        DisplayName = $usage.properties.displayName
        SKUName = $usage.sku.name
        Term = $usage.properties.term
        ProvisioningState = $usage.properties.displayProvisioningState
        AppliedScopeType = $usage.properties.userFriendlyAppliedScopeType
        RenewState = $usage.properties.renew
        PurchaseDate = $purchaseDate
        BenefitStart = $usage.properties.benefitStartTime
        ExpiryDate = $expiryDate
        EffectiveDate = $usage.properties.effectiveDateTime
        BillingScopeId = $usage.properties.billingScopeId
        BillingAccountId = $usage.properties.billingAccountId
        BillingProfileId = $usage.properties.billingProfileId
        BillingPlan = $usage.properties.billingPlan
        CommitmentGrain = $usage.properties.commitment.grain
        CommitmentCurrencyCode = $usage.properties.commitment.currencyCode
        CommitmentAmount = $usage.properties.commitment.amount
        UtilTrend = $usage.properties.utilization.trend
        Util1Days = ($usage.properties.utilization.aggregates | Where-Object { $_.grain -eq 1 }).value
        Util7Days = ($usage.properties.utilization.aggregates | Where-Object { $_.grain -eq 7 }).value
        Util30Days = ($usage.properties.utilization.aggregates | Where-Object { $_.grain -eq 30 }).value
        Scope = $scope
        TenantGuid = $tenantId
        Cloud = $cloudEnvironment
        CollectedDate = $timestamp
        Timestamp = $timestamp
    }
    $savingsPlans += $savingsPlanEntry
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Generated $($savingsPlans.Count) entries..."

$targetDate = $datetime.ToString("yyyy-MM-dd")

if ($BillingAccountID -match $mcaBillingAccountIdRegex)
{
    $csvExportPath = "$targetDate-$BillingProfileID.csv"
}
else
{
    $csvExportPath = "$targetDate-$BillingAccountID.csv"
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

$savingsPlans | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath
$csvProperties = @{"ContentType" = "text/csv"};
Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."