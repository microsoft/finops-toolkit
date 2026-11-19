# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'

function Get-RequiredEnv($Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required environment variable: $Name"
    }
    return $value
}

function Get-OptionalEnv($Name) {
    return [Environment]::GetEnvironmentVariable($Name)
}

function ConvertTo-BodyJson($Value) {
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

function Get-PropertyValue($Object, [string[]]$Names, $Default = '') {
    foreach ($name in $Names) {
        if ($null -ne $Object -and $Object.PSObject.Properties[$name] -and $null -ne $Object.$name) {
            return $Object.$name
        }
    }
    return $Default
}

function Get-HttpStatusCode($Exception) {
    if ($Exception.Response -and $Exception.Response.StatusCode) {
        return [int]$Exception.Response.StatusCode
    }
    return $null
}

function Invoke-WithRetry([scriptblock]$Action, [string]$Label, [int]$MaxAttempts = 5, [int]$DelaySeconds = 15) {
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return & $Action
        }
        catch {
            $statusCode = Get-HttpStatusCode $_.Exception
            if ($statusCode -and $statusCode -notin @(401, 403, 408, 412, 429, 500, 502, 503, 504)) {
                throw
            }
            if ($attempt -eq $MaxAttempts) {
                throw
            }
            Write-Warning "$Label attempt $attempt/$MaxAttempts failed. HTTP status: $statusCode."
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Invoke-JsonRest([string]$Method, [string]$Uri, [string]$Token, $Body = $null) {
    $headers = @{
        Authorization = "Bearer $Token"
        'Content-Type' = 'application/json'
    }
    $parameters = @{
        Method = $Method
        Uri = $Uri
        Headers = $headers
        TimeoutSec = 60
    }
    if ($null -ne $Body) {
        $parameters.Body = ConvertTo-BodyJson $Body
    }
    return Invoke-RestMethod @parameters
}

function Get-KnowledgeSourceName([string]$FileName) {
    $name = [IO.Path]::GetFileName($FileName).ToLowerInvariant() -replace '[^a-z0-9-]+', '-'
    $name = $name -replace '-+', '-'
    return $name.Trim('-')
}

function Get-Collection($Value) {
    if ($null -eq $Value) {
        return @()
    }
    return @($Value)
}

function Convert-TokenToString($Token) {
    if ($Token -is [Security.SecureString]) {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
        try {
            return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
    return [string]$Token
}

function Get-ArmAccessTokenString() {
    if ($env:FTK_LOCAL_EXTRAS) { return Get-CliAccessToken 'https://management.azure.com/' }
    return Convert-TokenToString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').Token
}

function Get-SreAccessTokenString() {
    if ($env:FTK_LOCAL_EXTRAS) { return Get-CliAccessToken 'https://azuresre.dev' }
    return Convert-TokenToString (Get-AzAccessToken -ResourceUrl 'https://azuresre.dev').Token
}

function Get-CliAccessToken([string]$Resource) {
    $token = az account get-access-token --subscription $subscriptionId --resource $Resource --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or -not $token) { throw "Unable to acquire a token for $Resource." }
    return $token.Trim()
}

$subscriptionId = Get-RequiredEnv 'subscriptionId'
$resourceGroupName = Get-RequiredEnv 'resourceGroupName'
$agentName = Get-RequiredEnv 'agentName'
$agentEndpoint = (Get-RequiredEnv 'agentEndpoint').TrimEnd('/')
$mode = Get-RequiredEnv 'costSourceMode'
if ($mode -cnotin @('native', 'hubs')) { throw 'Unsupported cost data source.' }
$kustoConnectorUri = Get-OptionalEnv 'kustoConnectorUri'
if ($mode -eq 'hubs' -and $kustoConnectorUri -cnotmatch '^https://[a-z0-9.-]+\.kusto\.windows\.net/Hub$') {
    throw 'FinOps hubs mode requires an Azure Data Explorer URI ending in /Hub.'
}
if ($mode -eq 'native' -and $kustoConnectorUri) { throw 'Native mode cannot use a Kusto URI.' }
$armApiVersion = '2025-05-01-preview'
$armBase = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.App/agents/$agentName"

$extrasPath = $env:FTK_LOCAL_EXTRAS
if (-not $extrasPath) {
    $recipePackageUri = Get-RequiredEnv 'recipePackageUri'
    $workRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    New-Item -Path $workRoot -ItemType Directory | Out-Null
    $zipPath = Join-Path $workRoot 'recipe.zip'
    Invoke-WithRetry -Label 'download recipe package' -Action {
        Invoke-WebRequest -Uri $recipePackageUri -OutFile $zipPath
    } | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $workRoot
    $extrasPath = Join-Path $workRoot "$mode/extras.json"
    Connect-AzAccount -Identity | Out-Null
    Set-AzContext -Subscription $subscriptionId | Out-Null
}
if (-not (Test-Path $extrasPath)) {
    throw "Recipe package did not contain the $mode profile."
}

$extras = Get-Content $extrasPath -Raw | ConvertFrom-Json -Depth 100
if ($extras.mode -cne $mode) { throw 'Recipe package mode does not match the requested mode.' }

if ([string]::IsNullOrWhiteSpace($kustoConnectorUri)) {
    $extras.connectors = @(
        Get-Collection $extras.connectors | Where-Object {
            $type = Get-PropertyValue $_.properties @('dataConnectorType', 'type')
            $type -ine 'Kusto'
        }
    )
}
else {
    foreach ($connector in Get-Collection $extras.connectors) {
        $type = Get-PropertyValue $connector.properties @('dataConnectorType', 'type')
        if ($type -ieq 'Kusto') {
            $connector.properties.dataSource = $kustoConnectorUri
            if (-not $connector.properties.PSObject.Properties['identity']) {
                $connector.properties | Add-Member -MemberType NoteProperty -Name identity -Value 'system'
            }
        }
    }
}

function Invoke-ArmPutConnector([string]$Name, $Body) {
    $uri = "$armBase/connectors/$Name`?api-version=$armApiVersion"
    Invoke-WithRetry -Label "ARM PUT connector $Name" -Action {
        Invoke-JsonRest -Method PUT -Uri $uri -Token (Get-ArmAccessTokenString) -Body $Body
    } | Out-Null
    Write-Output "  ARM PUT connectors/${Name}: ok"
}

function Invoke-SreApi([string]$Method, [string]$Path, $Body = $null) {
    $uri = "$agentEndpoint$Path"
    return Invoke-WithRetry -Label "$Method $Path" -MaxAttempts 21 -DelaySeconds 30 -Action {
        Invoke-JsonRest -Method $Method -Uri $uri -Token (Get-SreAccessTokenString) -Body $Body
    }
}

function Set-ToolPermissions($Permissions) {
    $uri = "$agentEndpoint/api/v2/agent/settings/global"
    Invoke-WithRetry -Label 'configure tool permissions' -Action {
        $headers = @{ Authorization = "Bearer $(Get-SreAccessTokenString)" }
        $response = Invoke-WebRequest -Uri $uri -Headers $headers -TimeoutSec 30
        $etag = [string]($response.Headers['ETag'] | Select-Object -First 1)
        if (-not $etag) { $etag = '*' }
        $settings = if ($response.Content) { $response.Content | ConvertFrom-Json -AsHashtable } else { @{} }
        $settings['permissions'] = $Permissions
        $headers['If-Match'] = $etag
        Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -ContentType 'application/json' `
            -Body (ConvertTo-BodyJson $settings) -TimeoutSec 30 | Out-Null
    }
}

function Set-ManagedConnector($Spec) {
    $name = [uri]::EscapeDataString($Spec.connectionName)
    $base = '/api/v2/connectorV2'
    try { $connection = Invoke-SreApi -Method GET -Path "$base/connections/$name" }
    catch {
        if ((Get-HttpStatusCode $_.Exception) -ne 404) { throw }
        $connection = $null
    }
    if (-not $connection) {
        Invoke-SreApi -Method PUT -Path "$base/connections/$name" -Body @{
            displayName = $Spec.displayName
            connectorName = $Spec.apiName
        } | Out-Null
    }
    elseif ($connection.properties.connectorName -ne $Spec.apiName) {
        throw "Existing connection $name isn't a $($Spec.apiName) connector. No change made."
    }
    Invoke-SreApi -Method PUT -Path "$base/connections/$name/accessPolicies/$name-policy" | Out-Null
    Invoke-SreApi -Method PUT -Path "$base/mcpservers/$name" -Body @{
        properties = @{
            description = $Spec.displayName
            connectors = @(@{ name = $Spec.apiName; connectionName = $Spec.connectionName; operations = @($Spec.operations) })
        }
    } | Out-Null
    $binding = Invoke-SreApi -Method GET -Path "$base/mcpservers/$name"
    $operations = @($binding.properties.connectors | Where-Object { $_.connectionName -eq $Spec.connectionName } |
        ForEach-Object { $_.operations.name })
    foreach ($operation in $Spec.operations) {
        if ($operation.name -notin $operations) { throw "Missing Teams operation: $($operation.name)" }
    }
    Write-Output "Teams connector provisioned. Verify interactive OAuth in the Azure SRE Agent portal."
}

function Invoke-ExtendedPut([string]$Kind, [string]$Name, [string]$Type, $Properties) {
    $encodedName = [Uri]::EscapeDataString($Name)
    $body = @{
        name = $Name
        type = $Type
        tags = @()
        properties = $Properties
    }
    Invoke-SreApi -Method PUT -Path "/api/v2/extendedAgent/$Kind/$encodedName" -Body $body | Out-Null
    Write-Output "  PUT $Kind/${Name}: ok"
}

Write-Output 'Step 1/7: Applying connectors...'
foreach ($connector in Get-Collection $extras.connectors) {
    $name = [string]$connector.name
    $properties = $connector.properties
    if (-not $properties.PSObject.Properties['identity']) {
        $properties | Add-Member -MemberType NoteProperty -Name identity -Value 'system'
    }
    Invoke-ArmPutConnector -Name $name -Body @{ properties = $properties }
}
Set-ToolPermissions $extras.toolPermissions
Invoke-SreApi -Method PUT -Path '/api/v2/agent/customInstructions' -Body @{ instructions = $extras.customInstructions } | Out-Null
foreach ($connector in Get-Collection $extras.connectorV2) {
    Set-ManagedConnector $connector.spec
}

Write-Output 'Step 2/7: Configuring built-in tools...'
$overrides = Get-Collection $extras.builtInTools.overrides
if ($overrides.Count -gt 0) {
    $body = @{
        overrides = @($overrides | ForEach-Object {
            @{
                name = $_.name
                enabled = [bool]$_.enabled
            }
        })
    }
    Invoke-SreApi -Method POST -Path '/api/v2/agent/tools/configure' -Body $body | Out-Null
    Write-Output "  built-in tools configured: $($overrides.Count) overrides"
}

Write-Output 'Step 3/7: Uploading knowledge sources...'
foreach ($item in Get-Collection $extras.knowledgeItems) {
    $sourceName = Get-KnowledgeSourceName ([string]$item.name)
    $bytes = [Text.Encoding]::UTF8.GetBytes([string]$item.content)
    $body = @{
        properties = @{
            dataConnectorType = 'KnowledgeFile'
            dataSource = $sourceName
            extendedProperties = @{
                displayName = [string]$item.name
                fileName = [string]$item.name
                fileContent = [Convert]::ToBase64String($bytes)
                contentType = [string](Get-PropertyValue $item @('contentType') 'application/octet-stream')
            }
        }
    }
    Invoke-ArmPutConnector -Name $sourceName -Body $body
    Start-Sleep -Seconds 5
}

Write-Output 'Step 4/7: Applying tools...'
foreach ($tool in Get-Collection $extras.tools) {
    $name = [string]$tool.metadata.name
    $properties = $tool.spec
    if ($properties.type -eq 'PythonTool') {
        $properties.type = 'PythonFunctionTool'
    }
    Invoke-ExtendedPut -Kind 'tools' -Name $name -Type 'ExtendedAgentTool' -Properties $properties
}

Write-Output 'Step 5/7: Applying skills...'
foreach ($skill in Get-Collection $extras.skills) {
    $name = [string]$skill.metadata.name
    $tools = @(Get-Collection $skill.metadata.spec.tools)
    $properties = @{
        name = $name
        description = [string](Get-PropertyValue $skill.metadata @('description'))
        tools = $tools
        skillContent = [string](Get-PropertyValue $skill @('skillContent'))
        additionalFiles = @()
    }
    Invoke-ExtendedPut -Kind 'skills' -Name $name -Type 'Skill' -Properties $properties
}

Write-Output 'Step 6/7: Applying subagents...'
foreach ($subagent in Get-Collection $extras.subagents) {
    $name = [string]$subagent.metadata.name
    Invoke-ExtendedPut -Kind 'agents' -Name $name -Type 'ExtendedAgent' -Properties $subagent.spec
}

Write-Output 'Step 7/7: Applying scheduled tasks...'
$scheduledTasks = @(Get-Collection $extras.scheduledTasks)
if ($scheduledTasks.Count -gt 0) {
    $existing = Invoke-SreApi -Method GET -Path '/api/v1/scheduledtasks'
    foreach ($task in $scheduledTasks) {
        $name = [string]$task.metadata.name
        foreach ($match in (Get-Collection $existing | Where-Object { $_.name -eq $name })) {
            if ($match.id) {
                Invoke-SreApi -Method DELETE -Path "/api/v1/scheduledtasks/$($match.id)" | Out-Null
                Write-Output "  deleted existing scheduledtasks/$name"
            }
        }
    }

    foreach ($task in $scheduledTasks) {
        $name = [string]$task.metadata.name
        $spec = $task.spec
        $properties = @{
            name = [string](Get-PropertyValue $spec @('name') $name)
            description = [string](Get-PropertyValue $spec @('description'))
            cronExpression = [string](Get-PropertyValue $spec @('schedule', 'cronExpression', 'cron_expression'))
            agentPrompt = [string](Get-PropertyValue $spec @('prompt', 'agentPrompt', 'agent_prompt'))
            agentMode = [string](Get-PropertyValue $spec @('mode', 'agentMode', 'agent_mode') 'Review')
            isEnabled = [bool](Get-PropertyValue $spec @('enabled') $true)
            agent = [string](Get-PropertyValue $spec @('agent'))
        }
        Invoke-ExtendedPut -Kind 'scheduledtasks' -Name $name -Type 'ScheduledTask' -Properties $properties
    }
}

Write-Output 'SRE Agent extras complete.'

foreach ($connector in Get-Collection $extras.connectors) {
    $name = [uri]::EscapeDataString($connector.name)
    $actual = Invoke-SreApi -Method GET -Path "/api/v2/extendedAgent/connectors/$name"
    if ($actual.name -ne $connector.name) { throw "Connector verification failed: $name" }
}
foreach ($group in @(
    @{ route = 'tools'; entries = $extras.tools },
    @{ route = 'skills'; entries = $extras.skills },
    @{ route = 'agents'; entries = $extras.subagents }
)) {
    $response = Invoke-SreApi -Method GET -Path "/api/v2/extendedAgent/$($group.route)"
    $names = @($response.value | ForEach-Object { $_.name })
    if ($response.nextLink) {
        foreach ($entry in $group.entries | Where-Object { $_.metadata.name -notin $names }) {
            $encoded = [uri]::EscapeDataString($entry.metadata.name)
            $actual = Invoke-SreApi -Method GET -Path "/api/v2/extendedAgent/$($group.route)/$encoded"
            $names += $actual.name
        }
    }
    foreach ($entry in $group.entries) {
        if ($entry.metadata.name -notin $names) { throw "Missing $($group.route)/$($entry.metadata.name)." }
    }
}
$actualSchedules = @(Invoke-SreApi -Method GET -Path '/api/v1/scheduledtasks')
foreach ($task in $scheduledTasks) {
    $matches = @($actualSchedules | Where-Object { $_.name -eq $task.metadata.name })
    if ($matches.Count -ne 1) { throw "Expected exactly one schedule named $($task.metadata.name)." }
}
$settings = Invoke-SreApi -Method GET -Path '/api/v2/agent/settings/global'
foreach ($tool in $extras.toolPermissions.deny) {
    if ($tool -notin $settings.permissions.deny) { throw "Missing deny policy for $tool." }
}
$requiredRuntimeTools = @('azure-resource-manager-mcp_query_costs', 'azure-resource-manager-mcp_list_benefit_utilization')
if ($mode -eq 'hubs') { $requiredRuntimeTools += @('monthly-cost-trend', 'hub-query-probe', 'hub-cost-query-proof') }
# A cold agent can finish applying configuration before the MCP catalog is populated.
Invoke-WithRetry -Label 'verify runtime tool registration' -MaxAttempts 25 -DelaySeconds 15 -Action {
    $catalog = Invoke-SreApi -Method GET -Path '/api/v2/agent/tools'
    $enabledTools = @($catalog.data | Where-Object { $_.enabled } | ForEach-Object { $_.name })
    $missing = @($requiredRuntimeTools | Where-Object { $_ -notin $enabledTools })
    if ($missing.Count) { throw "Tools aren't enabled in the runtime catalog: $($missing -join ', ')." }
}
Write-Output 'Verified connectors, enabled runtime tools, skills, subagents, and schedules. Runtime data access still needs a smoke test.'
