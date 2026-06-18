#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    ftk - a tiny CLI for the local FinOps Toolkit (Kustainer) stack.

.DESCRIPTION
    Runs KQL against the local Kusto Emulator (Kustainer) and runs the FinOps
    Toolkit published query catalog locally by adapting the upstream .kql files
    on read (no forked copies).

    Subcommands:
      ftk query "<kql>"            Run ad-hoc KQL (.-prefixed = mgmt command).
      ftk schema [-Tables|-Functions]
                                   List tables and/or functions in the database.
      ftk tables <name>            Show one table's column schema (cslschema).
      ftk list                     List the catalog queries discovered on disk.
      ftk run <name> [opts]        Adapt + run a named catalog query locally.

    Connection (overridable with -Endpoint / -Database):
      KUSTAINER_QUERY  full query URL (default http://localhost:<HOST_PORT>/v1/rest/query)
      HOST_PORT        port           (default 8082; read from .env if present)
      FTK_DB           database name  (default Hub)
    Never point this at port 8080 (that is the maenifold MCP gateway).

    Catalog (FTK_CATALOG_PATH overrides; else FTK_REPO / ../finops-toolkit):
      1. $FTK_CATALOG_PATH
      2. <finops-toolkit>/release/agent-skills/finops-toolkit/references/queries/catalog
      3. <finops-toolkit>/src/queries/catalog

.EXAMPLE
    pwsh scripts/ftk.ps1 query "Costs() | summarize sum(EffectiveCost) by ServiceName | top 10 by sum_EffectiveCost"

.EXAMPLE
    pwsh scripts/ftk.ps1 run savings-summary-report --format csv
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Command,

    [Parameter(Position = 1)]
    [string] $Arg1,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Rest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

# --------------------------------------------------------------------------- #
# Connection resolution
# --------------------------------------------------------------------------- #
function Get-HostPort {
    if ($env:HOST_PORT) { return $env:HOST_PORT }
    $envFile = Join-Path $script:RepoRoot '.env'
    if (Test-Path $envFile) {
        foreach ($line in Get-Content $envFile) {
            $t = $line.Trim()
            if ($t -like 'HOST_PORT=*') { return ($t -split '=', 2)[1].Trim() }
        }
    }
    return '8082'
}

function Get-QueryUrl {
    param([string] $Override)
    if ($Override) { return $Override }
    if ($env:KUSTAINER_QUERY) { return $env:KUSTAINER_QUERY }
    return "http://localhost:$(Get-HostPort)/v1/rest/query"
}

function Get-MgmtUrl {
    param([string] $Override)
    return (Get-QueryUrl $Override) -replace '/v1/rest/query', '/v1/rest/mgmt'
}

function Get-Database {
    param([string] $Override)
    if ($Override) { return $Override }
    if ($env:FTK_DB) { return $env:FTK_DB }
    return 'Hub'
}

# --------------------------------------------------------------------------- #
# REST client (same REST pattern used across the ftklocal tooling)
# --------------------------------------------------------------------------- #
function Invoke-Kusto {
    <#
        Run a query (or .mgmt command) and return a PSCustomObject with
        .Columns (string[]) and .Rows (object[][]).
    #>
    param(
        [Parameter(Mandatory)] [string] $Csl,
        [string] $Endpoint,
        [string] $Database,
        [int]    $TimeoutSec = 120
    )
    $db = Get-Database $Database
    $isMgmt = $Csl.TrimStart().StartsWith('.')
    $url = if ($isMgmt) { Get-MgmtUrl $Endpoint } else { Get-QueryUrl $Endpoint }
    $body = @{ db = $db; csl = $Csl } | ConvertTo-Json -Compress
    $headers = @{
        'Content-Type'        = 'application/json'
        'x-ms-client-version' = 'Kusto.Python.Client:1.0.0'  # unlocks full JSON error bodies
    }
    try {
        $resp = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body `
            -TimeoutSec $TimeoutSec
    }
    catch {
        throw (ConvertTo-KustoError $_ $url)
    }
    if (-not $resp.Tables) {
        return [pscustomobject]@{ Columns = @(); Rows = @() }
    }
    $table = $resp.Tables[0]
    $cols = @($table.Columns | ForEach-Object { $_.ColumnName })
    return [pscustomobject]@{ Columns = $cols; Rows = $table.Rows }
}

function ConvertTo-KustoError {
    param($ErrorRecord, [string] $Url)
    $raw = $null
    try { $raw = $ErrorRecord.ErrorDetails.Message } catch { }
    if (-not $raw) {
        try {
            $stream = $ErrorRecord.Exception.Response.GetResponseStream()
            $raw = (New-Object IO.StreamReader($stream)).ReadToEnd()
        } catch { }
    }
    if (-not $raw) {
        return "Cannot reach Kustainer at $Url ($($ErrorRecord.Exception.Message)). Is the container up? Try ``make up``."
    }
    try {
        $obj = $raw | ConvertFrom-Json
        foreach ($key in 'error', 'Error') {
            if ($obj.PSObject.Properties.Name -contains $key -and $obj.$key) {
                $err = $obj.$key
                $msg = $err.'@message'; if (-not $msg) { $msg = $err.message }; if (-not $msg) { $msg = $err.'@type' }
                $extra = $null
                if ($err.PSObject.Properties.Name -contains '@context' -and $err.'@context') {
                    $extra = $err.'@context'.'@message'
                }
                if ($extra) { return "Kusto error: $msg | $extra" }
                return "Kusto error: $msg"
            }
        }
    } catch { }
    return "Kusto error: $($raw.Substring(0, [Math]::Min(400, $raw.Length)))"
}

function Get-Scalar {
    param([string] $Csl, [string] $Endpoint, [string] $Database)
    $r = Invoke-Kusto -Csl $Csl -Endpoint $Endpoint -Database $Database
    if ($r.Rows -and $r.Rows.Count -gt 0 -and $r.Rows[0].Count -gt 0) { return $r.Rows[0][0] }
    return $null
}

# --------------------------------------------------------------------------- #
# Output formatting
# --------------------------------------------------------------------------- #
function Format-Result {
    param([string[]] $Columns, $Rows, [string] $Format)

    if ($Format -eq 'json') {
        $list = foreach ($row in $Rows) {
            $o = [ordered]@{}
            for ($i = 0; $i -lt $Columns.Count; $i++) { $o[$Columns[$i]] = $row[$i] }
            [pscustomobject]$o
        }
        return ($list | ConvertTo-Json -Depth 10)
    }
    if ($Format -eq 'csv') {
        $sb = [Text.StringBuilder]::new()
        [void]$sb.AppendLine(($Columns -join ','))
        foreach ($row in $Rows) {
            $cells = for ($i = 0; $i -lt $Columns.Count; $i++) {
                $v = if ($null -eq $row[$i]) { '' } else { [string]$row[$i] }
                if ($v -match '[",\n]') { '"' + ($v -replace '"', '""') + '"' } else { $v }
            }
            [void]$sb.AppendLine(($cells -join ','))
        }
        return $sb.ToString().TrimEnd("`r", "`n")
    }
    # table (default)
    if (-not $Columns -or $Columns.Count -eq 0) { return '(no columns)' }
    $widths = @($Columns | ForEach-Object { $_.Length })
    $strRows = @()
    foreach ($row in $Rows) {
        $sr = for ($i = 0; $i -lt $Columns.Count; $i++) { if ($null -eq $row[$i]) { '' } else { [string]$row[$i] } }
        $sr = @($sr)
        $strRows += , $sr
        for ($i = 0; $i -lt $Columns.Count; $i++) { if ($sr[$i].Length -gt $widths[$i]) { $widths[$i] = $sr[$i].Length } }
    }
    $sep = '  '
    $lines = @()
    $lines += (0..($Columns.Count - 1) | ForEach-Object { $Columns[$_].PadRight($widths[$_]) }) -join $sep
    $lines += (0..($Columns.Count - 1) | ForEach-Object { '-' * $widths[$_] }) -join $sep
    foreach ($sr in $strRows) {
        $lines += (0..($Columns.Count - 1) | ForEach-Object { $sr[$_].PadRight($widths[$_]) }) -join $sep
    }
    $n = @($Rows).Count
    $lines += ''
    $lines += "($n row$(if ($n -ne 1) { 's' }))"
    return ($lines -join "`n")
}

# --------------------------------------------------------------------------- #
# Catalog discovery
# --------------------------------------------------------------------------- #
$script:LibraryQueries = @('costs-enriched-base')

function Get-FtkRepo {
    if ($env:FTK_REPO) { return $env:FTK_REPO }
    # ftklocal lives in-repo at <root>/src/templates/finops-hub-local, so the toolkit
    # root (which holds src/queries/catalog) is three directories up from $RepoRoot.
    $inRepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $script:RepoRoot))
    if ($inRepoRoot -and (Test-Path (Join-Path $inRepoRoot 'src/queries/catalog') -PathType Container)) {
        return $inRepoRoot
    }
    # Robust fallback for worktrees / unusual layouts: the git top-level.
    # Guard on git being present so a missing git degrades to the legacy fallback
    # instead of throwing under $ErrorActionPreference = 'Stop'.
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitTop = (& git -C $script:RepoRoot rev-parse --show-toplevel 2>$null)
        if ($gitTop -and (Test-Path (Join-Path $gitTop 'src/queries/catalog') -PathType Container)) {
            return $gitTop
        }
    }
    # Last resort: legacy prototype layout where ftklocal sat beside a finops-toolkit clone.
    return (Resolve-Path (Join-Path (Split-Path -Parent $script:RepoRoot) 'finops-toolkit') -ErrorAction SilentlyContinue) `
        ?? (Join-Path (Split-Path -Parent $script:RepoRoot) 'finops-toolkit')
}

function Get-CatalogDir {
    $candidates = @()
    if ($env:FTK_CATALOG_PATH) { $candidates += $env:FTK_CATALOG_PATH }
    $repo = Get-FtkRepo
    $candidates += (Join-Path $repo 'release/agent-skills/finops-toolkit/references/queries/catalog')
    $candidates += (Join-Path $repo 'src/queries/catalog')
    foreach ($c in $candidates) { if (Test-Path $c -PathType Container) { return $c } }
    return $null
}

function Get-CatalogQueries {
    $d = Get-CatalogDir
    if (-not $d) { return @() }
    return @(Get-ChildItem -Path $d -Filter '*.kql' | Sort-Object Name)
}

function Get-QueryDescription {
    param([string] $Path)
    $lines = Get-Content -Path $Path
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '//\s*Description:') {
            for ($j = $i + 1; $j -lt [Math]::Min($i + 4, $lines.Count); $j++) {
                if ($lines[$j] -match '^\s*//\s*(.+)') { $t = $Matches[1].Trim(); if ($t) { return $t } }
            }
        }
    }
    foreach ($line in $lines) {
        if ($line -match '^\s*//\s*Query:\s*(.+)') { return $Matches[1].Trim() }
    }
    return ''
}

# --------------------------------------------------------------------------- #
# Query adapter (the only local-compat logic)
# --------------------------------------------------------------------------- #
$script:SchemaCache = @{}

function Get-FunctionSchema {
    param([string] $Fn, [string] $Endpoint, [string] $Database)
    $key = "$(Get-Database $Database)::$Fn"
    if ($script:SchemaCache.ContainsKey($key)) { return $script:SchemaCache[$key] }
    $cols = @{}
    try {
        $r = Invoke-Kusto -Csl "$Fn() | getschema | project ColumnName" -Endpoint $Endpoint -Database $Database
        foreach ($row in $r.Rows) { $cols[$row[0]] = $true }
    } catch { }
    $script:SchemaCache[$key] = $cols
    return $cols
}

function ConvertTo-KqlLiteral {
    param([string] $Value)
    $v = $Value.Trim()
    if ($v -match '^-?\d+$') { return $v }
    if ($v -match '^-?\d*\.\d+$') { return $v }
    if ($v -in 'true', 'false') { return $v.ToLower() }
    if ($v -match '^\d{4}-\d{2}-\d{2}([ T].*)?$') { return "datetime($($v -replace ' ', 'T'))" }
    return "'" + ($v -replace "'", "\'") + "'"
}

function Get-InferredSpanMonths {
    param([string] $Rhs)
    if ($Rhs -match 'ago\((\d+)d\)') { return [Math]::Max(1, [Math]::Round([int]$Matches[1] / 30.0)) }
    if ($Rhs -match 'monthsago\((\d+)\)') { return [Math]::Max(1, [int]$Matches[1]) }
    return 1
}

function Resolve-Window {
    param([string] $Kql, [string] $Start, [string] $End, [string] $Endpoint, [string] $Database)
    if ($Start -or $End) {
        $s = if ($Start) { ConvertTo-KqlLiteral $Start } else { $null }
        $e = if ($End)   { ConvertTo-KqlLiteral $End }   else { $null }
        return @($s, $e)
    }
    $span = 1
    if ($Kql -match 'let\s+startDate\s*=\s*([^;]+);') { $span = Get-InferredSpanMonths $Matches[1] }
    $maxRaw = $null
    try { $maxRaw = Get-Scalar -Csl 'Costs() | summarize max(ChargePeriodStart)' -Endpoint $Endpoint -Database $Database } catch { $maxRaw = $null }
    if (-not $maxRaw) { return @($null, $null) }
    $maxd = ([datetime]$maxRaw).ToUniversalTime()
    $endDt = (Get-Date -Year $maxd.Year -Month $maxd.Month -Day 1 -Hour 0 -Minute 0 -Second 0).AddMonths(1)
    $startDt = $endDt.AddMonths(-$span)
    $fmt = { param($d) "datetime($($d.ToString('yyyy-MM-ddTHH:mm:ssZ')))" }
    return @((& $fmt $startDt), (& $fmt $endDt))
}

function Invoke-ProjectAwayTolerance {
    param([string] $Kql, [string] $Endpoint, [string] $Database)
    if ($Kql -notmatch 'project-away') { return $Kql }
    if ($Kql -notmatch '\b(Costs|Prices|Recommendations|Transactions)\(\)') { return $Kql }
    $fn = $Matches[1]
    $schema = Get-FunctionSchema -Fn $fn -Endpoint $Endpoint -Database $Database
    if ($schema.Count -eq 0) { return $Kql }
    return [regex]::Replace($Kql, '(\|\s*project-away\s+)([^\n|]+)', {
            param($m)
            $prefix = $m.Groups[1].Value
            $names = $m.Groups[2].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            $kept = @($names | Where-Object { $schema.ContainsKey($_) })
            if ($kept.Count -eq 0) { return '' }
            return $prefix + ($kept -join ', ')
        })
}

function Convert-CatalogQuery {
    param(
        [string] $Kql,
        [hashtable] $Params,
        [string] $Start,
        [string] $End,
        [string] $Endpoint,
        [string] $Database
    )
    $out = $Kql

    # 1. Date window
    $win = Resolve-Window -Kql $out -Start $Start -End $End -Endpoint $Endpoint -Database $Database
    if ($null -ne $win[0]) {
        $out = [regex]::Replace($out, '(let\s+startDate\s*=\s*)([^;]+)(;)', { param($m) $m.Groups[1].Value + $win[0] + $m.Groups[3].Value }, 1)
    }
    if ($null -ne $win[1]) {
        $out = [regex]::Replace($out, '(let\s+endDate\s*=\s*)([^;]+)(;)', { param($m) $m.Groups[1].Value + $win[1] + $m.Groups[3].Value }, 1)
    }

    # 1b. Arbitrary --param overrides on top-level let bindings (typed literals).
    if ($Params) {
        foreach ($k in $Params.Keys) {
            $lit = ConvertTo-KqlLiteral $Params[$k]
            $pat = "(let\s+$([regex]::Escape($k))\s*=\s*)([^;]+)(;)"
            if ($out -notmatch $pat) {
                throw "--param '$k' does not match a top-level ``let $k = ...;`` in the query"
            }
            $out = [regex]::Replace($out, $pat, { param($m) $m.Groups[1].Value + $lit + $m.Groups[3].Value }, 1)
        }
    }

    # 2. decimal -> real normalization (the verified Kustainer compatibility fix)
    $out = $out -replace "todecimal\(\s*''\s*\)", 'real(null)'
    $out = $out -replace '\btodecimal\s*\(', 'toreal('
    $out = $out -replace '\bdecimal\s*\(', 'real('

    # 3. project-away tolerance: drop columns the local schema doesn't expose
    $out = Invoke-ProjectAwayTolerance -Kql $out -Endpoint $Endpoint -Database $Database

    return $out
}

# --------------------------------------------------------------------------- #
# Option parsing for the remaining args (mirrors the CLI flag surface)
# --------------------------------------------------------------------------- #
function Read-Options {
    param([string[]] $Tokens)
    $opts = @{ format = 'table'; params = @{}; positional = @() }
    $i = 0
    while ($i -lt $Tokens.Count) {
        switch -Regex ($Tokens[$i]) {
            '^--format$|^-Format$' { $opts.format = $Tokens[++$i] }
            '^--param$|^-Param$'   { $kv = $Tokens[++$i]; $p = $kv -split '=', 2; if ($p.Count -ne 2) { throw "--param must be key=value, got '$kv'" }; $opts.params[$p[0].Trim()] = $p[1] }
            '^--start$|^-Start$'   { $opts.start = $Tokens[++$i] }
            '^--end$|^-End$'       { $opts.end = $Tokens[++$i] }
            '^--show$|^-Show$'     { $opts.show = $true }
            '^--tables$|^-Tables$' { $opts.tables = $true }
            '^--functions$|^-Functions$' { $opts.functions = $true }
            '^--endpoint$|^-Endpoint$'   { $opts.endpoint = $Tokens[++$i] }
            '^--database$|^-Database$'    { $opts.database = $Tokens[++$i] }
            default { $opts.positional += $Tokens[$i] }
        }
        $i++
    }
    return $opts
}

# --------------------------------------------------------------------------- #
# Subcommands
# --------------------------------------------------------------------------- #
function Show-Usage {
    @'
ftk - local FinOps Toolkit query CLI

  ftk query "<kql>" [--format table|json|csv]
  ftk schema [--tables] [--functions]
  ftk tables <name>
  ftk list
  ftk run <name> [--param k=v] [--start <date>] [--end <date>] [--show] [--format ...]

  Global: [--endpoint <url>] [--database <db>]
'@
}

$argv = @()
if ($Arg1) { $argv += $Arg1 }
if ($Rest) { $argv += $Rest }
$opt = Read-Options $argv

$endpoint = if ($opt.ContainsKey('endpoint')) { $opt.endpoint } else { $null }
$db = if ($opt.ContainsKey('database')) { $opt.database } else { $null }

try {
    switch ($Command) {
        'query' {
            $kql = $opt.positional[0]
            if (-not $kql) { throw 'usage: ftk query "<kql>"' }
            $r = Invoke-Kusto -Csl $kql -Endpoint $endpoint -Database $db
            Write-Output (Format-Result -Columns $r.Columns -Rows $r.Rows -Format $opt.format)
        }
        'schema' {
            $wantTables = $opt.ContainsKey('tables') -or -not $opt.ContainsKey('functions')
            $wantFuncs = $opt.ContainsKey('functions') -or -not $opt.ContainsKey('tables')
            if ($wantTables) {
                $r = Invoke-Kusto -Csl '.show tables | project TableName | order by TableName asc' -Endpoint $endpoint -Database $db
                Write-Output 'Tables:'
                foreach ($row in $r.Rows) { Write-Output "  $($row[0])" }
            }
            if ($wantFuncs) {
                $r = Invoke-Kusto -Csl '.show functions | project Name | order by Name asc' -Endpoint $endpoint -Database $db
                Write-Output 'Functions:'
                foreach ($row in $r.Rows) { Write-Output "  $($row[0])" }
            }
        }
        'tables' {
            $name = $opt.positional[0]
            if (-not $name) { throw 'usage: ftk tables <name>' }
            $r = Invoke-Kusto -Csl ".show table $name cslschema | project Schema" -Endpoint $endpoint -Database $db
            if ($r.Rows) { Write-Output $r.Rows[0][0] }
        }
        'list' {
            $d = Get-CatalogDir
            if (-not $d) { Write-Error 'No catalog found. Set FTK_CATALOG_PATH or FTK_REPO (looked under ../finops-toolkit).'; exit 1 }
            Write-Output "Catalog: $d`n"
            foreach ($p in Get-CatalogQueries) {
                $nm = [IO.Path]::GetFileNameWithoutExtension($p.Name)
                $tag = if ($script:LibraryQueries -contains $nm) { '  [library]' } else { '' }
                $desc = Get-QueryDescription $p.FullName
                Write-Output ('  {0,-42}{1} {2}' -f $nm, $tag, $desc)
            }
        }
        'run' {
            $name = $opt.positional[0]
            if (-not $name) { throw 'usage: ftk run <name>' }
            if ($script:LibraryQueries -contains $name) { throw "'$name' is a library building block, not a runnable query." }
            $path = $null
            foreach ($p in Get-CatalogQueries) { if ([IO.Path]::GetFileNameWithoutExtension($p.Name) -eq $name) { $path = $p.FullName; break } }
            if (-not $path) { throw "Catalog query '$name' not found. Try ``ftk list``." }
            $raw = Get-Content -Raw -Path $path
            $start = if ($opt.ContainsKey('start')) { $opt.start } else { $null }
            $end = if ($opt.ContainsKey('end')) { $opt.end } else { $null }
            $adapted = Convert-CatalogQuery -Kql $raw -Params $opt.params -Start $start -End $end -Endpoint $endpoint -Database $db
            if ($opt.ContainsKey('show')) { Write-Output $adapted; break }
            $r = Invoke-Kusto -Csl $adapted -Endpoint $endpoint -Database $db
            Write-Output (Format-Result -Columns $r.Columns -Rows $r.Rows -Format $opt.format)
        }
        default { Show-Usage; if ($Command) { exit 2 } }
    }
}
catch {
    Write-Error "error: $($_.Exception.Message)"
    exit 2
}
