# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Builds Grafana dashboards from the FinOps hub Data Explorer dashboard.

    .DESCRIPTION
    Creates one dashboard per analytical page and an overview with drill-through links.
    Reuses the source queries and parameters. Excludes text-only pages and cluster management queries.
    Writes Grafana JSON to the grafana directory. Specify ResourceGroupId to also
    create an Azure Monitor deployment template for that resource group.
    Does not deploy resources or change the source dashboard.

    .PARAMETER DestDir
    Directory containing the build copy of dashboard.json.

    .PARAMETER ResourceGroupId
    Optional target resource group ID. Required to generate deploy.json with native dashboard links.

    .PARAMETER ClusterUri
    Query URI of the existing Data Explorer cluster. Required with ResourceGroupId.

    .PARAMETER Database
    Database containing the FinOps hub query functions. Default = Hub.

    .PARAMETER Location
    Region for the Azure Monitor dashboards. Defaults to the target resource group's region.

    .EXAMPLE
    ./Build-HubGrafanaDashboards.ps1 -DestDir ./release/finops-hub
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $DestDir,

    [ValidatePattern('^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+$')]
    [string] $ResourceGroupId,

    [string] $ClusterUri = '__HUB_CLUSTER_URI__',

    [ValidateNotNullOrEmpty()]
    [string] $Database = 'Hub',

    [string] $Location = '[resourceGroup().location]'
)

$ErrorActionPreference = 'Stop'
if ($ResourceGroupId -and $ClusterUri -notmatch '^https://[^/]+/?$')
{
    throw 'Specify the HTTPS cluster query URI when generating an Azure deployment template.'
}
$sourceText = Get-Content (Join-Path $DestDir 'dashboard.json') -Raw
$sourceText = $sourceText.Replace('$$ftkver$$', (& "$PSScriptRoot/Get-Version.ps1"))
$sourceText = $sourceText.Replace('$$build-date$$', (Get-Date -Format 'yyyy-MM-dd'))
$sourceText = $sourceText.Replace('$$build-month$$', (Get-Date -Format 'MMMM yyyy'))
$source = $sourceText | ConvertFrom-Json -AsHashtable
$outputDir = Join-Path $DestDir 'grafana'
$null = New-Item -Path $outputDir -ItemType Directory -Force
$queries = @{}
$bases = @{}
$pages = [ordered]@{}
$tileIds = @{}
$tilesById = @{}
$source.queries | ForEach-Object { $queries[$_.id] = $_ }
$source.baseQueries | ForEach-Object { $bases[$_.variableName] = $_.queryId }

foreach ($page in $source.pages)
{
    $title = $page.name -replace '^- ', ''
    if ($title -cmatch '^[A-Z]+$') { $title = $title.Substring(0, 1) + $title.Substring(1).ToLowerInvariant() }
    $slug = ($title.ToLowerInvariant() -replace '\s*\+\s*', '-' -replace '[^a-z0-9]+', '-').Trim('-')
    $pages[$page.id] = @{ title = $title; uid = "ftk-hub-$slug" }
}
foreach ($tile in $source.tiles)
{
    $tilesById[$tile.id] = $tile
    $tileIds[$tile.id] = $tileIds.Count + 1
}
$retainedTiles = @($source.tiles | Where-Object {
        -not $_.queryRef -or $queries[$_.queryRef.queryId].text -notmatch '(?im)^\s*\.show\s+cluster\b'
    })
$analyticalPageIds = @($retainedTiles | Where-Object queryRef | Select-Object -ExpandProperty pageId -Unique)
foreach ($pageId in @($pages.Keys))
{
    if ($pageId -notin $analyticalPageIds)
    {
        $obsoleteFile = Join-Path $outputDir "$($pages[$pageId].uid).json"
        if (Test-Path $obsoleteFile) { Remove-Item -LiteralPath $obsoleteFile }
        $pages.Remove($pageId)
    }
}
$retainedTiles = @($retainedTiles | Where-Object { $pages.Contains($_.pageId) })
$datasource = @{ type = 'grafana-azure-data-explorer-datasource'; uid = '${adx_ds}' }
$parameterBindings = @'
let numberOfMonths = toint(${numberOfMonths:doublequote});
let numberOfDays = toint(${numberOfDays:doublequote});
let maxGroupCount = toint(${maxGroupCount:doublequote});
let selectedBillingCurrency = tostring(${selectedBillingCurrency:doublequote});
let _validParameters = assert(
    isnotnull(numberOfMonths) and todouble(${numberOfMonths:doublequote}) == numberOfMonths
    and isnotnull(numberOfDays) and todouble(${numberOfDays:doublequote}) == numberOfDays
    and isnotnull(maxGroupCount) and todouble(${maxGroupCount:doublequote}) == maxGroupCount,
    "Monthly trend, daily trend, and max group count must be integers.");
let _checkParameters = toscalar(print _validParameters);
'@

function Get-QueryDependency([string] $QueryId, [System.Collections.Generic.HashSet[string]] $Seen)
{
    if (-not $queries.ContainsKey($QueryId)) { throw "Source query not found: $QueryId" }
    foreach ($name in $queries[$QueryId].usedVariables)
    {
        if ($bases.ContainsKey($name) -and $Seen.Add($name))
        {
            Get-QueryDependency $bases[$name] $Seen
            "let $name = (`n$($queries[$bases[$name]].text)`n);"
        }
    }
}

function Get-AdxTarget([string] $Query, [string] $Format = 'table')
{
    @{
        refId = 'A'; datasource = $datasource; query = $Query
        clusterUri = '${cluster}'; database = '${database}'
        queryType = 'KQL'; querySource = 'raw'; rawMode = $true; resultFormat = $Format
    }
}

function Get-PageUrl([string] $Uid, [int] $PanelId = 0)
{
    $names = @('adx_ds', 'cluster', 'database') + @($source.parameters.variableName)
    $queryParameters = foreach ($name in $names) { 'var-' + $name + '=${' + $name + ':percentencode}' }
    $url = "/d/${Uid}?" + ($queryParameters -join '&')
    if ($PanelId) { $url += "&viewPanel=$PanelId" }
    $url
}

function Convert-Markdown([string] $Text)
{
    [regex]::Replace($Text, '\]\((#|\?tile=)([0-9a-f-]{36})\)', {
            param($match)
            $id = $match.Groups[2].Value
            if ($match.Groups[1].Value -eq '#')
            {
                if (-not $pages.Contains($id)) { throw "Unknown source page link: $id" }
                return '](' + (Get-PageUrl $pages[$id].uid) + ')'
            }
            if (-not $tilesById.ContainsKey($id)) { throw "Unknown source tile link: $id" }
            return '](' + (Get-PageUrl $pages[$tilesById[$id].pageId].uid $tileIds[$id]) + ')'
        })
}

$variables = @(
    @{ name = 'adx_ds'; label = 'Data source'; type = 'datasource'; query = $datasource.type; current = @{}; refresh = 1; hide = 0 }
    @{ name = 'cluster'; label = 'Cluster URI'; type = 'textbox'; query = $ClusterUri; current = @{ text = $ClusterUri; value = $ClusterUri }; hide = 0 }
    @{ name = 'database'; label = 'Database'; type = 'textbox'; query = $Database; current = @{ text = $Database; value = $Database }; hide = 0 }
)
foreach ($parameter in $source.parameters)
{
    $variable = @{
        name = $parameter.variableName; label = $parameter.displayName; description = $parameter.description
        hide = 0; skipUrlSync = $false; multi = $false; includeAll = $false; options = @()
    }
    if ($parameter.dataSource)
    {
        $query = $queries[$parameter.dataSource.queryRef.queryId].text
        $query += "`n| project text = tostring($($parameter.dataSource.columns.label)), value = tostring($($parameter.dataSource.columns.value))"
        $variable.type = 'query'
        $variable.datasource = $datasource
        $variable.query = Get-AdxTarget $query
        $variable.refresh = 1
        $variable.sort = 0
        $variable.current = @{}
    }
    else
    {
        $variable.type = 'textbox'
        $variable.query = [string]$parameter.defaultValue.value
        $variable.current = @{ text = $variable.query; value = $variable.query }
    }
    $variables += $variable
}

function Get-HubDashboard([string] $Uid, [string] $Title)
{
    @{
        uid = $Uid; title = "FinOps hubs - $Title"; schemaVersion = 42; version = 1; editable = $true
        tags = @('FinOps toolkit', 'FinOps hubs'); timezone = 'utc'; refresh = '30m'
        time = @{ from = 'now-1y'; to = 'now' }; timepicker = @{ hidden = $true }
        description = 'Uses source billing and calendar windows, not the dashboard time picker. Currency All does not convert currencies.'
        templating = @{ list = $variables }
        links = @(
            @{ title = 'Overview'; type = 'link'; url = (Get-PageUrl 'ftk-hub-overview'); icon = 'dashboard'; targetBlank = $false }
        )
        panels = @()
    }
}

function Get-HubPanel([hashtable] $Tile)
{
    $layout = $Tile.layout
    $x = [int][math]::Floor($layout.x * 24 / 22)
    $panel = @{
        id = $tileIds[$Tile.id]; title = $Tile.title
        gridPos = @{
            x = $x; y = [int][math]::Floor($layout.y * 1.5)
            w = [int][math]::Floor(($layout.x + $layout.width) * 24 / 22) - $x
            h = [int][math]::Floor(($layout.y + $layout.height) * 1.5) - [int][math]::Floor($layout.y * 1.5)
        }
        description = "Source tile: $($Tile.id)"
        fieldConfig = @{ defaults = @{ color = @{ mode = 'palette-classic' }; noValue = 'No data'; unit = 'short' }; overrides = @() }
        options = @{}
    }
    if ($Tile.visualType -eq 'markdownCard')
    {
        $panel.type = 'text'
        $panel.title = ''
        $panel.options = @{ mode = 'markdown'; content = (Convert-Markdown $Tile.markdownText) }
        if ($Tile.markdownText -match '^## ([^\r\n]+)\s*$')
        {
            $panel.type = 'row'; $panel.title = $Matches[1]; $panel.collapsed = $false; $panel.panels = @()
            $panel.gridPos.h = 1
        }
        return $panel
    }

    $queryId = $Tile.queryRef.queryId
    $query = $parameterBindings + "`n" + ((Get-QueryDependency $queryId ([System.Collections.Generic.HashSet[string]]::new())) -join "`n")
    $query += "`n$($queries[$queryId].text)`n| where _checkParameters"
    $panel.datasource = $datasource
    $format = 'table'
    $legend = @{ displayMode = 'list'; placement = 'bottom'; showLegend = -not $Tile.visualOptions.hideLegend; calcs = @() }
    $tooltip = @{ mode = 'multi'; sort = 'desc' }
    switch ($Tile.visualType)
    {
        'table'
        {
            $panel.type = 'table'
            $panel.options = @{ showHeader = $true; cellHeight = 'sm'; footer = @{ show = $false } }
            break
        }
        { $_ -in 'multistat', 'card' }
        {
            $panel.type = 'stat'
            $label = 'Label'
            $value = 'Value'
            if ($queryId -eq '152f2041-bbc1-41e4-b155-271b2e0cf6e9') { $label = 'Type'; $value = 'Cost' }
            if ($queryId -in 'f2cecbb0-13f8-4642-afa4-bbcc0558f777', '5d63e04d-1a11-4307-96f1-ebbf68e09be0', 'e8b343dc-7430-4487-8d44-ef48ac454f2d') { $value = 'Count' }
            $query += "`n| project $label, $value"
            $panel.transformations = @(@{ id = 'rowsToFields'; options = @{ mappings = @(
                            @{ fieldName = $label; handlerKey = 'field.name' }
                            @{ fieldName = $value; handlerKey = 'field.value' }
                        ) } })
            $panel.options = @{
                colorMode = 'none'; graphMode = 'none'; textMode = 'auto'; wideLayout = $true
                orientation = 'auto'; justifyMode = 'auto'
                reduceOptions = @{ values = $false; calcs = @('lastNotNull'); fields = '/.*/' }
            }
            if ($queryId -eq '8de47213-8327-44da-9d1b-8ba5de74c44a')
            {
                $panel.title = 'Hub settings'
                $panel.description += '. The source query can return empty labels and values when the hub version is not numeric.'
            }
            break
        }
        'pie'
        {
            $panel.type = 'piechart'
            $panel.options = @{
                pieType = 'pie'; displayLabels = @('name', 'percent'); legend = $legend; tooltip = $tooltip
                reduceOptions = @{ values = $true; calcs = @('lastNotNull'); fields = '/^Savings$/' }
            }
            break
        }
        'bar'
        {
            $panel.type = 'barchart'
            $panel.options = @{ orientation = 'horizontal'; stacking = 'none'; showValue = 'auto'; legend = $legend; tooltip = $tooltip }
            if ($queryId -in '5ff29428-de83-4a2c-8f86-d8beebe68750', 'f5f240a8-a818-4f27-bdfb-e96fcfe433bd')
            {
                $panel.transformations = @(@{ id = 'groupingToMatrix'; options = @{ rowField = 'Label'; columnField = 'Period'; valueField = 'Value' } })
            }
            break
        }
        { $queryId -in 'd5ed469a-45ea-49a2-b305-b841050213cf', '9e41a624-d5f9-40c6-b47f-fef4b50ec3dd' }
        {
            $panel.type = 'barchart'
            $value = if ($queryId -eq 'd5ed469a-45ea-49a2-b305-b841050213cf') { 'EffectiveCostRunningTotal' } else { 'EffectiveCost' }
            $query += "`n| order by Day asc`n| extend Day = tostring(Day)"
            $panel.transformations = @(@{ id = 'groupingToMatrix'; options = @{ rowField = 'Day'; columnField = 'Month'; valueField = $value } })
            $panel.options = @{ orientation = 'vertical'; stacking = 'none'; showValue = 'never'; legend = $legend; tooltip = $tooltip }
            break
        }
        'timechart'
        {
            # XY time axes fit the returned data, including the entire forecast horizon.
            $panel.type = 'xychart'
            $query += @'

| project-rename Timestamp = ChargePeriodStart
| mv-expand Timestamp to typeof(datetime), EffectiveCost to typeof(real), Forecast to typeof(real)
| project Timestamp, EffectiveCost, Forecast
| order by Timestamp asc
'@
            $panel.title = 'Forecast (next ${numberOfDays} days)'
            $panel.options = @{ mapping = 'auto'; series = @(@{ x = @{ matcher = @{ id = 'byName'; options = 'Timestamp' } } }); legend = $legend; tooltip = @{ mode = 'single' } }
            $panel.fieldConfig.defaults.custom = @{ show = 'lines'; lineWidth = 2; pointSize = @{ fixed = 3 }; axisPlacement = 'auto' }
            break
        }
        { $_ -in 'column', 'stackedcolumn', 'area', 'stackedarea' }
        {
            $panel.type = 'timeseries'
            $format = 'time_series'
            $timeColumn = if ($queryId -in 'bc24e050-f2b9-4b4a-a08d-69fc4a4bb95e', '0d91ea4a-c81d-4a21-b708-b6af37be1eec', '290e7eab-8159-4338-8531-85e2718cedb1') { 'BillingPeriodStart' } else { 'ChargePeriodStart' }
            $query += "`n| order by $timeColumn asc"
            $panel.timeFrom = 'now-${numberOfMonths}M/M'
            if ($queries[$queryId].usedVariables -contains 'CostsByDay') { $panel.timeFrom = 'now-${numberOfDays}d-1d' }
            if ($Tile.visualType -in 'area', 'stackedarea' -or $Tile.title -like '3-month*') { $panel.timeFrom = 'now-3M/M' }
            $panel.hideTimeOverride = $true
            $panel.options = @{ legend = $legend; tooltip = $tooltip }
            $panel.fieldConfig.defaults.custom = @{
                drawStyle = $(if ($Tile.visualType -like '*column') { 'bars' } else { 'line' })
                lineWidth = 1; fillOpacity = 70; showPoints = 'never'
                stacking = @{ mode = $(if ($Tile.visualType -like 'stacked*') { 'normal' } else { 'none' }); group = 'A' }
                axisPlacement = 'auto'
            }
            if ($queryId -in '290e7eab-8159-4338-8531-85e2718cedb1', '1d9c166d-22b6-48fd-9a90-9f983083ecc7')
            {
                $panel.fieldConfig.overrides += @{ matcher = @{ id = 'byName'; options = 'Change' }; properties = @(
                        @{ id = 'unit'; value = 'percentunit' }; @{ id = 'custom.axisPlacement'; value = 'right' }
                    ) }
            }
            break
        }
        default { throw "Unsupported source visual: $($Tile.visualType) ($($Tile.id))" }
    }
    $panel.targets = @(Get-AdxTarget $query $format)
    $panel
}

$dashboards = @()
$panelsByTile = @{}
foreach ($pageId in $pages.Keys)
{
    $page = $pages[$pageId]
    $dashboard = Get-HubDashboard $page.uid $page.title
    $pageTiles = @($retainedTiles | Where-Object pageId -EQ $pageId | Sort-Object { $_.layout.y }, { $_.layout.x })
    # Remove empty rows left by the excluded extent panels.
    $occupied = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($tile in $pageTiles)
    {
        for ($y = $tile.layout.y; $y -lt $tile.layout.y + $tile.layout.height; $y++) { $null = $occupied.Add($y) }
    }
    foreach ($tile in $pageTiles)
    {
        $panel = Get-HubPanel $tile
        $compressedY = @($occupied | Where-Object { $_ -lt $tile.layout.y }).Count
        $panel.gridPos.y = [int][math]::Floor($compressedY * 1.5)
        if ($panel.type -ne 'row')
        {
            $panel.gridPos.h = [int][math]::Floor(($compressedY + $tile.layout.height) * 1.5) - $panel.gridPos.y
        }
        $dashboard.panels += $panel
        $panelsByTile[$tile.id] = $panel
    }
    if ($page.title -eq 'Licensing + SaaS')
    {
        $dashboard.description += ' The source licensing queries use the monthly lookback, despite their last n days titles.'
    }
    $dashboards += $dashboard
}

$overview = Get-HubDashboard 'ftk-hub-overview' 'Overview'
$overview.panels += @{
    id = 1000; type = 'text'; title = ''; gridPos = @{ x = 0; y = 0; w = 24; h = 3 }
    options = @{ mode = 'markdown'; content = '# FinOps hubs overview' + "`nReview costs, savings, and the forecast. Open a summary for the detailed breakdown. **Currency All combines currencies without conversion.**" }
}
$overview.panels += @{
    id = 1001; type = 'text'; title = 'Detailed dashboards'; gridPos = @{ x = 0; y = 3; w = 24; h = 3 }
    options = @{ mode = 'markdown'; content = (($pages.Values | ForEach-Object { "[$($_.title)]($(Get-PageUrl $_.uid))" }) -join ' &nbsp; | &nbsp; ') }
}
$summaryTiles = @(
    @{ id = '66dcd731-a141-47b2-b36a-53a138cb75f2'; title = 'Cost and savings - this month and last'; x = 0; y = 6; w = 12; h = 10 }
    @{ id = 'e8018da4-7269-4e91-9f32-4bcf390746af'; title = 'Commitment usage - last ${numberOfMonths} months'; x = 12; y = 6; w = 12; h = 10 }
    @{ id = '1ac02a9f-3c12-4828-a4dd-60a0d411f60c'; title = 'Spending comparison - this month and last'; x = 0; y = 16; w = 12; h = 10 }
    @{ id = 'd2e4a321-9c2c-411b-8a20-19fd86dab3fe'; title = 'Azure Hybrid Benefit - selected months'; x = 12; y = 16; w = 12; h = 10 }
    @{ id = 'acf2ca3d-9d8f-477f-b259-f3937bf938d4'; title = 'Last month invoicing'; x = 0; y = 26; w = 12; h = 8 }
    @{ id = '05764729-51e4-4048-8cf8-2ac56eb3e643'; title = 'Hub infrastructure cost - last ${numberOfMonths} months'; x = 12; y = 26; w = 12; h = 8 }
)
foreach ($item in $summaryTiles)
{
    $panel = $panelsByTile[$item.id] | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
    if (-not $panel) { throw "Overview source tile not found: $($item.id)" }
    $panel.title = $item.title
    $panel.gridPos = @{ x = $item.x; y = $item.y; w = $item.w; h = $item.h }
    $page = $pages[$tilesById[$item.id].pageId]
    $url = Get-PageUrl $page.uid
    $panel.links = @(@{ title = "Open $($page.title)"; url = $url; targetBlank = $false })
    $panel.fieldConfig.defaults.links = @(@{ title = "Open $($page.title)"; url = $url; targetBlank = $false; oneClick = $true })
    $overview.panels += $panel
}
$forecastTile = $retainedTiles | Where-Object visualType -EQ 'timechart' | Select-Object -First 1
$forecast = $panelsByTile[$forecastTile.id] | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
$forecast.gridPos = @{ x = 0; y = 34; w = 24; h = 10 }
$forecast.links = @(@{ title = 'Open Anomaly management'; url = (Get-PageUrl $pages[$forecastTile.pageId].uid); targetBlank = $false })
$overview.panels += $forecast
$dashboards = @($overview) + $dashboards

$resources = @()
foreach ($dashboard in $dashboards)
{
    $dashboard | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $outputDir "$($dashboard.uid).json") -Encoding utf8
    if ($ResourceGroupId)
    {
        # ARM expression results are limited to 128 KiB; serialize large definitions before deployment.
        $uidPrefix = $ResourceGroupId.TrimStart('/').Replace('/', '~') + '~providers~Microsoft.Dashboard~dashboards~'
        $json = ($dashboard | ConvertTo-Json -Depth 100 -Compress).Replace('/d/ftk-hub-', "/d/${uidPrefix}ftk-hub-")
        $resources += @{
            type = 'Microsoft.Dashboard/dashboards'; apiVersion = '2026-09-01'
            name = $dashboard.uid; location = $Location; properties = @{}
        }
        $resources += @{
            type = 'Microsoft.Dashboard/dashboards/dashboardDefinitions'; apiVersion = '2026-09-01'
            name = "$($dashboard.uid)/default"
            dependsOn = @("[resourceId('Microsoft.Dashboard/dashboards', '$($dashboard.uid)')]")
            properties = @{ serializedData = $json }
        }
    }
}
if ($ResourceGroupId)
{
    $template = @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
        contentVersion = '1.0.0.0'; resources = $resources
        outputs = @{
            overviewResourceId = @{ type = 'string'; value = "[resourceId('Microsoft.Dashboard/dashboards', 'ftk-hub-overview')]" }
        }
    }
    $template | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $outputDir 'deploy.json') -Encoding utf8
}
elseif (Test-Path (Join-Path $outputDir 'deploy.json'))
{
    Remove-Item -LiteralPath (Join-Path $outputDir 'deploy.json')
}
Write-Verbose "Created $($dashboards.Count) Grafana dashboards in $outputDir."
