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

function Get-TempRoot() {
    $tempRoot = [System.IO.Path]::GetTempPath()
    if ([string]::IsNullOrWhiteSpace($tempRoot)) {
        $tempRoot = Get-OptionalEnv 'AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY'
    }
    if ([string]::IsNullOrWhiteSpace($tempRoot)) {
        $tempRoot = (Get-Location).Path
    }
    return $tempRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
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
            if ($statusCode -and $statusCode -notin @(401, 403, 408, 429, 500, 502, 503, 504)) {
                throw
            }
            if ($attempt -eq $MaxAttempts) {
                throw
            }
            Write-Output "$Label attempt $attempt/$MaxAttempts failed: $($_.Exception.Message)"
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
    return Convert-TokenToString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').Token
}

function Get-SreAccessTokenString() {
    return Convert-TokenToString (Get-AzAccessToken -ResourceUrl 'https://azuresre.dev').Token
}

$subscriptionId = Get-RequiredEnv 'subscriptionId'
$resourceGroupName = Get-RequiredEnv 'resourceGroupName'
$agentName = Get-RequiredEnv 'agentName'
$agentEndpoint = (Get-RequiredEnv 'agentEndpoint').TrimEnd('/')
$recipePackageUri = Get-RequiredEnv 'recipePackageUri'
$kustoConnectorUri = Get-OptionalEnv 'kustoConnectorUri'
$armApiVersion = '2025-05-01-preview'
$armBase = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.App/agents/$agentName"

Write-Output 'Connecting with deployment script managed identity...'
Connect-AzAccount -Identity | Out-Null
Set-AzContext -Subscription $subscriptionId | Out-Null

$tempRoot = Get-TempRoot
$workRoot = Join-Path $tempRoot 'sre-agent-recipe'
$zipPath = Join-Path $tempRoot 'sre-agent-recipe.zip'
Remove-Item $workRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path $workRoot -ItemType Directory -Force | Out-Null

Write-Output "Downloading SRE Agent recipe package: $recipePackageUri"
Invoke-WithRetry -Label 'download recipe package' -Action {
    Invoke-WebRequest -Uri $recipePackageUri -OutFile $zipPath
} | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $workRoot -Force

$extrasPath = Join-Path $workRoot 'extras.json'
if (-not (Test-Path $extrasPath)) {
    throw "Recipe package did not contain extras.json"
}

$extras = Get-Content $extrasPath -Raw | ConvertFrom-Json -Depth 100
Write-Output "Loaded recipe package from $extrasPath"

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
    $tools = @()
    if ($skill.metadata.spec -and $skill.metadata.spec.tools) {
        $tools = Get-Collection $skill.metadata.spec.tools
    }
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
$scheduledTasks = Get-Collection $extras.scheduledTasks
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
