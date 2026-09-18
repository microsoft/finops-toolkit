# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'FinOps hub Grafana dashboards' {
    It 'Builds analytical pages and an overview with complete query coverage and valid navigation' {
        $root = Resolve-Path "$PSScriptRoot/../../../.."
        Copy-Item "$root/src/templates/finops-hub/dashboard.json" $TestDrive
        $null = New-Item "$TestDrive/grafana" -ItemType Directory
        foreach ($name in 'about', 'understand', 'optimize', 'quantify', 'manage')
        {
            '{}' | Set-Content "$TestDrive/grafana/ftk-hub-$name.json"
        }
        $resourceGroupId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/grafana'
        & "$root/src/scripts/Build-HubGrafanaDashboards.ps1" -DestDir $TestDrive `
            -ResourceGroupId $resourceGroupId -ClusterUri 'https://hub.kusto.windows.net'
        $source = Get-Content "$TestDrive/dashboard.json" -Raw | ConvertFrom-Json -AsHashtable
        $dashboards = @(Get-ChildItem "$TestDrive/grafana/ftk-hub-*.json" | ForEach-Object {
                Get-Content $_ -Raw | ConvertFrom-Json -AsHashtable
            })
        $dashboards.Count | Should -Be 8
        $textOnlyPageIds = @($source.pages | Where-Object { $_.id -notin @($source.tiles | Where-Object queryRef).pageId } | Select-Object -ExpandProperty id)
        $overview = $dashboards | Where-Object uid -EQ 'ftk-hub-overview'
        $detailPanels = @($dashboards | Where-Object uid -NE 'ftk-hub-overview' | ForEach-Object { $_.panels })
        $detailPanels.Count | Should -Be 99
        @($detailPanels | Where-Object targets).Count | Should -Be 71
        foreach ($tile in $source.tiles)
        {
            $query = $source.queries | Where-Object id -EQ $tile.queryRef.queryId
            $panels = @($detailPanels | Where-Object { $_.description -like "Source tile: $($tile.id)*" })
            if ($tile.pageId -in $textOnlyPageIds -or $query.text -match '(?im)^\s*\.show\s+cluster\b')
            {
                $panels.Count | Should -Be 0
            }
            else
            {
                $panels.Count | Should -Be 1
                if ($query) { $panels[0].targets[0].query.Contains($query.text) | Should -BeTrue }
            }
        }
        foreach ($dashboard in $dashboards)
        {
            @($dashboard.panels | Where-Object targets).Count | Should -BeGreaterThan 0
            @($dashboard.panels.id | Select-Object -Unique).Count | Should -Be $dashboard.panels.Count
            foreach ($parameter in $source.parameters | Where-Object dataSource)
            {
                $variable = $dashboard.templating.list | Where-Object name -EQ $parameter.variableName
                $projection = "| project text = tostring($($parameter.dataSource.columns.label)), value = tostring($($parameter.dataSource.columns.value))"
                $variable.query.query.TrimEnd().EndsWith($projection) | Should -BeTrue -Because 'ADX query variables require string text and value fields, not SQL-style __text and __value fields'
            }
            $dashboard.links[0].url | Should -BeLike '/d/ftk-hub-overview?var-adx_ds=*'
            foreach ($name in @('adx_ds', 'cluster', 'database') + @($source.parameters.variableName))
            {
                $dashboard.links[0].url.Contains('var-' + $name + '=${' + $name + ':percentencode}') | Should -BeTrue
            }
            $json = $dashboard | ConvertTo-Json -Depth 100
            $json | Should -Not -Match '\?tile=|\$\$ftkver\$\$|\.show cluster|ftk-hub-(about|understand|optimize|quantify|manage)[?"\\]'
            foreach ($link in [regex]::Matches($json, '/d/(ftk-hub-[a-z-]+)\?([^"\s)]+)'))
            {
                $target = @($dashboards | Where-Object uid -EQ $link.Groups[1].Value)
                $target.Count | Should -Be 1
                if ($link.Groups[2].Value -match '&viewPanel=(\d+)') { $target[0].panels.id | Should -Contain ([int]$Matches[1]) }
            }
            foreach ($panel in $dashboard.panels)
            {
                $a = $panel.gridPos
                ($a.w -gt 0 -and $a.h -gt 0 -and $a.x -ge 0 -and $a.x + $a.w -le 24) | Should -BeTrue
                foreach ($other in $dashboard.panels | Where-Object id -LT $panel.id)
                {
                    $b = $other.gridPos
                    ($a.x -lt $b.x + $b.w -and $b.x -lt $a.x + $a.w -and $a.y -lt $b.y + $b.h -and $b.y -lt $a.y + $a.h) |
                        Should -BeFalse -Because "$($dashboard.uid) panels $($panel.id) and $($other.id) must not overlap"
                }
            }
        }
        foreach ($dashboard in $dashboards | Where-Object uid -NE 'ftk-hub-overview')
        {
            $overview.panels[1].options.content | Should -Match ([regex]::Escape("/d/$($dashboard.uid)?"))
        }
        $template = Get-Content "$TestDrive/grafana/deploy.json" -Raw | ConvertFrom-Json -AsHashtable
        $template.resources.Count | Should -Be 16
        @($template.resources | Where-Object type -EQ 'Microsoft.Dashboard/dashboards').Count | Should -Be 8
        foreach ($definition in $template.resources | Where-Object type -EQ 'Microsoft.Dashboard/dashboards/dashboardDefinitions')
        {
            $deployed = $definition.properties.serializedData | ConvertFrom-Json -AsHashtable
            $deployed.links[0].url.StartsWith('/d/' + $resourceGroupId.TrimStart('/').Replace('/', '~') + '~providers~Microsoft.Dashboard~dashboards~ftk-hub-overview?var-adx_ds=') | Should -BeTrue
        }
        $anomaly = $dashboards | Where-Object uid -EQ 'ftk-hub-anomaly-management'
        @($anomaly.panels | Where-Object type -EQ 'barchart').Count | Should -Be 2
        $forecast = $anomaly.panels | Where-Object type -EQ 'xychart'
        $forecast.targets[0].resultFormat | Should -Be 'table'
        $forecast.targets[0].query | Should -Match 'mv-expand Timestamp to typeof\(datetime\), EffectiveCost to typeof\(real\), Forecast to typeof\(real\)'
        $forecast.options.tooltip.mode | Should -Be 'single'
        ($overview.panels | Where-Object type -EQ 'xychart').targets[0].query | Should -Be $forecast.targets[0].query
        & "$root/src/scripts/Build-HubGrafanaDashboards.ps1" -DestDir $TestDrive
        "$TestDrive/grafana/deploy.json" | Should -Not -Exist
    }
}
