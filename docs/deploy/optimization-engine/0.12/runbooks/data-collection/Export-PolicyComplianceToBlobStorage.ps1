param(
    [Parameter(Mandatory = $false)]
    [string] $TargetSubscription,

    [Parameter(Mandatory = $false)]
    [string] $externalCloudEnvironment,

    [Parameter(Mandatory = $false)]
    [string] $externalTenantId,

    [Parameter(Mandatory = $false)]
    [string] $externalCredentialName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("ARG", "ARM")]
    [string] $PolicyStatesEndpoint = "ARG"
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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_PolicyStatesContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "policystateexports"
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

$allpolicyStates = @()

Write-Output "Getting subscriptions target $TargetSubscription"
if (-not([string]::IsNullOrEmpty($TargetSubscription)))
{
    $subscriptions = $TargetSubscription
    $subscriptionSuffix = $TargetSubscription
}
else
{
    $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" -and $_.SubscriptionPolicies.QuotaId -notlike "AAD*" } | ForEach-Object { "$($_.Id)"}
    $subscriptionSuffix = $cloudSuffix + "all-" + $tenantId
}

Write-Output "Building Policy display names..."

$policyAssignments = @{}
$policyInitiatives = @{}
$policyDefinitions = @{}
$excludedAssignmentScopes = @()
$allInitiatives = @()

if ($PolicyStatesEndpoint -eq "ARG")
{
    $resultsSoFar = 0

    $argQuery = @"
    policyresources
    | where type =~ 'microsoft.authorization/policyassignments'
    | extend displayName = iif(isnotempty(properties.displayName), tostring(properties.displayName), 'N/A')
    | distinct id, displayName
    | order by id asc
"@

    $argAssignmentsTotal = @()

    do
    {
        if ($resultsSoFar -eq 0)
        {
            $argAssignments = Search-AzGraph -Query $argQuery -First $ARGPageSize -UseTenantScope
        }
        else
        {
            $argAssignments = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -UseTenantScope
        }
        if ($argAssignments -and $argAssignments.GetType().Name -eq "PSResourceGraphResponse")
        {
            $argAssignments = $argAssignments.Data
        }
        $resultsCount = $argAssignments.Count
        $resultsSoFar += $resultsCount
        $argAssignmentsTotal += $argAssignments

    } while ($resultsCount -eq $ARGPageSize)

    Write-Output "Building $($argAssignmentsTotal.Count) assignment entries"

    foreach ($assignment in $argAssignmentsTotal)
    {
        $policyAssignments.Add($assignment.id, $assignment.displayName)
    }

    $resultsSoFar = 0

    $argQuery = @"
    policyresources
    | where type =~ 'microsoft.authorization/policysetdefinitions'
    | extend displayName = iif(isnotempty(properties.displayName), tostring(properties.displayName), 'N/A')
    | distinct id, displayName
    | order by id asc
"@

    $argInitiativesTotal = @()

    do
    {
        if ($resultsSoFar -eq 0)
        {
            $argInitiatives = Search-AzGraph -Query $argQuery -First $ARGPageSize -UseTenantScope
        }
        else
        {
            $argInitiatives = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -UseTenantScope
        }
        if ($argInitiatives -and $argInitiatives.GetType().Name -eq "PSResourceGraphResponse")
        {
            $argInitiatives = $argInitiatives.Data
        }
        $resultsCount = $argInitiatives.Count
        $resultsSoFar += $resultsCount
        $argInitiativesTotal += $argInitiatives

    } while ($resultsCount -eq $ARGPageSize)

    Write-Output "Building $($argInitiativesTotal.Count) initiative entries"

    foreach ($initiative in $argInitiativesTotal)
    {
        $policyInitiatives.Add($initiative.id, $initiative.displayName)
    }

    $resultsSoFar = 0

    $argQuery = @"
    policyresources
    | where type =~ 'microsoft.authorization/policydefinitions'
    | extend displayName = iif(isnotempty(properties.displayName), tostring(properties.displayName), 'N/A')
    | distinct id, displayName
    | order by id asc
"@

    $argDefinitionsTotal = @()

    do
    {
        if ($resultsSoFar -eq 0)
        {
            $argDefinitions = Search-AzGraph -Query $argQuery -First $ARGPageSize -UseTenantScope
        }
        else
        {
            $argDefinitions = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -UseTenantScope
        }
        if ($argDefinitions -and $argDefinitions.GetType().Name -eq "PSResourceGraphResponse")
        {
            $argDefinitions = $argDefinitions.Data
        }
        $resultsCount = $argDefinitions.Count
        $resultsSoFar += $resultsCount
        $argDefinitionsTotal += $argDefinitions

    } while ($resultsCount -eq $ARGPageSize)

    Write-Output "Building $($argDefinitionsTotal.Count) definition entries"

    foreach ($definition in $argDefinitionsTotal)
    {
        $policyDefinitions.Add($definition.id, $definition.displayName)
    }
}
else
{
    foreach ($sub in $subscriptions)
    {
        Select-AzSubscription -SubscriptionId $sub | Out-Null
        $assignments = Get-AzPolicyAssignment -IncludeDescendent
        foreach ($assignment in $assignments)
        {
            if (-not($policyAssignments[$assignment.PolicyAssignmentId]))
            {
                $assignmentName = $assignment.Properties.DisplayName
                if([string]::IsNullOrWhiteSpace($assignmentName)) {
                    $policyAssignments.Add($assignment.PolicyAssignmentId, 'N/A')
                }
                else  {
                    $policyAssignments.Add($assignment.PolicyAssignmentId, $assignmentName)
                }
            }
            if ($assignment.Properties.NotScopes -and -not($excludedAssignmentScopes | Where-Object { $_.PolicyAssignmentId -eq $assignment.PolicyAssignmentId }))
            {
                $excludedAssignmentScopes += $assignment
            }
        }

        $initiatives = Get-AzPolicySetDefinition
        foreach ($initiative in $initiatives)
        {
            if (-not($policyInitiatives[$initiative.PolicySetDefinitionId]))
            {
                $setDefinitionName = $initiative.Properties.DisplayName
                if([string]::IsNullOrWhiteSpace($setDefinitionName)) {
                    $policyInitiatives.Add($initiative.PolicySetDefinitionId, 'N/A')
                }
                else  {
                    $policyInitiatives.Add($initiative.PolicySetDefinitionId, $setDefinitionName)
                }
            }
            if (-not($allInitiatives | Where-Object { $_.PolicySetDefinitionId -eq $initiative.PolicySetDefinitionId }))
            {
                $allInitiatives += $initiative
            }
        }

        $definitions = Get-AzPolicyDefinition
        foreach ($definition in $definitions)
        {
            if (-not($policyDefinitions[$definition.PolicyDefinitionId]))
            {
                $definitionName = $initiative.Properties.DisplayName
                if([string]::IsNullOrWhiteSpace($definitionName)) {
                    $policyDefinitions.Add($definition.PolicyDefinitionId, 'N/A')
                }
                else  {
                    $policyDefinitions.Add($definition.PolicyDefinitionId, $definitionName)
                }
            }
        }
    }
}

$policyStatesTotal = @()

Write-Output "Querying for Policy states using $PolicyStatesEndpoint endpoint..."

if ($PolicyStatesEndpoint -eq "ARG")
{
    $resultsSoFar = 0

    $argQuery = @"
    policyresources
    | where type =~ 'microsoft.policyinsights/policystates'
    | extend complianceState = tostring(properties.complianceState)
    | extend complianceReason = tostring(properties.complianceReasonCode)
    | where complianceState != 'Compliant' and complianceReason !contains 'ResourceNotFound'
    | extend effect = tostring(properties.policyDefinitionAction)
    | extend assignmentId = tolower(properties.policyAssignmentId)
    | extend definitionId = tolower(properties.policyDefinitionId)
    | extend definitionReferenceId = tolower(properties.policyDefinitionReferenceId)
    | extend initiativeId = tolower(properties.policySetDefinitionId)
    | extend resourceId = tolower(properties.resourceId)
    | extend resourceType = tostring(properties.resourceType)
    | extend evaluatedOn = todatetime(properties.timestamp)
    | summarize StatesCount = count() by id, tenantId, subscriptionId, resourceGroup, resourceId, resourceType, complianceState, complianceReason, effect, assignmentId, definitionReferenceId, definitionId, initiativeId, evaluatedOn
    | union ( policyresources
        | where type =~ 'microsoft.policyinsights/policystates'
        | extend complianceState = tostring(properties.complianceState)
        | where complianceState == 'Compliant'
        | extend effect = tostring(properties.policyDefinitionAction)
        | extend assignmentId = tolower(properties.policyAssignmentId)
        | extend definitionId = tolower(properties.policyDefinitionId)
        | extend definitionReferenceId = tolower(properties.policyDefinitionReferenceId)
        | extend initiativeId = tolower(properties.policySetDefinitionId)
        | summarize StatesCount = count() by tenantId, subscriptionId, complianceState, effect, assignmentId, definitionReferenceId, definitionId, initiativeId
    )
    | join kind=leftouter (
        resources
        | project resourceId=tolower(id), tags
    ) on resourceId
    | project-away resourceId1
    | order by id asc
"@

    do
    {
        if ($resultsSoFar -eq 0)
        {
            $policyStates = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
        }
        else
        {
            $policyStates = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
        }
        if ($policyStates -and $policyStates.GetType().Name -eq "PSResourceGraphResponse")
        {
            $policyStates = $policyStates.Data
        }
        $resultsCount = $policyStates.Count
        $resultsSoFar += $resultsCount
        $policyStatesTotal += $policyStates

    } while ($resultsCount -eq $ARGPageSize)

    Write-Output "Building $($policyStatesTotal.Count) policyState entries"
}
else
{
    foreach ($sub in $subscriptions)
    {
        Select-AzSubscription -SubscriptionId $sub | Out-Null
        $policyStates = Get-AzPolicyState -All

        $nonCompliantStates = $policyStates | Where-Object { $_.ComplianceState -ne "Compliant" }

        foreach ($policyState in $nonCompliantStates)
        {
            $policyStateObject = New-Object PSObject -Property @{
                tenantId = $tenantId
                subscriptionId = $sub
                resourceGroup = $policyState.ResourceGroup
                resourceId = $policyState.ResourceId
                resourceType = $policyState.ResourceType
                complianceState = $policyState.ComplianceState
                complianceReason = $policyState.AdditionalProperties.complianceReasonCode
                effect = $policyState.PolicyDefinitionAction
                assignmentId = $policyState.PolicyAssignmentId
                initiativeId = $policyState.PolicySetDefinitionId
                definitionId = $policyState.PolicyDefinitionId
                definitionReferenceId = $policyState.PolicyDefinitionReferenceId
                evaluatedOn = $policyState.Timestamp
                StatesCount = 1
            }
            $policyStatesTotal += $policyStateObject
        }

        $compliantStates = $policyStates | Where-Object { $_.ComplianceState -eq "Compliant" } `
            | Group-Object PolicyDefinitionAction, PolicyAssignmentId, PolicyDefinitionId, PolicyDefinitionReferenceId, PolicySetDefinitionId

        foreach ($policyState in $compliantStates)
        {
            $compliantStateProps = $policyState.Name.Split(',')
            $definitionReferenceId = $null
            if ($compliantStateProps[3])
            {
                $definitionReferenceId = $compliantStateProps[3].Trim().ToLower()
            }
            $initiativeId = $null
            if ($compliantStateProps[4])
            {
                $initiativeId = $compliantStateProps[4].Trim().ToLower()
            }

            $policyStateObject = New-Object PSObject -Property @{
                tenantId = $tenantId
                subscriptionId = $sub
                complianceState = "Compliant"
                effect = $compliantStateProps[0]
                assignmentId = $compliantStateProps[1].Trim().ToLower()
                definitionId = $compliantStateProps[2].Trim().ToLower()
                definitionReferenceId = $definitionReferenceId
                initiativeId = $initiativeId
                StatesCount = $policyState.Count
            }
            $policyStatesTotal += $policyStateObject
        }
    }

    Write-Output "Building $($policyStatesTotal.Count) policyState entries"
}

$datetime = (Get-Date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")
$statusDate = $datetime.ToString("yyyy-MM-dd")

foreach ($policyState in $policyStatesTotal)
{
    $resourceGroup = $null
    if ($policyState.resourceGroup)
    {
        $resourceGroup = $policyState.resourceGroup.ToLower()
    }

    if (-not([string]::IsNullOrEmpty($policyState.tags)))
    {
        $tags = $policyState.tags | ConvertTo-Json -Compress
    }
    else
    {
        $tags = $null
    }

    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $policyState.tenantId
        SubscriptionGuid = $policyState.subscriptionId
        ResourceGroupName = $resourceGroup
        ResourceId = $policyState.resourceId
        ResourceType = $policyState.resourceType
        ComplianceState = $policyState.complianceState
        ComplianceReason = $policyState.complianceReason
        Effect = $policyState.effect
        AssignmentId = $policyState.assignmentId
        AssignmentName = $policyAssignments[$policyState.assignmentId]
        InitiativeId = $policyState.initiativeId
        InitiativeName = $policyInitiatives[$policyState.initiativeId]
        DefinitionId = $policyState.definitionId
        DefinitionName = $policyDefinitions[$policyState.definitionId]
        DefinitionReferenceId = $policyState.definitionReferenceId
        EvaluatedOn = $policyState.evaluatedOn
        StatesCount = $policyState.StatesCount
        Tags = $tags
        StatusDate = $statusDate
    }

    $allpolicyStates += $logentry
}

if ($PolicyStatesEndpoint -eq "ARG")
{
    $resultsSoFar = 0

    $argQuery = @"
    policyresources
    | where type =~ 'microsoft.authorization/policyassignments'
    | where array_length(properties.notScopes) > 0
    | mv-expand notScope = properties.notScopes
    | extend policyAssignmentId = tolower(id)
    | extend assignmentPolicyDefinitionId = tolower(properties.policyDefinitionId)
    | join kind=leftouter (
        policyresources
        | where type =~ 'microsoft.authorization/policysetdefinitions'
        | mv-expand policyDefinition = properties.policyDefinitions
        | project policySetDefinitionId = tolower(id), policyDefinitionId = tolower(policyDefinition.policyDefinitionId), policyDefinitionReferenceId = tolower(policyDefinition.policyDefinitionReferenceId)
    ) on `$left.assignmentPolicyDefinitionId == `$right.policySetDefinitionId
    | project policyAssignmentId, notScope, assignmentPolicyDefinitionId, policySetDefinitionId, policyDefinitionId, policyDefinitionReferenceId
    | order by policyDefinitionReferenceId, tostring(notScope)
"@

    do
    {
        if ($resultsSoFar -eq 0)
        {
            $argExcludedAssignments = Search-AzGraph -Query $argQuery -First $ARGPageSize -UseTenantScope
        }
        else
        {
            $argExcludedAssignments = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -UseTenantScope
        }
        if ($argExcludedAssignments -and $argExcludedAssignments.GetType().Name -eq "PSResourceGraphResponse")
        {
            $argExcludedAssignments = $argExcludedAssignments.Data
        }
        $resultsCount = $argExcludedAssignments.Count
        $resultsSoFar += $resultsCount
        $excludedAssignmentScopes += $argExcludedAssignments

    } while ($resultsCount -eq $ARGPageSize)

    Write-Output "Adding excluded scopes from $($excludedAssignmentScopes.Count) assignments"

    foreach ($excludedAssignmentScope in $excludedAssignmentScopes)
    {
        if (-not([String]::IsNullOrEmpty($excludedAssignmentScope.policySetDefinitionId)))
        {
            $initiativeId = $excludedAssignmentScope.policySetDefinitionId
            $initiativeName = $policyInitiatives[$initiativeId]
            $definitionReferenceId = $excludedAssignmentScope.policyDefinitionReferenceId
            $definitionId = $excludedAssignmentScope.policyDefinitionId
        }
        else
        {
            $initiativeId = $null
            $initiativeName = $null
            $definitionReferenceId = $null
            $definitionId = $excludedAssignmentScope.assignmentPolicyDefinitionId
        }

        $logentry = New-Object PSObject -Property @{
            Timestamp = $timestamp
            Cloud = $cloudEnvironment
            TenantGuid = $tenantId
            ResourceId = $excludedAssignmentScope.notScope
            ComplianceState = 'Excluded'
            AssignmentId = $excludedAssignmentScope.policyAssignmentId
            AssignmentName = $policyAssignments[$excludedAssignmentScope.policyAssignmentId]
            InitiativeId = $initiativeId
            InitiativeName = $initiativeName
            DefinitionId = $definitionId
            DefinitionName = $policyDefinitions[$definitionId]
            DefinitionReferenceId = $definitionReferenceId
            StatusDate = $statusDate
        }

        $allpolicyStates += $logentry
    }
}
else
{
    Write-Output "Adding excluded scopes from $($excludedAssignmentScopes.Count) assignments"

    foreach ($excludedAssignment in $excludedAssignmentScopes)
    {
        $excludedIDs = @()
        $excludedInitiative = $allInitiatives | Where-Object { $_.PolicySetDefinitionId -eq $excludedAssignment.Properties.PolicyDefinitionId }
        if ($excludedInitiative)
        {
            $excludedDefinitions = $excludedInitiative.Properties.PolicyDefinitions
            foreach ($excludedDefinition in $excludedDefinitions)
            {
                $excludedIDs += "$($excludedDefinition.policyDefinitionId)|$($excludedDefinition.policyDefinitionReferenceId)"
            }
        }
        else
        {
            $excludedIDs += $excludedAssignment.Properties.PolicyDefinitionId
        }

        foreach ($excludedID in $excludedIDs)
        {
            $excludedIDParts = $excludedID.Split('|')
            $definitionId = $excludedIDParts[0].ToLower()
            $definitionReferenceId = $null
            if (-not([string]::IsNullOrEmpty($excludedIDParts[1])))
            {
                $definitionReferenceId = $excludedIDParts[1].ToLower()
            }

            $initiativeId = $null
            $initiativeName = $null
            if ($excludedInitiative)
            {
                $initiativeId = $excludedInitiative.PolicySetDefinitionId.ToLower()
                $initiativeName = $policyInitiatives[$initiativeId]
            }

            foreach ($notScope in $excludedAssignment.Properties.NotScopes)
            {
                $logentry = New-Object PSObject -Property @{
                    Timestamp = $timestamp
                    Cloud = $cloudEnvironment
                    TenantGuid = $tenantId
                    ResourceId = $notScope.ToLower()
                    ComplianceState = 'Excluded'
                    AssignmentId = $excludedAssignment.PolicyAssignmentId.ToLower()
                    AssignmentName = $policyAssignments[$excludedAssignment.PolicyAssignmentId]
                    InitiativeId = $initiativeId
                    InitiativeName = $initiativeName
                    DefinitionId = $definitionId
                    DefinitionName = $policyDefinitions[$definitionId]
                    DefinitionReferenceId = $definitionReferenceId
                    StatusDate = $statusDate
                }

                $allpolicyStates += $logentry
            }
        }
    }
}

Write-Output "Uploading CSV to Storage"

$today = $datetime.ToString("yyyyMMdd")
$csvExportPath = "$today-policyStates-$subscriptionSuffix.csv"

$allpolicyStates | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

Write-Output "Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

Write-Output "Removed $csvExportPath from local disk..."