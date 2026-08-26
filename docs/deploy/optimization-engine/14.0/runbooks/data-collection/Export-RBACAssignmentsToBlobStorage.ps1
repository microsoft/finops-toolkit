param(
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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_RBACAssignmentsContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "rbacexports"
}

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    $externalCredential = Get-AutomationPSCredential -Name $externalCredentialName
}

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
$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }

$roleAssignments = @()

"Iterating through all reachable subscriptions..."

foreach ($subscription in $subscriptions) {

    Select-AzSubscription -SubscriptionId $subscription.Id -TenantId $tenantId | Out-Null

    $assignments = Get-AzRoleAssignment -IncludeClassicAdministrators -ErrorAction Continue
    "Found $($assignments.Count) assignments for $($subscription.Name) subscription..."

    foreach ($assignment in $assignments) {
        if ($null -eq $assignment.ObjectId -and $assignment.Scope.Contains($subscription.Id))
        {
            $assignmentEntry = New-Object PSObject -Property @{
                Timestamp         = $timestamp
                TenantGuid        = $tenantId
                Cloud             = $cloudEnvironment
                Model             = "AzureClassic"
                PrincipalId       = $assignment.SignInName
                Scope             = $assignment.Scope
                RoleDefinition    = $assignment.RoleDefinitionName
            }
            $roleAssignments += $assignmentEntry
        }
        else
        {
            $duplicateRoleAssignment = $roleAssignments | Where-Object { $_.PrincipalId -eq $assignment.ObjectId -and $_.Scope -eq $assignment.Scope -and $_.RoleDefinition -eq $assignment.RoleDefinitionName}
            if (-not($duplicateRoleAssignment))
            {
                $assignmentEntry = New-Object PSObject -Property @{
                    Timestamp         = $timestamp
                    TenantGuid        = $tenantId
                    Cloud             = $cloudEnvironment
                    Model             = "AzureRM"
                    PrincipalId       = $assignment.ObjectId
                    Scope             = $assignment.Scope
                    RoleDefinition    = $assignment.RoleDefinitionName
                }
                $roleAssignments += $assignmentEntry
            }
        }
    }
}

$fileDate = $datetime.ToString("yyyyMMdd")
$jsonExportPath = "$fileDate-$tenantId-rbacassignments.json"
$csvExportPath = "$fileDate-$tenantId-rbacassignments.csv"

$roleAssignments | ConvertTo-Json -Depth 3 -Compress | Out-File $jsonExportPath
"Exported to JSON: $($roleAssignments.Count) lines"
$rbacObjectsJson = Get-Content -Path $jsonExportPath | ConvertFrom-Json
"JSON Import: $($rbacObjectsJson.Count) lines"
$rbacObjectsJson | Export-Csv -NoTypeInformation -Path $csvExportPath
"Export to $csvExportPath"

$csvBlobName = $csvExportPath
$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
"[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
"[$now] Removed $csvExportPath from local disk..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
"[$now] Removed $jsonExportPath from local disk..."

$roleAssignments = @()

"Getting Microsoft Entra ID roles..."

#workaround for https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/888
$localPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
if (-not(get-item "$localPath\.graph\" -ErrorAction SilentlyContinue))
{
    New-Item -Type Directory "$localPath\.graph"
}

Import-Module Microsoft.Graph.Identity.DirectoryManagement

switch ($cloudEnvironment) {
    "AzureUSGovernment" {
        $graphEnvironment = "USGov"
        break
    }
    "AzureChinaCloud" {
        $graphEnvironment = "China"
        break
    }
    "AzureGermanCloud" {
        $graphEnvironment = "Germany"
        break
    }
    Default {
        $graphEnvironment = "Global"
    }
}

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    "Logging in to Microsoft Graph with $externalCredentialName external credential..."
    Connect-MgGraph -TenantId $externalTenantId -ClientSecretCredential $externalCredential -Environment $graphEnvironment -NoWelcome
}
else
{
    "Logging in to Microsoft Graph with $authenticationOption..."

    switch ($authenticationOption) {
        "UserAssignedManagedIdentity" {
            Connect-MgGraph -Identity -ClientId $uamiClientID -Environment $graphEnvironment -NoWelcome
            break
        }
        Default { #ManagedIdentity
            Connect-MgGraph -Identity -Environment $graphEnvironment -NoWelcome
            break
        }
    }
}

$domainName = (Get-MgDomain | Where-Object { $_.IsVerified -and $_.IsDefault } | Select-Object -First 1).Id

$roles = Get-MgDirectoryRole -ExpandProperty Members -Property DisplayName,Members
foreach ($role in $roles)
{
    $roleMembers = $role.Members | Where-Object { -not($_.DeletedDateTime) }
    foreach ($roleMember in $roleMembers)
    {
        $assignmentEntry = New-Object PSObject -Property @{
            Timestamp         = $timestamp
            TenantGuid        = $tenantId
            Cloud             = $cloudEnvironment
            Model             = "AzureAD"
            PrincipalId       = $roleMember.Id
            Scope             = $domainName
            RoleDefinition    = $role.DisplayName
        }
        $roleAssignments += $assignmentEntry
    }
}

$fileDate = $datetime.ToString("yyyyMMdd")
$jsonExportPath = "$fileDate-$tenantId-aadrbacassignments.json"
$csvExportPath = "$fileDate-$tenantId-aadrbacassignments.csv"

$roleAssignments | ConvertTo-Json -Depth 3 -Compress | Out-File $jsonExportPath
"Exported to JSON: $($roleAssignments.Count) lines"
$rbacObjectsJson = Get-Content -Path $jsonExportPath | ConvertFrom-Json
"JSON Import: $($rbacObjectsJson.Count) lines"
$rbacObjectsJson | Export-Csv -NoTypeInformation -Path $csvExportPath
"Export to $csvExportPath"

$csvBlobName = $csvExportPath
$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
"[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
"[$now] Removed $csvExportPath from local disk..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
"[$now] Removed $jsonExportPath from local disk..."
