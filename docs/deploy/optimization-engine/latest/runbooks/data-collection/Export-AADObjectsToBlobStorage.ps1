param(
    [Parameter(Mandatory = $false)]
    [string] $externalCloudEnvironment,

    [Parameter(Mandatory = $false)]
    [string] $externalTenantId,

    [Parameter(Mandatory = $false)]
    [string] $externalCredentialName,

    [Parameter(Mandatory = $false)]
    [string] $groupFilter,

    [Parameter(Mandatory = $false)]
    [string] $userFilter
)

$ErrorActionPreference = "Stop"

function Build-CredObjectWithDates {
    param (
        [object] $appObject
    )
    
    $credObjects = @()

    foreach ($obj in $appObject.KeyCredentials)
    {
        $credObject = New-Object PSObject -Property @{
            DisplayName = $obj.DisplayName
            KeyId = $obj.KeyId
            KeyType = $obj.Type
            StartDate = (Get-Date($obj.StartDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
            EndDate = (Get-Date($obj.EndDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
        }
        $credObjects += $credObject        
    }

    foreach ($obj in $appObject.PasswordCredentials)
    {
        $credObject = New-Object PSObject -Property @{
            DisplayName = $obj.DisplayName
            KeyId = $obj.KeyId
            KeyType = "Password"
            StartDate = (Get-Date($obj.StartDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
            EndDate = (Get-Date($obj.EndDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
        }
        $credObjects += $credObject        
    }

    return $credObjects
}

function Build-PrincipalNames {
    param (
        [object] $appObject
    )
    
    $principalNames = @()

    if ($appObject.Web.HomePageUrl)
    {
        $principalNames += $appObject.Web.HomePageUrl
    }

    foreach ($obj in $appObject.IdentifierUris)
    {
        $principalNames += $obj
    }

    foreach ($obj in $appObject.ServicePrincipalNames)
    {
        $principalNames += $obj
    }

    foreach ($obj in $appObject.AlternativeNames)
    {
        $principalNames += $obj
    }

    return $principalNames
}

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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_AADObjectsContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "aadobjectsexports"
}

# Application,ServicePrincipal,User,Group
$aadObjectsFilter = Get-AutomationVariable -Name  "AzureOptimization_AADObjectsFilter" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($aadObjectsFilter))
{
    $aadObjectsFilter = "Application,ServicePrincipal"
}

$groupFilterVariable = Get-AutomationVariable -Name  "AzureOptimization_AADObjectsGroupFilter" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($groupFilter) -and -not([string]::IsNullOrEmpty($groupFilterVariable)))
{
    $groupFilter = $groupFilterVariable
}

$userFilterVariable = Get-AutomationVariable -Name  "AzureOptimization_AADObjectsUserFilter" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($userFilter) -and -not([string]::IsNullOrEmpty($userFilterVariable)))
{
    $userFilter = $userFilterVariable
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

#workaround for https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/888
$localPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
if (-not(get-item "$localPath\.graph\" -ErrorAction SilentlyContinue))
{
    New-Item -Type Directory "$localPath\.graph"
}

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Groups

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
    
$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

$aadObjectsTypes = $aadObjectsFilter.Split(",")

$fileDate = $datetime.ToString("yyyyMMdd")

if ("Application" -in $aadObjectsTypes)
{
    $aadObjects = @()

    "Getting AAD applications..."
    $apps = Get-MgApplication -All -ExpandProperty Owners -Property Id,AppId,CreatedDateTime,DeletedDateTime,DisplayName,KeyCredentials,PasswordCredentials,Owners,PublisherDomain,Web,IdentifierUris
    "Found $($apps.Count) AAD applications"

    foreach ($app in $apps)
    {
        $owners = $null
        if ($app.Owners.Count -gt 0)
        {
            $owners = ($app.Owners | Where-Object { [string]::IsNullOrEmpty($_.DeletedDateTime) }).Id | ConvertTo-Json -Compress
        }
        $createdDate = $null
        if ($app.CreatedDateTime)
        {
            $createdDate = (Get-Date($app.CreatedDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
        }
        $deletedDate = $null
        if ($app.DeletedDateTime)
        {
            $deletedDate = (Get-Date($app.DeletedDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
        }
        $aadObject = New-Object PSObject -Property @{
            Timestamp = $timestamp
            TenantGuid = $tenantId
            Cloud = $cloudEnvironment
            ObjectId = $app.Id
            ObjectType = "Application"
            ObjectSubType = "N/A"
            DisplayName = $app.DisplayName
            SecurityEnabled = "N/A"
            ApplicationId = $app.AppId
            Keys = (Build-CredObjectWithDates -appObject $app) | ConvertTo-Json -Compress
            PrincipalNames = (Build-PrincipalNames -appObject $app) | ConvertTo-Json -Compress
            Owners = $owners
            CreatedDate = $createdDate
            DeletedDate = $deletedDate
        }
        $aadObjects += $aadObject    
    }   

    $jsonExportPath = "$fileDate-$tenantId-aadobjects-apps.json"
    $csvExportPath = "$fileDate-$tenantId-aadobjects-apps.csv"
    
    $aadObjects | ConvertTo-Json -Depth 3 -Compress | Out-File $jsonExportPath
    "Exported to JSON: $($aadObjects.Count) lines"
    $aadObjectsJson = Get-Content -Path $jsonExportPath | ConvertFrom-Json
    "JSON Import: $($aadObjectsJson.Count) lines"
    $aadObjectsJson | Export-Csv -NoTypeInformation -Path $csvExportPath
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
}

if ("ServicePrincipal" -in $aadObjectsTypes)
{
    $aadObjects = @()

    "Getting AAD service principals..."
    $spns = Get-MgServicePrincipal -All -ExpandProperty Owners -Property Id,AppId,DeletedDateTime,DisplayName,KeyCredentials,PasswordCredentials,Owners,ServicePrincipalNames,ServicePrincipalType,AccountEnabled,AlternativeNames
    "Found $($spns.Count) AAD service principals"
    
    foreach ($spn in $spns)
    {
        $owners = $null
        if ($spn.Owners.Count -gt 0)
        {
            $owners = ($spn.Owners | Where-Object { [string]::IsNullOrEmpty($_.DeletedDateTime) }).Id | ConvertTo-Json -Compress
        }
        $deletedDate = $null
        if ($spn.DeletedDateTime)
        {
            $deletedDate = (Get-Date($spn.DeletedDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
        }
        $aadObject = New-Object PSObject -Property @{
            Timestamp = $timestamp
            TenantGuid = $tenantId
            Cloud = $cloudEnvironment
            ObjectId = $spn.Id
            ObjectType = "ServicePrincipal"
            ObjectSubType = $spn.ServicePrincipalType
            DisplayName = $spn.DisplayName
            SecurityEnabled = $spn.AccountEnabled
            ApplicationId = $spn.AppId
            Keys = (Build-CredObjectWithDates -appObject $spn) | ConvertTo-Json -Compress
            PrincipalNames = (Build-PrincipalNames -appObject $spn) | ConvertTo-Json -Compress
            Owners = $owners
            DeletedDate = $deletedDate
        }
        $aadObjects += $aadObject    
    }

    $jsonExportPath = "$fileDate-$tenantId-aadobjects-spns.json"
    $csvExportPath = "$fileDate-$tenantId-aadobjects-spns.csv"
    
    $aadObjects | ConvertTo-Json -Depth 3 -Compress | Out-File $jsonExportPath
    "Exported to JSON: $($aadObjects.Count) lines"
    $aadObjectsJson = Get-Content -Path $jsonExportPath | ConvertFrom-Json
    "JSON Import: $($aadObjectsJson.Count) lines"
    $aadObjectsJson | Export-Csv -NoTypeInformation -Path $csvExportPath
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
}

if ("User" -in $aadObjectsTypes)
{
    $aadObjects = @()

    if ([string]::IsNullOrEmpty($userFilter))
    {
        "Getting AAD users..."
        $users = Get-MgUser -All -Property Id,AccountEnabled,DisplayName,UserPrincipalName,UserType,CreatedDateTime,DeletedDateTime    
    }
    else
    {
        "Getting AAD users with filter $userFilter..."
        $users = Get-MgUser -Filter $userFilter -All -Property Id,AccountEnabled,DisplayName,UserPrincipalName,UserType,CreatedDateTime,DeletedDateTime            
    }
    "Found $($users.Count) AAD users"
    
    foreach ($user in $users)
    {
        $createdDate = $null
        if ($user.CreatedDateTime)
        {
            $createdDate = (Get-Date($user.CreatedDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
        }
        $deletedDate = $null
        if ($user.DeletedDateTime)
        {
            $deletedDate = (Get-Date($user.DeletedDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
        }
        $aadObject = New-Object PSObject -Property @{
            Timestamp = $timestamp
            TenantGuid = $tenantId
            Cloud = $cloudEnvironment
            ObjectId = $user.Id
            ObjectType = "User"
            ObjectSubType = $user.UserType
            DisplayName = $user.DisplayName
            SecurityEnabled = $user.AccountEnabled
            PrincipalNames = $user.UserPrincipalName
            CreatedDate = $createdDate
            DeletedDate = $deletedDate
        }
        $aadObjects += $aadObject    
    }

    $jsonExportPath = "$fileDate-$tenantId-aadobjects-users.json"
    $csvExportPath = "$fileDate-$tenantId-aadobjects-users.csv"
    
    $aadObjects | Export-Csv -NoTypeInformation -Path $csvExportPath
    "Export to $csvExportPath"
    
    $csvBlobName = $csvExportPath
    $csvProperties = @{"ContentType" = "text/csv"};
    
    Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force        

    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    "[$now] Uploaded $csvBlobName to Blob Storage..."
    
    Remove-Item -Path $csvExportPath -Force
    
    $now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    "[$now] Removed $csvExportPath from local disk..."    
}

if ("Group" -in $aadObjectsTypes)
{
    $aadObjects = @()

    if ([string]::IsNullOrEmpty($groupFilter))
    {
        "Getting AAD groups..."
        $groups = Get-MgGroup -All -ExpandProperty Members -Property Id,SecurityEnabled,DisplayName,Members,CreatedDateTime,DeletedDateTime,GroupTypes
    }
    else
    {
        "Getting AAD groups with filter $groupFilter..."
        $groups = Get-MgGroup -Filter $groupFilter -All -ExpandProperty Members -Property Id,SecurityEnabled,DisplayName,Members,CreatedDateTime,DeletedDateTime,GroupTypes
    }
    "Found $($groups.Count) AAD groups"
    
    foreach ($group in $groups)
    {
        $groupMembers = $null
        if ($group.Members.Count -gt 0)
        {
            $groupMembers = $group.Members.Id | ConvertTo-Json -Compress
        }
        $createdDate = $null
        if ($group.CreatedDateTime)
        {
            $createdDate = (Get-Date($group.CreatedDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
        }
        $deletedDate = $null
        if ($group.DeletedDateTime)
        {
            $deletedDate = (Get-Date($group.DeletedDateTime)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:00.000Z")
        }
        $aadObject = New-Object PSObject -Property @{
            Timestamp = $timestamp
            TenantGuid = $tenantId
            Cloud = $cloudEnvironment
            ObjectId = $group.Id
            ObjectType = "Group"
            ObjectSubType = $group.GroupTypes | ConvertTo-Json -Compress
            DisplayName = $group.DisplayName
            SecurityEnabled = $group.SecurityEnabled
            PrincipalNames = $groupMembers
            CreatedDate = $createdDate
            DeletedDate = $deletedDate
        }
        $aadObjects += $aadObject    
    }

    $jsonExportPath = "$fileDate-$tenantId-aadobjects-groups.json"
    $csvExportPath = "$fileDate-$tenantId-aadobjects-groups.csv"
    
    $aadObjects | ConvertTo-Json -Depth 3 -Compress | Out-File $jsonExportPath
    "Exported to JSON: $($aadObjects.Count) lines"
    $aadObjectsJson = Get-Content -Path $jsonExportPath | ConvertFrom-Json
    "JSON Import: $($aadObjectsJson.Count) lines"
    $aadObjectsJson | Export-Csv -NoTypeInformation -Path $csvExportPath
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
}

"DONE!"