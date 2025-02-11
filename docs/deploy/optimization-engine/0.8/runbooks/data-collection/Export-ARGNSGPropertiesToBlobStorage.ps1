param(
    [Parameter(Mandatory = $false)]
    [string] $TargetSubscription,

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
$referenceRegion = Get-AutomationVariable -Name "AzureOptimization_ReferenceRegion" -ErrorAction SilentlyContinue # e.g., westeurope
if ([string]::IsNullOrEmpty($referenceRegion))
{
    $referenceRegion = "westeurope"
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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_ARGNSGContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "argnsgexports"
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

$allnsgRules = @()

Write-Output "Getting subscriptions target $TargetSubscription"
if (-not([string]::IsNullOrEmpty($TargetSubscription)))
{
    $subscriptions = $TargetSubscription
    $subscriptionSuffix = $TargetSubscription
}
else
{
    $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" } | ForEach-Object { "$($_.Id)"}
    $subscriptionSuffix = $cloudSuffix + "all-" + $tenantId
}

$nsgRulesTotal = @()

$resultsSoFar = 0

Write-Output "Querying for NSG properties"

$argQuery = @"
resources
| where type =~ 'Microsoft.Network/networkSecurityGroups' 
| extend nicCount = iif(isnotempty(properties.networkInterfaces),array_length(properties.networkInterfaces),0)
| extend subnetCount = iif(isnotempty(properties.subnets),array_length(properties.subnets),0)
| mvexpand securityRules = properties.securityRules
| extend ruleName = tolower(securityRules.name)
| extend ruleProtocol = tolower(securityRules.properties.protocol)
| extend ruleDirection = tolower(securityRules.properties.direction)
| extend rulePriority = toint(securityRules.properties.priority)
| extend ruleAccess = tolower(securityRules.properties.access)
| extend ruleDestinationAddresses = tolower(iif(array_length(securityRules.properties.destinationAddressPrefixes) > 0,strcat_array(securityRules.properties.destinationAddressPrefixes, ','),securityRules.properties.destinationAddressPrefix))
| extend ruleSourceAddresses = tolower(iif(array_length(securityRules.properties.sourceAddressPrefixes) > 0,strcat_array(securityRules.properties.sourceAddressPrefixes, ','),securityRules.properties.sourceAddressPrefix))
| extend ruleDestinationPorts = iif(array_length(securityRules.properties.destinationPortRanges) > 0,strcat_array(securityRules.properties.destinationPortRanges, ','),securityRules.properties.destinationPortRange)
| extend ruleSourcePorts = iif(array_length(securityRules.properties.sourcePortRanges) > 0,strcat_array(securityRules.properties.sourcePortRanges, ','),securityRules.properties.sourcePortRange)
| extend ruleId = tolower(securityRules.id)
| project-away securityRules, properties
| order by ruleId asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $nsgRules = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $nsgRules = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($nsgRules -and $nsgRules.GetType().Name -eq "PSResourceGraphResponse")
    {
        $nsgRules = $nsgRules.Data
    }
    $resultsCount = $nsgRules.Count
    $resultsSoFar += $resultsCount
    $nsgRulesTotal += $nsgRules

} while ($resultsCount -eq $ARGPageSize)

$datetime = (Get-Date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")
$statusDate = $datetime.ToString("yyyy-MM-dd")

Write-Output "Building $($nsgRulesTotal.Count) ARM NSG entries"

foreach ($nsgRule in $nsgRulesTotal)
{
    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $nsgRule.tenantId
        SubscriptionGuid = $nsgRule.subscriptionId
        ResourceGroupName = $nsgRule.resourceGroup.ToLower()
        Location = $nsgRule.location
        NSGName = $nsgRule.name.ToLower()
        InstanceId = $nsgRule.id.ToLower()
        NicCount = $nsgRule.nicCount
        SubnetCount = $nsgRule.subnetCount
        RuleName = $nsgRule.ruleName
        RuleProtocol = $nsgRule.ruleProtocol
        RuleDirection = $nsgRule.ruleDirection
        RulePriority = $nsgRule.rulePriority
        RuleAccess = $nsgRule.ruleAccess
        RuleDestinationAddresses = $nsgRule.ruleDestinationAddresses
        RuleSourceAddresses = $nsgRule.ruleSourceAddresses
        RuleDestinationPorts = $nsgRule.ruleDestinationPorts
        RuleSourcePorts = $nsgRule.ruleSourcePorts
        Tags = $nsgRule.tags
        StatusDate = $statusDate
    }
    
    $allnsgRules += $logentry
}

Write-Output "Uploading CSV to Storage"

$today = $datetime.ToString("yyyyMMdd")
$csvExportPath = "$today-nsgrules-$subscriptionSuffix.csv"

$allnsgRules | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."    