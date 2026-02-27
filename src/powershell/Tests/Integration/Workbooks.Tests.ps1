# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

<#
    .SYNOPSIS
    Recursively extracts all query items from a workbook JSON object.

    .DESCRIPTION
    Walks the workbook JSON tree and returns objects for each embedded query, including its name,
    JSON path, query text, query type, and resource type.
#>
function Get-WorkbookQueries
{
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter()]
        [string]$Path = 'root'
    )

    $queries = @()

    if ($null -eq $Object)
    {
        return $queries
    }

    if ($Object -is [System.Collections.IList])
    {
        for ($i = 0; $i -lt $Object.Count; $i++)
        {
            if ($null -ne $Object[$i])
            {
                $queries += Get-WorkbookQueries -Object $Object[$i] -Path "$Path[$i]"
            }
        }
        return $queries
    }

    if ($Object -is [PSCustomObject])
    {
        # Check if this node has a query property
        if ($Object.PSObject.Properties['query'] -and $Object.query -is [string] -and $Object.query.Length -gt 0)
        {
            $queries += [PSCustomObject]@{
                Name         = $Object.PSObject.Properties['name'].Value ?? $Path
                Path         = $Path
                Query        = $Object.query
                QueryType    = $Object.PSObject.Properties['queryType'].Value
                ResourceType = $Object.PSObject.Properties['resourceType'].Value
            }
        }

        # Recurse into child properties
        foreach ($prop in $Object.PSObject.Properties)
        {
            if ($null -ne $prop.Value)
            {
                $queries += Get-WorkbookQueries -Object $prop.Value -Path "$Path.$($prop.Name)"
            }
        }
    }

    return $queries
}

<#
    .SYNOPSIS
    Resolves workbook parameter placeholders so queries can be executed against Azure Resource Graph.

    .DESCRIPTION
    Workbook queries contain {ParameterName} placeholders that are resolved at runtime by the Azure
    Monitor workbook engine. To execute these queries directly via Search-AzGraph, this function:
    1. Removes entire 'where' clauses that depend on parameters (filter lines)
    2. Replaces inline parameter references with safe literal values
    3. Reports any remaining unresolved parameters
#>
function Resolve-WorkbookParameters
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query
    )

    # Remove inline 'and <col> in ({Param})' filter conditions before line processing
    # These appear mid-line and can't be caught by line-level where removal
    $result = [regex]::Replace($Query, '\s+and\s+\w+\s+in\s*\(\{[A-Za-z_]+\}\)', '')

    $lines = $result -split "`r?`n"

    $resolved = @()
    foreach ($line in $lines)
    {
        $trimmed = $line.Trim()

        # Remove 'where' clauses that contain parameter placeholders
        # These are runtime filters that can't be evaluated statically
        if ($trimmed -match '^\|?\s*where\b' -and $trimmed -match '\{[A-Za-z_]+\}')
        {
            continue
        }

        $resolved += $line
    }

    $result = $resolved -join "`n"

    # Replacement values are unquoted — the workbook engine replaces {param}
    # with the raw selected value; query authors add quotes as needed
    # NOTE: Use unary comma (,@()) to prevent PowerShell from flattening nested arrays
    $replacements = @(
        , @('{TagName}', 'Environment')
        , @('{TagValue}', '')
        , @('{TagFilter}', '')
        , @('{ResourceGroup}', '*')
        , @('{Subscription}', '*')
        , @('{term}', '1Year')
        , @('{LookBackPeriod}', '7')
        , @('{resourceType}', '*')
        , @('{ResourceType}', '*')
        , @('{ResourceFilter}', '')
        , @('{ResourceIdFilter}', '')
        , @('{SelectedResourceId}', '')
        , @('{OrphanDisks}', 'Yes')
        , @('{OrphanNIC}', 'Yes')
        , @('{OrphanNSG}', 'Yes')
        , @('{OrphanIPs}', 'Yes')
        , @('{OrphanAppGW}', '|')
        , @('{OrphanLB}', 'Yes')
        , @('{VMState}', '')
        , @('{RuleConditionSet}', '')
        , @('{AlertDisplayNameFilter}', '')
        , @('{AlertNameFilter}', '')
        , @('{NewAlertFilter}', '')
        , @('{SeverityFilter}', '')
        , @('{ResourceGroupFilter}', '')
        , @('{DisplayName}', '')
        , @('{selectedOwner}', '')
        , @('{selectedWorkspaceId}', '')
    )

    foreach ($pair in $replacements)
    {
        $result = $result.Replace($pair[0], $pair[1])
    }

    # Prefix 'resources |' for fragment queries that start with a clause keyword
    # The workbook engine auto-prefixes the table based on resourceType
    if ($result.TrimStart() -match '^(where|extend|project|summarize|join|order|mv-expand|parse|distinct)\b')
    {
        $result = "resources`n| $($result.TrimStart())"
    }

    return $result
}

Describe 'Workbooks' {
    BeforeDiscovery {
        $workbookRoot = "$PSScriptRoot/../../../workbooks"

        # Find all workbook files (both .workbook and workbook.json formats)
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $workbookFiles = @(
            Get-ChildItem -Path $workbookRoot -Recurse -Include '*.workbook', 'workbook.json' `
            | Where-Object { $_.Directory.Name -ne '.scaffold' } `
            | ForEach-Object {
                @{
                    Name         = $_.Directory.Name + '/' + $_.Name
                    RelativePath = $_.FullName.Substring((Resolve-Path $workbookRoot).Path.Length + 1)
                    FullPath     = $_.FullName
                }
            }
        )

        # Find AHB workbook files specifically for Dev/Test filter validation
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $ahbWorkbookFiles = @(
            $workbookFiles | Where-Object { $_.Name -like '*AHB*' }
        )

        # Extract all ARG queries across all workbooks for execution tests
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $argQueries = @(
            $workbookFiles | ForEach-Object {
                $wbFile = $_
                $workbook = Get-Content -Path $wbFile.FullPath -Raw | ConvertFrom-Json
                $queries = Get-WorkbookQueries -Object $workbook
                $queries `
                | Where-Object { $_.QueryType -eq 1 -and $_.ResourceType -eq 'microsoft.resourcegraph/resources' } `
                | ForEach-Object {
                    @{
                        Workbook     = $wbFile.Name
                        QueryName    = $_.Name
                        Query        = $_.Query
                        WorkbookPath = $wbFile.RelativePath
                    }
                }
            }
        )
    }

    BeforeAll {
        $context = Get-AzContext
        if (-not $context)
        {
            throw 'Not authenticated to Azure. Run Connect-AzAccount first.'
        }

        # Verify Az.ResourceGraph module is available
        if (-not (Get-Module -ListAvailable -Name 'Az.ResourceGraph'))
        {
            throw 'Az.ResourceGraph module is not installed. Run Install-Module Az.ResourceGraph.'
        }
        Import-Module Az.ResourceGraph -ErrorAction Stop

        # Define helper functions in test scope (file-scope functions from BeforeDiscovery
        # are not visible inside It blocks in Pester)
        function Get-WorkbookQueries
        {
            param(
                [Parameter(Mandatory = $true)]
                [object]$Object,
                [Parameter()]
                [string]$Path = 'root'
            )

            $queries = @()
            if ($null -eq $Object) { return $queries }

            if ($Object -is [System.Collections.IList])
            {
                for ($i = 0; $i -lt $Object.Count; $i++)
                {
                    if ($null -ne $Object[$i])
                    {
                        $queries += Get-WorkbookQueries -Object $Object[$i] -Path "$Path[$i]"
                    }
                }
                return $queries
            }

            if ($Object -is [PSCustomObject])
            {
                if ($Object.PSObject.Properties['query'] -and $Object.query -is [string] -and $Object.query.Length -gt 0)
                {
                    $queries += [PSCustomObject]@{
                        Name         = $Object.PSObject.Properties['name'].Value ?? $Path
                        Path         = $Path
                        Query        = $Object.query
                        QueryType    = $Object.PSObject.Properties['queryType'].Value
                        ResourceType = $Object.PSObject.Properties['resourceType'].Value
                    }
                }

                foreach ($prop in $Object.PSObject.Properties)
                {
                    if ($null -ne $prop.Value)
                    {
                        $queries += Get-WorkbookQueries -Object $prop.Value -Path "$Path.$($prop.Name)"
                    }
                }
            }

            return $queries
        }

        function Resolve-WorkbookParameters
        {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Query
            )

            # Remove inline 'and <col> in ({Param})' filter conditions before line processing
            # These appear mid-line and can't be caught by line-level where removal
            $result = [regex]::Replace($Query, '\s+and\s+\w+\s+in\s*\(\{[A-Za-z_]+\}\)', '')

            $lines = $result -split "`r?`n"

            $resolved = @()
            foreach ($line in $lines)
            {
                $trimmed = $line.Trim()
                if ($trimmed -match '^\|?\s*where\b' -and $trimmed -match '\{[A-Za-z_]+\}')
                {
                    continue
                }
                $resolved += $line
            }

            $result = $resolved -join "`n"

            # Replacement values are unquoted — the workbook engine replaces {param}
            # with the raw selected value; query authors add quotes as needed
            # NOTE: Use unary comma (,@()) to prevent PowerShell from flattening nested arrays
            $replacements = @(
                , @('{TagName}', 'Environment')
                , @('{TagValue}', '')
                , @('{TagFilter}', '')
                , @('{ResourceGroup}', '*')
                , @('{Subscription}', '*')
                , @('{term}', '1Year')
                , @('{LookBackPeriod}', '7')
                , @('{resourceType}', '*')
                , @('{ResourceType}', '*')
                , @('{ResourceFilter}', '')
                , @('{ResourceIdFilter}', '')
                , @('{SelectedResourceId}', '')
                , @('{OrphanDisks}', 'Yes')
                , @('{OrphanNIC}', 'Yes')
                , @('{OrphanNSG}', 'Yes')
                , @('{OrphanIPs}', 'Yes')
                , @('{OrphanAppGW}', '|')
                , @('{OrphanLB}', 'Yes')
                , @('{VMState}', '')
                , @('{RuleConditionSet}', '')
                , @('{AlertDisplayNameFilter}', '')
                , @('{AlertNameFilter}', '')
                , @('{NewAlertFilter}', '')
                , @('{SeverityFilter}', '')
                , @('{ResourceGroupFilter}', '')
                , @('{DisplayName}', '')
                , @('{selectedOwner}', '')
                , @('{selectedWorkspaceId}', '')
            )

            foreach ($pair in $replacements)
            {
                $result = $result.Replace($pair[0], $pair[1])
            }

            # Prefix 'resources |' for fragment queries that start with a clause keyword
            # The workbook engine auto-prefixes the table based on resourceType
            if ($result.TrimStart() -match '^(where|extend|project|summarize|join|order|mv-expand|parse|distinct)\b')
            {
                $result = "resources`n| $($result.TrimStart())"
            }

            return $result
        }
    }

    Context 'JSON validation' {
        It 'Should be valid JSON: <RelativePath>' -ForEach $workbookFiles {
            $parseError = $null
            try
            {
                $null = Get-Content -Path $FullPath -Raw | ConvertFrom-Json -ErrorAction Stop
            }
            catch
            {
                $parseError = $_.Exception.Message
            }
            $parseError | Should -BeNullOrEmpty -Because "workbook file should be valid JSON"
        }

        It 'Should contain at least one query: <RelativePath>' -ForEach $workbookFiles {
            # Arrange
            $workbook = Get-Content -Path $FullPath -Raw | ConvertFrom-Json

            # Act
            $queries = Get-WorkbookQueries -Object $workbook

            # Assert
            $queries.Count | Should -BeGreaterThan 0 -Because "workbook should contain at least one embedded query"
        }
    }

    Context 'AHB Dev/Test subscription exclusion' {
        It 'Should exclude Dev/Test subscriptions in all ResourceContainers queries: <RelativePath>' -ForEach $ahbWorkbookFiles {
            # Arrange
            $workbook = Get-Content -Path $FullPath -Raw | ConvertFrom-Json
            $queries = Get-WorkbookQueries -Object $workbook

            # Act — filter to queries that join ResourceContainers with resources (AHB subscription-scoped queries)
            # Exclude simple parameter queries that just look up subscription IDs without joining to resources
            $subscriptionQueries = $queries | Where-Object {
                $_.Query -match 'ResourceContainers' -and $_.Query -match '\bjoin\b'
            }
            $missingFilter = $subscriptionQueries | Where-Object {
                $_.Query -notmatch 'MSDNDevTest_2014-09-01'
            }

            # Assert
            $subscriptionQueries.Count | Should -BeGreaterThan 0 -Because "AHB workbooks should have ResourceContainers queries"
            $missingFilter | Should -BeNullOrEmpty -Because "all ResourceContainers queries in AHB workbooks must exclude Dev/Test subscriptions using the MSDNDevTest_2014-09-01 filter"
        }
    }

    Context 'ARG query execution' {
        It 'Should execute without errors: <Workbook> / <QueryName>' -ForEach $argQueries {
            Monitor "Executing $Workbook / $QueryName..." -Indent '  ' {
                # Substitute workbook parameters with safe defaults
                $resolvedQuery = Resolve-WorkbookParameters -Query $Query

                # Check for any remaining unresolved parameters (includes merge format like {Param:value})
                if ($resolvedQuery -match '\{[A-Za-z_]+[:\}]')
                {
                    $unresolvedParams = [regex]::Matches($resolvedQuery, '\{[A-Za-z_]+(?::[A-Za-z_]+)?\}') | ForEach-Object { $_.Value } | Select-Object -Unique
                    Report "Skipping — unresolved parameters: $($unresolvedParams -join ', ')"
                    Set-ItResult -Inconclusive -Because "query has unresolved parameters: $($unresolvedParams -join ', ')"
                    return
                }

                try
                {
                    $results = Search-AzGraph -Query $resolvedQuery -First 1 -ErrorAction Stop
                    Report "Returned $($results.Count) result(s)"
                }
                catch
                {
                    Report "Query failed: $($_.Exception.Message)" -Exception $_.Exception
                    throw
                }
            }
        }
    }

    Context 'ARG query performance' {
        It 'Should complete within 30 seconds: <Workbook> / <QueryName>' -ForEach $argQueries {
            # Substitute workbook parameters with safe defaults
            $resolvedQuery = Resolve-WorkbookParameters -Query $Query

            # Skip queries with unresolved parameters (includes merge format like {Param:value})
            if ($resolvedQuery -match '\{[A-Za-z_]+(?::[A-Za-z_]+)?\}')
            {
                Set-ItResult -Skipped -Because 'query has unresolved parameters'
                return
            }

            Monitor "Testing performance for $Workbook / $QueryName..." -Indent '  ' {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                try
                {
                    $null = Search-AzGraph -Query $resolvedQuery -First 1 -ErrorAction Stop
                    $stopwatch.Stop()
                    $ms = $stopwatch.ElapsedMilliseconds
                    Report "Completed in ${ms}ms"
                    $ms | Should -BeLessThan 30000 -Because 'ARG queries should complete within 30 seconds'
                }
                catch
                {
                    Set-ItResult -Inconclusive -Because "query execution failed: $($_.Exception.Message)"
                }
            }
        }
    }

    Context 'KQL syntax validation' {
        It 'Should have balanced parentheses: <RelativePath>' -ForEach $workbookFiles {
            # Arrange
            $workbook = Get-Content -Path $FullPath -Raw | ConvertFrom-Json
            $queries = Get-WorkbookQueries -Object $workbook

            # Act — check KQL queries only (not JSON merge queries)
            $kqlQueries = $queries | Where-Object { $_.Query -notmatch '^\s*\{' }
            $unbalanced = @($kqlQueries | Where-Object {
                    $open = ($_.Query.ToCharArray() | Where-Object { $_ -eq '(' }).Count
                    $close = ($_.Query.ToCharArray() | Where-Object { $_ -eq ')' }).Count
                    $open -ne $close
                })

            # Assert
            if ($unbalanced.Count -gt 0)
            {
                $details = $unbalanced | ForEach-Object { $_.Name } | Select-Object -First 5
                $unbalanced.Count | Should -Be 0 -Because "all KQL queries should have balanced parentheses, but these do not: $($details -join ', ')"
            }
        }
    }
}
