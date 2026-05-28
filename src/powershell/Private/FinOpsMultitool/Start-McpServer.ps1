###########################################################################
# START-MCPSERVER.PS1
# FINOPS MULTITOOL MCP SERVER (STDIO)
###########################################################################
# Purpose: Model Context Protocol server exposing FinOps scan modules
#          as AI-callable tools over JSON-RPC via stdin/stdout.
# Author:  Zac Larsen
# Date:    Created for FinOps Toolkit integration
#
# Description:
# 1. Imports FinOpsMultitool.psm1 (same module used by TUI/GUI)
# 2. Listens for JSON-RPC messages on stdin
# 3. Dispatches tool calls to existing Get-* functions
# 4. Returns structured JSON results on stdout
#
# Prerequisites:
# - PowerShell 7+ (pwsh)
# - Az.Accounts, Az.Resources, Az.ResourceGraph modules
# - Active Azure session (Connect-AzAccount)
#
# Usage:
# MCP config (VS Code settings.json or mcp.json):
#   {
#     "mcp": {
#       "servers": {
#         "finops-multitool": {
#           "command": "pwsh",
#           "args": ["-NoProfile", "-File", "path/to/Start-McpServer.ps1"]
#         }
#       }
#     }
#   }
###########################################################################

$ErrorActionPreference = 'Stop'

# Suppress all Write-Host output — scan modules use Write-Host for TUI
# display, but MCP must only write JSON-RPC to stdout.
# Redirect Write-Host to stderr so MCP clients see clean JSON on stdout.
$PSDefaultParameterValues['Write-Host:InformationAction'] = 'SilentlyContinue'

# Import the module
$psm1Path = Join-Path $PSScriptRoot 'FinOpsMultitool.psm1'
if (-not (Test-Path $psm1Path)) {
    [Console]::Error.WriteLine("ERROR: FinOpsMultitool.psm1 not found at $psm1Path")
    exit 1
}
Import-Module $psm1Path -Force -DisableNameChecking

# =====================================================================
#  MCP PROTOCOL CONSTANTS
# =====================================================================
$MCP_VERSION = '2024-11-05'
$SERVER_NAME = 'finops-multitool'
$SERVER_VERSION = '1.0.0'

# =====================================================================
#  TOOL DEFINITIONS
# =====================================================================
# Each tool maps to a Get-* function in the module. The MCP server
# handles subscription resolution and parameter binding.

$toolDefinitions = @(
    @{
        name        = 'scan_orphaned_resources'
        description = 'Find orphaned Azure resources (unattached disks, NICs, public IPs, NSGs) across subscriptions.'
        fn          = 'Get-OrphanedResources'
        category    = 'Optimization'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_idle_vms'
        description = 'Find idle or underutilized VMs (less than 5% average CPU over 14-30 days) with cost impact classification.'
        fn          = 'Get-IdleVMs'
        category    = 'Optimization'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_storage_tier_advice'
        description = 'Analyze storage accounts for tier optimization opportunities (Hot to Cool/Cold/Archive).'
        fn          = 'Get-StorageTierAdvice'
        category    = 'Optimization'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_ahb_opportunities'
        description = 'Find Windows/SQL VMs and SQL databases not using Azure Hybrid Benefit (up to 40-55% savings).'
        fn          = 'Get-AHBOpportunities'
        category    = 'Optimization'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_tag_inventory'
        description = 'Inventory all resource tags across subscriptions. Returns tag coverage percentage, tag names, resource counts, and untagged resources.'
        fn          = 'Get-TagInventory'
        category    = 'Governance'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_tag_recommendations'
        description = 'Analyze existing tags and recommend improvements: missing CAF standard tags, inconsistent casing, similar/duplicate names.'
        fn          = 'Get-TagRecommendations'
        category    = 'Governance'
        requiresTagInventory = $true
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_policy_inventory'
        description = 'List all Azure Policy assignments with scope, effect, enforcement mode, and compliance status.'
        fn          = 'Get-PolicyInventory'
        category    = 'Governance'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_policy_recommendations'
        description = 'Evaluate policy coverage gaps and recommend cost governance policies (tagging, region, SKU restrictions).'
        fn          = 'Get-PolicyRecommendations'
        category    = 'Governance'
        requiresPolicyInventory = $true
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_cost_data'
        description = 'Get current month actual and forecasted cost per subscription. Returns spend, forecast, and currency.'
        fn          = 'Get-CostData'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_resource_costs'
        description = 'Get top resources by cost (actual month-to-date spend) with resource group, type, and forecast.'
        fn          = 'Get-ResourceCosts'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_cost_by_tag'
        description = 'Break down cost by tag key/value pairs. Shows spend per tag value and identifies untagged spend.'
        fn          = 'Get-CostByTag'
        category    = 'Cost Analysis'
        requiresTagInventory = $true
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_cost_trend'
        description = 'Get month-over-month cost trend (last 3-6 months) per subscription to identify spending patterns.'
        fn          = 'Get-CostTrend'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_reservation_advice'
        description = 'Get Azure Advisor reservation purchase recommendations with estimated annual savings.'
        fn          = 'Get-ReservationAdvice'
        category    = 'Commitments'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_commitment_utilization'
        description = 'Check utilization rates of existing reservations and savings plans. Identifies underutilized commitments.'
        fn          = 'Get-CommitmentUtilization'
        category    = 'Commitments'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_savings_realized'
        description = 'Calculate actual savings from reservations, savings plans, and Azure Hybrid Benefit (monthly and annual).'
        fn          = 'Get-SavingsRealized'
        category    = 'Commitments'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_budget_status'
        description = 'Check budget consumption vs thresholds. Returns budget amounts, actual spend, percentage used, and risk level.'
        fn          = 'Get-BudgetStatus'
        category    = 'Monitoring'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_anomaly_alerts'
        description = 'Retrieve recent cost anomaly alerts and detection rules.'
        fn          = 'Get-AnomalyAlerts'
        category    = 'Monitoring'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_optimization_advice'
        description = 'Get Azure Advisor cost optimization recommendations with estimated annual savings per resource.'
        fn          = 'Get-OptimizationAdvice'
        category    = 'Advisor'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_billing_structure'
        description = 'Get billing account hierarchy and enrollment details (EA, MCA, CSP).'
        fn          = 'Get-BillingStructure'
        category    = 'Account'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_contract_info'
        description = 'Get agreement type, offer details, currency, and support plan information.'
        fn          = 'Get-ContractInfo'
        category    = 'Account'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'run_full_scan'
        description = 'Run all FinOps scan modules (optimization, governance, cost, commitments, monitoring, advisor) and return a comprehensive assessment. This is the most thorough scan — use individual tools for targeted queries.'
        fn          = '_full_scan'
        category    = 'Assessment'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
                modules        = @{ type = 'array'; items = @{ type = 'string' }; description = 'Optional list of module names to include. Omit to run all.' }
            }
        }
    }
)

# Permission requirements per tool (same as TUI)
$permissionMap = @{
    'Get-OrphanedResources'     = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Graph' }
    'Get-IdleVMs'               = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Graph + Monitor Metrics' }
    'Get-StorageTierAdvice'     = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Graph' }
    'Get-AHBOpportunities'      = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Graph' }
    'Get-TagInventory'          = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Graph' }
    'Get-TagRecommendations'    = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Graph' }
    'Get-PolicyInventory'       = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Manager' }
    'Get-PolicyRecommendations' = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Manager' }
    'Get-CostData'              = @{ role = 'Cost Management Reader'; scope = 'Subscription or Management Group'; api = 'Cost Management Query API' }
    'Get-ResourceCosts'         = @{ role = 'Cost Management Reader'; scope = 'Subscription or Management Group'; api = 'Cost Management Query API' }
    'Get-CostByTag'             = @{ role = 'Cost Management Reader'; scope = 'Subscription or Management Group'; api = 'Cost Management Query API' }
    'Get-CostTrend'             = @{ role = 'Cost Management Reader'; scope = 'Subscription or Management Group'; api = 'Cost Management Query API' }
    'Get-ReservationAdvice'     = @{ role = 'Cost Management Reader'; scope = 'Subscription'; api = 'Consumption Reservation Recommendations API' }
    'Get-CommitmentUtilization' = @{ role = 'Cost Management Reader'; scope = 'Subscription'; api = 'Consumption Reservation Summaries API' }
    'Get-SavingsRealized'       = @{ role = 'Cost Management Reader'; scope = 'Subscription'; api = 'Cost Management Benefit Utilization API' }
    'Get-BudgetStatus'          = @{ role = 'Cost Management Reader'; scope = 'Subscription'; api = 'Consumption Budgets API' }
    'Get-AnomalyAlerts'         = @{ role = 'Cost Management Reader'; scope = 'Subscription'; api = 'Cost Management Alerts API' }
    'Get-OptimizationAdvice'    = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Advisor API' }
    'Get-BillingStructure'      = @{ role = 'Billing Reader'; scope = 'Billing Account'; api = 'Billing API' }
    'Get-ContractInfo'          = @{ role = 'Billing Reader'; scope = 'Billing Account'; api = 'Billing API' }
}

# =====================================================================
#  RESOURCE DEFINITIONS
# =====================================================================
$resourceDefinitions = @(
    @{
        uri         = 'finops://permissions'
        name        = 'Permission Requirements'
        description = 'Required Azure RBAC roles for each scan module.'
        mimeType    = 'application/json'
    }
    @{
        uri         = 'finops://modules'
        name        = 'Available Scan Modules'
        description = 'List of all FinOps scan modules with descriptions and categories.'
        mimeType    = 'application/json'
    }
)

# =====================================================================
#  HELPER: RESOLVE SUBSCRIPTIONS
# =====================================================================
function Resolve-Subscriptions {
    param([string]$SubscriptionId)

    if ($SubscriptionId) {
        $sub = Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
        return @($sub)
    }

    $subs = @(Get-AzSubscription -ErrorAction Stop | Where-Object { $_.State -eq 'Enabled' })
    if ($subs.Count -eq 0) { throw 'No enabled subscriptions found. Run Connect-AzAccount first.' }
    return $subs
}

# =====================================================================
#  HELPER: INVOKE TOOL
# =====================================================================
function Invoke-McpTool {
    param(
        [string]$ToolName,
        [hashtable]$Arguments
    )

    $toolDef = $toolDefinitions | Where-Object { $_.name -eq $ToolName }
    if (-not $toolDef) { throw "Unknown tool: $ToolName" }

    $subId = if ($Arguments.subscriptionId) { $Arguments.subscriptionId } else { $null }

    # Full scan is a composite tool
    if ($toolDef.fn -eq '_full_scan') {
        return Invoke-FullScan -SubscriptionId $subId -ModuleFilter $Arguments.modules
    }

    $fn = $toolDef.fn
    $subs = Resolve-Subscriptions -SubscriptionId $subId
    $tenantId = (Get-AzContext).Tenant.Id

    # Build parameter set based on what the function accepts
    $cmdInfo = Get-Command $fn -ErrorAction Stop
    $params = @{}

    if ($cmdInfo.Parameters.ContainsKey('Subscriptions')) {
        $params['Subscriptions'] = $subs
    }
    if ($cmdInfo.Parameters.ContainsKey('TenantId') -and $tenantId) {
        $params['TenantId'] = $tenantId
    }

    # Handle chained dependencies
    if ($toolDef.requiresTagInventory) {
        $tagData = Get-TagInventory -Subscriptions $subs
        if ($fn -eq 'Get-TagRecommendations') {
            $params = @{ ExistingTags = if ($tagData.TagNames) { $tagData.TagNames } else { @{} } }
            if ($tagData.TagLocations) { $params['TagLocations'] = $tagData.TagLocations }
        }
        elseif ($fn -eq 'Get-CostByTag') {
            $params['ExistingTags'] = if ($tagData.TagNames) { $tagData.TagNames } else { @{} }
        }
    }
    if ($toolDef.requiresPolicyInventory) {
        $policyData = Get-PolicyInventory -Subscriptions $subs -TenantId $tenantId
        $params = @{ ExistingAssignments = if ($policyData.Assignments) { $policyData.Assignments } else { @() } }
    }

    # Invoke
    $result = & $fn @params

    # Add permission context to result
    $permInfo = if ($permissionMap.ContainsKey($fn)) { $permissionMap[$fn] } else { $null }

    return @{
        tool       = $ToolName
        module     = $fn
        category   = $toolDef.category
        data       = $result
        permission = $permInfo
        timestamp  = (Get-Date -Format 'o')
    }
}

# =====================================================================
#  FULL SCAN (composite tool)
# =====================================================================
function Invoke-FullScan {
    param(
        [string]$SubscriptionId,
        [string[]]$ModuleFilter
    )

    $subs = Resolve-Subscriptions -SubscriptionId $SubscriptionId
    $tenantId = (Get-AzContext).Tenant.Id

    # Determine which modules to run
    $modulesToRun = $toolDefinitions | Where-Object { $_.fn -ne '_full_scan' }
    if ($ModuleFilter -and $ModuleFilter.Count -gt 0) {
        $modulesToRun = $modulesToRun | Where-Object { $_.name -in $ModuleFilter }
    }

    $results = @{}
    $errors = @{}

    # Run Tag Inventory first (other modules depend on it)
    $tagData = $null
    $tagTool = $modulesToRun | Where-Object { $_.fn -eq 'Get-TagInventory' }
    if ($tagTool) {
        try {
            $tagData = Get-TagInventory -Subscriptions $subs
            $results['scan_tag_inventory'] = $tagData
        }
        catch { $errors['scan_tag_inventory'] = $_.Exception.Message }
    }

    # Run Policy Inventory early (policy recommendations depend on it)
    $policyData = $null
    $policyTool = $modulesToRun | Where-Object { $_.fn -eq 'Get-PolicyInventory' }
    if ($policyTool) {
        try {
            $params = @{ Subscriptions = $subs }
            if ($tenantId) { $params['TenantId'] = $tenantId }
            $policyData = Get-PolicyInventory @params
            $results['scan_policy_inventory'] = $policyData
        }
        catch { $errors['scan_policy_inventory'] = $_.Exception.Message }
    }

    # Run remaining modules
    foreach ($tool in $modulesToRun) {
        if ($tool.fn -in @('Get-TagInventory', 'Get-PolicyInventory')) { continue }

        try {
            $fn = $tool.fn
            $cmdInfo = Get-Command $fn -ErrorAction Stop
            $params = @{}

            if ($cmdInfo.Parameters.ContainsKey('Subscriptions')) { $params['Subscriptions'] = $subs }
            if ($cmdInfo.Parameters.ContainsKey('TenantId') -and $tenantId) { $params['TenantId'] = $tenantId }

            # Inject dependencies
            if ($tool.requiresTagInventory -and $tagData) {
                if ($fn -eq 'Get-TagRecommendations') {
                    $params = @{ ExistingTags = if ($tagData.TagNames) { $tagData.TagNames } else { @{} } }
                    if ($tagData.TagLocations) { $params['TagLocations'] = $tagData.TagLocations }
                }
                elseif ($fn -eq 'Get-CostByTag') {
                    $params['ExistingTags'] = if ($tagData.TagNames) { $tagData.TagNames } else { @{} }
                }
            }
            if ($tool.requiresPolicyInventory -and $policyData) {
                $params = @{ ExistingAssignments = if ($policyData.Assignments) { $policyData.Assignments } else { @() } }
            }

            $results[$tool.name] = & $fn @params
        }
        catch {
            $errors[$tool.name] = $_.Exception.Message
        }
    }

    return @{
        tool          = 'run_full_scan'
        subscriptions = @($subs | ForEach-Object { @{ id = $_.Id; name = $_.Name } })
        results       = $results
        errors        = $errors
        modulesRun    = $modulesToRun.Count
        timestamp     = (Get-Date -Format 'o')
    }
}

# =====================================================================
#  JSON-RPC MESSAGE HANDLING
# =====================================================================
function Send-JsonRpc {
    param([object]$Message)
    $json = $Message | ConvertTo-Json -Depth 20 -Compress
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()
}

function Send-Result {
    param([int]$Id, [object]$Result)
    Send-JsonRpc @{ jsonrpc = '2.0'; id = $Id; result = $Result }
}

function Send-Error {
    param([int]$Id, [int]$Code, [string]$Message)
    Send-JsonRpc @{ jsonrpc = '2.0'; id = $Id; error = @{ code = $Code; message = $Message } }
}

function Handle-Initialize {
    param([int]$Id)
    Send-Result -Id $Id -Result @{
        protocolVersion = $MCP_VERSION
        capabilities    = @{
            tools     = @{ listChanged = $false }
            resources = @{ subscribe = $false; listChanged = $false }
        }
        serverInfo = @{
            name    = $SERVER_NAME
            version = $SERVER_VERSION
        }
    }
}

function Handle-ToolsList {
    param([int]$Id)
    $tools = $toolDefinitions | ForEach-Object {
        @{
            name        = $_.name
            description = $_.description
            inputSchema = $_.inputSchema
        }
    }
    Send-Result -Id $Id -Result @{ tools = @($tools) }
}

function Handle-ToolsCall {
    param([int]$Id, [hashtable]$Params)
    $toolName = $Params.name
    $arguments = if ($Params.arguments) { $Params.arguments } else { @{} }

    try {
        $result = Invoke-McpTool -ToolName $toolName -Arguments $arguments
        $json = $result | ConvertTo-Json -Depth 20 -Compress
        Send-Result -Id $Id -Result @{
            content = @(
                @{ type = 'text'; text = $json }
            )
        }
    }
    catch {
        $errMsg = $_.Exception.Message
        # Include permission hint if available
        $toolDef = $toolDefinitions | Where-Object { $_.name -eq $toolName }
        if ($toolDef -and $permissionMap.ContainsKey($toolDef.fn)) {
            $perm = $permissionMap[$toolDef.fn]
            $errMsg += " | Required: $($perm.role) at $($perm.scope) scope ($($perm.api))"
        }
        Send-Result -Id $Id -Result @{
            content = @(
                @{ type = 'text'; text = $errMsg }
            )
            isError = $true
        }
    }
}

function Handle-ResourcesList {
    param([int]$Id)
    $resources = $resourceDefinitions | ForEach-Object {
        @{
            uri         = $_.uri
            name        = $_.name
            description = $_.description
            mimeType    = $_.mimeType
        }
    }
    Send-Result -Id $Id -Result @{ resources = @($resources) }
}

function Handle-ResourcesRead {
    param([int]$Id, [hashtable]$Params)
    $uri = $Params.uri

    switch ($uri) {
        'finops://permissions' {
            $content = $permissionMap | ConvertTo-Json -Depth 5
            Send-Result -Id $Id -Result @{
                contents = @(
                    @{ uri = $uri; mimeType = 'application/json'; text = $content }
                )
            }
        }
        'finops://modules' {
            $modules = $toolDefinitions | Where-Object { $_.fn -ne '_full_scan' } | ForEach-Object {
                @{ name = $_.name; description = $_.description; category = $_.category; function = $_.fn }
            }
            $content = $modules | ConvertTo-Json -Depth 5
            Send-Result -Id $Id -Result @{
                contents = @(
                    @{ uri = $uri; mimeType = 'application/json'; text = $content }
                )
            }
        }
        default {
            Send-Error -Id $Id -Code -32602 -Message "Unknown resource URI: $uri"
        }
    }
}

# =====================================================================
#  MAIN LOOP — Read JSON-RPC from stdin, dispatch, respond
# =====================================================================
[Console]::Error.WriteLine("FinOps Multitool MCP Server v$SERVER_VERSION starting...")

# Suppress Write-Host by redirecting the Information stream
$origInfoPref = $InformationPreference
$InformationPreference = 'SilentlyContinue'

try {
    while ($true) {
        $line = [Console]::In.ReadLine()
        if ($null -eq $line) { break }  # stdin closed
        $line = $line.Trim()
        if ($line -eq '') { continue }

        try {
            $msg = $line | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        catch {
            # Skip malformed JSON
            [Console]::Error.WriteLine("Malformed JSON-RPC: $line")
            continue
        }

        $method = $msg.method
        $id = $msg.id
        $params = if ($msg.params) { $msg.params } else { @{} }

        switch ($method) {
            'initialize'        { Handle-Initialize -Id $id }
            'initialized'       { <# notification, no response #> }
            'tools/list'        { Handle-ToolsList -Id $id }
            'tools/call'        { Handle-ToolsCall -Id $id -Params $params }
            'resources/list'    { Handle-ResourcesList -Id $id }
            'resources/read'    { Handle-ResourcesRead -Id $id -Params $params }
            'notifications/initialized' { <# notification, no response #> }
            'ping'              { Send-Result -Id $id -Result @{} }
            default {
                if ($null -ne $id) {
                    Send-Error -Id $id -Code -32601 -Message "Method not found: $method"
                }
            }
        }
    }
}
finally {
    $InformationPreference = $origInfoPref
    [Console]::Error.WriteLine("FinOps Multitool MCP Server stopped.")
}
