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

# ---------------------------------------------------------------------
# Keep stdout clean for JSON-RPC. Scan modules use Write-Host for TUI
# status and Az cmdlets emit warnings/progress — in a redirected child
# process these land on stdout and corrupt the protocol stream. Suppress
# every non-JSON stream globally and shadow Write-Host so it can never
# reach stdout. Errors (stream 2) are left intact for try/catch.
# ---------------------------------------------------------------------
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'

# Write-Host bypasses preference variables and writes straight to the
# host (= stdout when redirected). Shadow it with a function that routes
# to stderr, so module TUI output is preserved for debugging but never
# pollutes the JSON-RPC stdout stream.
function Write-Host {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ValueFromRemainingArguments)]
        [object[]]$Object,
        [switch]$NoNewline,
        [object]$Separator,
        [object]$ForegroundColor,
        [object]$BackgroundColor
    )
    if ($null -ne $Object) { [Console]::Error.WriteLine(($Object -join ' ')) }
}

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
$SERVER_VERSION = '1.2.0'

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
        name        = 'remediate_delete_orphaned_resource'
        description = "WRITE/MUTATING. Delete ONE orphaned resource found by scan_orphaned_resources. Only orphan-eligible types can ever be deleted: unattached managed disks (Microsoft.Compute/disks), dangling public IPs (Microsoft.Network/publicIPAddresses), unattached NICs (Microsoft.Network/networkInterfaces), and disk snapshots (Microsoft.Compute/snapshots) - any other type is refused. It re-reads the resource and re-verifies it is still orphaned before acting (it REFUSES if the resource is now in use). DRY-RUN by default: without apply=true it returns a preview (the exact DELETE URI plus orphan evidence) and deletes NOTHING. Deletion is IRREVERSIBLE. ALWAYS show the user the preview and obtain explicit confirmation, THEN call again with apply=true to actually delete. Requires a delete-capable role (e.g. Contributor) on the resource scope."
        fn          = 'Remove-OrphanedResource'
        category    = 'Optimization'
        inputSchema = @{
            type       = 'object'
            properties = @{
                resourceId        = @{ type = 'string'; description = 'Full ARM resource ID of the orphan to delete (e.g. /subscriptions/{guid}/resourceGroups/{rg}/providers/Microsoft.Compute/disks/{name}). Take this from scan_orphaned_resources output. Required.' }
                apply             = @{ type = 'boolean'; description = 'SAFETY GATE. Default false = dry-run preview (deletes nothing). Set true ONLY after the user has reviewed the preview and explicitly approved deleting this specific resource. Deletion is irreversible.' }
                confirmationToken = @{ type = 'string'; description = 'The token returned by the dry-run preview. OPTIONAL in Interactive mode; REQUIRED in Enforced (autonomous-safe) mode, where apply=true is rejected without the exact token from the matching preview. Single-use and short-lived.' }
            }
            required   = @('resourceId')
        }
    }
    @{
        name        = 'remediate_enable_hybrid_benefit'
        description = "WRITE/MUTATING (REVERSIBLE, savings-only). Enable Azure Hybrid Benefit on ONE VM found by scan_ahb_opportunities, applying existing Windows Server / SQL licenses to cut compute licensing cost up to ~85%. This is reversible (set licenseType back to None) and only reduces cost. Windows VMs are auto-detected (licenseType Windows_Server); for Linux you must pass an explicit RHEL_BYOS/SLES_BYOS licenseType. No-ops if AHB is already on. DRY-RUN by default: without apply=true it previews the PATCH and changes nothing. In Interactive mode apply=true works directly; in Enforced mode it also requires the confirmationToken from the preview."
        fn          = 'Enable-HybridBenefit'
        category    = 'Optimization'
        inputSchema = @{
            type       = 'object'
            properties = @{
                resourceId        = @{ type = 'string'; description = 'Full ARM resource ID of the VM (Microsoft.Compute/virtualMachines). From scan_ahb_opportunities. Required.' }
                licenseType       = @{ type = 'string'; enum = @('Windows_Server', 'Windows_Client', 'RHEL_BYOS', 'SLES_BYOS'); description = 'Optional override. Auto-detected as Windows_Server for Windows VMs; required for Linux (RHEL_BYOS/SLES_BYOS).' }
                apply             = @{ type = 'boolean'; description = 'SAFETY GATE. Default false = dry-run preview. Set true to enable AHB. Reversible, savings-only.' }
                confirmationToken = @{ type = 'string'; description = 'Token from the dry-run preview. Optional in Interactive mode; required in Enforced mode.' }
            }
            required   = @('resourceId')
        }
    }
    @{
        name        = 'remediate_deallocate_vm'
        description = "WRITE/MUTATING (REVERSIBLE). Deallocate (stop) ONE idle VM found by scan_idle_vms so it stops billing for compute. Deallocate is reversible - the VM can be started again and keeps its disks and configuration; it is NOT deleted. No-ops if the VM is already deallocated. DRY-RUN by default: without apply=true it previews the deallocate and changes nothing. In Interactive mode apply=true works directly; in Enforced mode it also requires the confirmationToken from the preview."
        fn          = 'Stop-IdleVm'
        category    = 'Optimization'
        inputSchema = @{
            type       = 'object'
            properties = @{
                resourceId        = @{ type = 'string'; description = 'Full ARM resource ID of the VM (Microsoft.Compute/virtualMachines). From scan_idle_vms. Required.' }
                apply             = @{ type = 'boolean'; description = 'SAFETY GATE. Default false = dry-run preview. Set true to deallocate. Reversible (start the VM to undo).' }
                confirmationToken = @{ type = 'string'; description = 'Token from the dry-run preview. Optional in Interactive mode; required in Enforced mode.' }
            }
            required   = @('resourceId')
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
        name                 = 'scan_tag_recommendations'
        description          = 'Analyze existing tags and recommend improvements: missing CAF standard tags, inconsistent casing, similar/duplicate names.'
        fn                   = 'Get-TagRecommendations'
        category             = 'Governance'
        requiresTagInventory = $true
        inputSchema          = @{
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
        name                    = 'scan_policy_recommendations'
        description             = 'Evaluate policy coverage gaps and recommend cost governance policies (tagging, region, SKU restrictions).'
        fn                      = 'Get-PolicyRecommendations'
        category                = 'Governance'
        requiresPolicyInventory = $true
        inputSchema             = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_cost_data'
        description = 'Get current month actual and forecasted cost per subscription. Returns spend, forecast, and currency. Uses FinOps Hub export data when available (fast); call detect_cost_data_source first to decide.'
        fn          = 'Get-CostData'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId  = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
                subscriptionIds = @{ type = 'array'; items = @{ type = 'string' }; description = 'Subset of subscription IDs to scan (for chunked progress). Overrides subscriptionId when provided.' }
                dataSource      = @{ type = 'string'; enum = @('auto', 'hub', 'api'); description = "Where to read cost data. 'auto' (default) uses a FinOps Hub or Cost Management export when it covers scope, else the live API. 'hub' forces the export fast path. 'api' forces the live Cost Management API." }
            }
        }
    }
    @{
        name        = 'scan_resource_costs'
        description = 'Get top resources by cost (actual month-to-date spend) with resource group, type, and forecast. Uses FinOps Hub export data when available (fast); call detect_cost_data_source first to decide.'
        fn          = 'Get-ResourceCosts'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId  = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
                subscriptionIds = @{ type = 'array'; items = @{ type = 'string' }; description = 'Subset of subscription IDs to scan (for chunked progress). Overrides subscriptionId when provided.' }
                dataSource      = @{ type = 'string'; enum = @('auto', 'hub', 'api'); description = "Where to read cost data. 'auto' (default) uses a FinOps Hub or Cost Management export when it covers scope, else the live API. 'hub' forces the export fast path. 'api' forces the live Cost Management API." }
            }
        }
    }
    @{
        name                 = 'scan_cost_by_tag'
        description          = 'Break down cost by tag key/value pairs. Shows spend per tag value and identifies untagged spend. Uses FinOps Hub export data when available (fast); call detect_cost_data_source first to decide.'
        fn                   = 'Get-CostByTag'
        category             = 'Cost Analysis'
        requiresTagInventory = $true
        inputSchema          = @{
            type       = 'object'
            properties = @{
                subscriptionId  = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
                subscriptionIds = @{ type = 'array'; items = @{ type = 'string' }; description = 'Subset of subscription IDs to scan (for chunked progress). Overrides subscriptionId when provided.' }
                dataSource      = @{ type = 'string'; enum = @('auto', 'hub', 'api'); description = "Where to read cost data. 'auto' (default) uses a FinOps Hub or Cost Management export when it covers scope, else the live API. 'hub' forces the export fast path. 'api' forces the live Cost Management API." }
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
        name            = 'scan_budget_history'
        description     = 'Get monthly budget vs actual history (last N months) for each configured budget. Pro-rates quarterly/annual budgets to a monthly equivalent. Runs Budget Status first to discover budgets.'
        fn              = 'Get-BudgetHistory'
        category        = 'Monitoring'
        requiresBudgets = $true
        inputSchema     = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
                monthsBack     = @{ type = 'integer'; description = 'Number of months of history to return. Default 6.' }
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
        name        = 'scan_unit_economics'
        description = 'Compute unit-economics KPIs: cost per vCPU, per GB RAM, per VM (compute) and per GB stored (storage), plus the compute/storage cost split, by dividing month-to-date amortized cost by provisioned capacity. vCPU and RAM are exact (from Compute SKU capabilities); storage GB combines managed disks with Storage-account used capacity (Azure Monitor); cost is scoped to the selected subscriptions with a per-subscription fallback.'
        fn          = 'Get-UnitEconomics'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_vm_cost_breakdown'
        description = "Decompose ONE virtual machine's full solution cost (month-to-date) into meter components - compute, OS/data disks, network egress, network infra (public IP/NIC), backup/recovery, security (Defender), monitoring/extension agents, and licensing - instead of a single rolled-up number. Resolves the VM and its associated billable resources from Azure Resource Graph, then attributes cost per meter. Uses the FinOps Hub export when available (exact egress GB); otherwise the live Cost Management API. Provide vmName (optionally resourceGroup) or a full resourceId."
        fn          = 'Get-VmCostBreakdown'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                vmName         = @{ type = 'string'; description = 'Name of the virtual machine to decompose. Use with resourceGroup if the name is not unique.' }
                resourceId     = @{ type = 'string'; description = 'Full Azure resource ID of the VM. Takes precedence over vmName when supplied.' }
                resourceGroup  = @{ type = 'string'; description = 'Resource group of the VM (disambiguates a non-unique vmName).' }
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, searches all accessible subscriptions.' }
                dataSource     = @{ type = 'string'; enum = @('auto', 'hub', 'api'); description = "Where to read cost. 'auto' (default) uses the FinOps Hub export when it covers scope (exact egress GB), else the live Cost Management API. 'hub' forces the export. 'api' forces the live API." }
            }
        }
    }
    @{
        name        = 'scan_allocate_shared_cost'
        description = "Allocate the billed cost of SHARED hub resources (ExpressRoute gateway/circuit, VPN gateway, Azure Firewall, shared bandwidth) across the spoke subscriptions that use them, and report each spoke's full solution cost (its own resources + its allocated share). Use this for hub-and-spoke showback. The cost math lives here; the GB/TB transfer split key is supplied as input - an agent can fetch per-spoke transfer from Azure Monitor / Traffic Analytics (e.g. via the Azure MCP server) and pass it as weightingValues, or fall back to a proxy (resourceCount/equal). Each shared pool is split into a fixed part (shared evenly) and a variable part (by transfer weight). Provide sharedResourceIds or sharedResourceGroup, plus the spoke subscription IDs."
        fn          = 'Get-SharedCostAllocation'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                sharedResourceIds   = @{ type = 'array'; items = @{ type = 'string' }; description = 'Full resource IDs of the shared hub resources to allocate (e.g. the ExpressRoute gateway, firewall). Either this or sharedResourceGroup is required.' }
                sharedResourceGroup = @{ type = 'string'; description = 'Resource group holding the shared resources. Used when sharedResourceIds is not supplied.' }
                spokes              = @{ type = 'array'; items = @{ type = 'string' }; description = 'Subscription IDs of the spokes that share the hub resources. Required.' }
                weightingMethod     = @{ type = 'string'; enum = @('inline', 'trafficAnalytics', 'equal', 'resourceCount'); description = "How to weight the variable split. 'inline' (default) uses weightingValues (exact GB/TB per spoke). 'trafficAnalytics' queries a Log Analytics workspace (workspaceId) for measured GB per spoke - exact, end-to-end, no manual feed. 'equal' splits evenly. 'resourceCount' uses billable resource count per spoke as a proxy estimate." }
                weightingValues     = @{ type = 'object'; description = "Map of spoke subscription id -> transfer amount (e.g. GB). Used when weightingMethod is 'inline'. Typically sourced from Traffic Analytics / Azure Monitor." }
                workspaceId         = @{ type = 'string'; description = "Log Analytics workspace GUID (customer id). Required when weightingMethod is 'trafficAnalytics'. The workspace must have Traffic Analytics / VNet flow logs." }
                lookbackDays        = @{ type = 'number'; description = "Days of transfer history to read for 'trafficAnalytics' weighting. Default 30." }
                fixedRatio          = @{ type = 'number'; description = 'Fraction of each shared pool treated as fixed (split evenly) vs variable (split by weight). 0 = all variable, 1 = all fixed. Default 0.5.' }
                subscriptionId      = @{ type = 'string'; description = 'Optional scope hint for resolving shared resources. If omitted, the spokes and shared resource scope are searched.' }
                dataSource          = @{ type = 'string'; enum = @('auto', 'hub', 'api'); description = "Where to read cost. 'auto' (default) uses the FinOps Hub export when it covers scope, else the live Cost Management API. 'hub' forces the export. 'api' forces the live API." }
            }
        }
    }
    @{
        name        = 'set_cost_allocation_rule'
        description = "WRITE/MUTATING. Create or update a NATIVE Azure Cost Management cost allocation rule so chargeback reflects a shared-cost split (typically the output of scan_allocate_shared_cost). This CHANGES how cost is charged back across subscriptions and can affect internal billing. It is DRY-RUN by default: without apply=true it returns a preview (the exact PUT URI and request body) and writes NOTHING. ALWAYS show the user the preview and obtain explicit confirmation, THEN call again with apply=true to actually write. Requires an EA enrollment or MCA billing account id and Cost Management Contributor on it. Source is one hub resource group (sourceResourceGroup) or subscription (sourceSubscriptionId); targets are the spoke subscriptions with percentages (auto-normalized to sum 100)."
        fn          = 'Set-CostAllocationRule'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                billingAccountId     = @{ type = 'string'; description = 'EA enrollment id or MCA billing account id that scopes the rule. Required.' }
                ruleName             = @{ type = 'string'; description = "Cost allocation rule name. Letters, digits, '_' and '-' only (max 260 chars). Required." }
                sourceResourceGroup  = @{ type = 'array'; items = @{ type = 'string' }; description = 'Resource group name(s) holding the shared cost to reallocate (the hub). Provide this OR sourceSubscriptionId.' }
                sourceSubscriptionId = @{ type = 'array'; items = @{ type = 'string' }; description = 'Subscription id(s) holding the shared cost to reallocate (the hub). Provide this OR sourceResourceGroup.' }
                targets              = @{ type = 'array'; items = @{ type = 'object' }; description = "Spoke targets. Each item: { subscriptionId, percentage } or { spoke, allocatedShared }. You can pass the Allocations array from scan_allocate_shared_cost (it has Spoke + AllocatedShared) and percentages are derived and normalized to sum 100. Required." }
                targetDimension      = @{ type = 'string'; enum = @('SubscriptionId', 'ResourceGroupName'); description = "Dimension the targets are keyed by. Default 'SubscriptionId'." }
                status               = @{ type = 'string'; enum = @('Active', 'NotActive'); description = "Rule status. 'Active' (default) impacts cost allocation; 'NotActive' saves it without applying." }
                description          = @{ type = 'string'; description = 'Optional rule description.' }
                apply                = @{ type = 'boolean'; description = 'SAFETY GATE. Default false = dry-run preview (writes nothing). Set true ONLY after the user has reviewed the preview and explicitly approved, to create/update the rule in Azure.' }
            }
            required   = @('billingAccountId', 'ruleName', 'targets')
        }
    }
    @{
        name        = 'scan_billing_account'
        description = "READ-ONLY. List the Azure billing accounts your identity can see and report, for each, the billing account id (the value set_cost_allocation_rule needs), the agreement type (EA / MCA / CSP / pay-as-you-go), whether it is ELIGIBLE for cost allocation rules (only EA and MCA are), and - by default - whether you can reach the cost allocation rules endpoint there (a 403 means you lack Cost Management Contributor at that scope). Run this before set_cost_allocation_rule to find the right billingAccountId and confirm access. Never writes anything."
        fn          = 'Get-BillingAccount'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                billingAccountId = @{ type = 'string'; description = 'Optional. Return only this billing account id instead of all visible ones.' }
                probeAccess      = @{ type = 'boolean'; description = 'When true (default), probe the cost allocation rules endpoint per eligible account to report read access (a 403 signals missing Cost Management Contributor). Set false to skip the extra calls.' }
            }
        }
    }
    @{
        name        = 'scan_usage_allocation'
        description = "SHOWBACK. Split the billed cost of a SHARED PLATFORM across sub-resource consumers that have NO Azure billing dimension - Kubernetes namespaces (AKS), APIM products/subscriptions (token spend), or Azure OpenAI deployments - by a usage signal read from a Log Analytics workspace. This is the answer to 'we can't get to AKS/APIM token spend easily': there is no native billing line per namespace/token, so it must be telemetry-driven. Pick a preset (aksNamespace = Container Insights CPU/mem; apimTokens = App Insights token metrics; openAiTokens = Azure Monitor Cognitive Services token metrics) or pass a custom weightingQuery returning Consumer + Weight. SHOWBACK ONLY: results are Mode=Showback with empty RuleTargets and CANNOT be written via set_cost_allocation_rule (those consumers are not EA/MCA billing dimensions). Provide the pool via sharedResourceIds/sharedResourceGroup (cost resolved) or poolAmount, plus the workspaceId."
        fn          = 'Get-UsageProportionalAllocation'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                preset              = @{ type = 'string'; enum = @('aksNamespace', 'apimTokens', 'openAiTokens', 'custom'); description = "Which shared-platform usage key to use. 'aksNamespace' splits by namespace CPU+memory (Container Insights). 'apimTokens' splits by tokens per APIM consumer (workspace-based App Insights). 'openAiTokens' splits by tokens per Azure OpenAI resource (Azure Monitor metrics). 'custom' requires weightingQuery." }
                workspaceId         = @{ type = 'string'; description = 'Log Analytics workspace GUID holding the telemetry (Container Insights workspace for AKS; the workspace backing Application Insights for APIM/OpenAI). Required.' }
                sharedResourceIds   = @{ type = 'array'; items = @{ type = 'string' }; description = 'Resource IDs whose billed cost forms the pool to split (e.g. the AKS cluster / its node pools, the APIM instance, the AOAI resource). Either this or sharedResourceGroup or poolAmount.' }
                sharedResourceGroup = @{ type = 'string'; description = 'Resource group holding the shared platform; its billed cost forms the pool.' }
                poolAmount          = @{ type = 'number'; description = 'Explicit pool cost to split instead of resolving resources (e.g. a known PTU monthly cost).' }
                lookbackDays        = @{ type = 'number'; description = 'Telemetry window in days. Default 30.' }
                dimensionName       = @{ type = 'string'; description = "Override the consumer dimension. apimTokens defaults to 'Subscription Id'; set e.g. 'API ID' or 'Product Id' to charge by API or product." }
                weightingQuery      = @{ type = 'string'; description = 'Full KQL override. Must return two columns: Consumer (string) and Weight (number). Required when preset is custom.' }
                subscriptionId      = @{ type = 'string'; description = 'Optional scope hint for resolving the shared platform resources.' }
                dataSource          = @{ type = 'string'; enum = @('auto', 'hub', 'api'); description = "Where to read the pool cost. 'auto' (default) uses the FinOps Hub export when it covers scope, else the live Cost Management API." }
            }
            required   = @('preset', 'workspaceId')
        }
    }
    @{
        name        = 'scan_ai_workloads'
        description = 'Detect AI/LLM workloads (Azure OpenAI, AI Services, Machine Learning, AI Search, GPU VMs) and, only when present, compute AI unit-economics KPIs: month-to-date token consumption (input/output) by model deployment, total Azure OpenAI requests, AI spend, effective cost per 1K tokens, and cost per request. Self-gating - returns quickly when no AI workloads exist. Reads AI spend and billed token volume from the FinOps Hub export when available (no Monitor/Cost Management calls); cost per request is only available on the live API path.'
        fn          = 'Get-AIWorkloadMetrics'
        category    = 'AI & ML'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
                dataSource     = @{ type = 'string'; enum = @('auto', 'hub', 'api'); description = "Where to read AI spend and token volume. 'auto' (default) uses the FinOps Hub export when it fully covers scope, else the live Monitor + Cost Management APIs. 'hub' forces the export (no cost-per-request). 'api' forces the live APIs." }
            }
        }
    }
    @{
        name        = 'scan_legacy_resources'
        description = 'Find legacy and retiring resources to modernize: first-generation (v1) VM families, unmanaged (VHD) disks, HDD managed disks, and Basic-SKU public IPs / load balancers (retiring Sep 2025).'
        fn          = 'Get-LegacyResources'
        category    = 'Optimization'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'scan_carbon'
        description = 'Get Azure carbon emissions (kgCO2e) from the Carbon Optimization service: latest-month total, month-over-month change, a 12-month trend, and a per-subscription breakdown. Emissions publish ~2 months in arrears.'
        fn          = 'Get-CarbonMetrics'
        category    = 'Sustainability'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions.' }
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
        name        = 'scan_macc_commitment'
        description = 'Check Microsoft Azure Consumption Commitment (MACC) status for EA/MCA billing accounts: commitment amount, consumed, remaining, percent burned, and expiration. Returns not-applicable for PAYGO/CSP/MSDN. Requires a billing role.'
        fn          = 'Get-MaccCommitment'
        category    = 'Account'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, queries all accessible subscriptions.' }
            }
        }
    }
    @{
        name        = 'detect_cost_data_source'
        description = 'Decide how cost scans should run BEFORE invoking any cost tool. Detects a FinOps Hub or any readable Cost Management (CSV) export in scope, checks whether it is readable (with a specific blocker reason if not), reports which subscriptions it covers and how fresh the data is, and estimates how long the live Cost Management API path would take. Call this first for any cost question so the fast export path can be used, or so the user can be warned and asked before a slow API scan.'
        fn          = '_detect_cost_source'
        category    = 'Cost Analysis'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, evaluates all accessible subscriptions.' }
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
                dataSource     = @{ type = 'string'; enum = @('auto', 'hub', 'api'); description = 'Cost-family data source. auto (default) uses a FinOps Hub or Cost Management export when it covers the scope, else the live Cost Management API; hub forces the export fast path; api skips the export. Governance and optimization modules always use live APIs.' }
            }
        }
    }
    @{
        name        = 'generate_powerbi_template'
        description = 'Run a full FinOps scan and generate a self-contained Power BI template (.pbit) plus the supporting CSV files. The .pbit ships a curated 4-page report (Cost Overview, Subscriptions, Optimization, Governance) whose CsvFolderPath parameter is pre-pointed at the exported folder. Returns the path to FinOps-Report.pbit.'
        fn          = '_generate_powerbi'
        category    = 'Reporting'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, scans all accessible subscriptions in the current tenant.' }
                outputDir      = @{ type = 'string'; description = 'Folder to write the CSVs and FinOps-Report.pbit into. Defaults to a timestamped folder under the user TEMP directory.' }
                dataSource     = @{ type = 'string'; enum = @('auto', 'hub', 'api'); description = 'Cost-family data source for the scan. auto (default), hub, or api.' }
            }
        }
    }
    @{
        name        = 'connect_powerbi_to_hub'
        description = 'Detect the FinOps Hub in scope and emit the exact connection parameter values to plug into the official FinOps Toolkit Power BI reports (src/power-bi). Returns the storage account, blob endpoint, ingestion container, dataset path, and which report to open. Use this when the user already has a FinOps Hub and wants the toolkit reports instead of a generated .pbit.'
        fn          = '_connect_powerbi_hub'
        category    = 'Reporting'
        inputSchema = @{
            type       = 'object'
            properties = @{
                subscriptionId = @{ type = 'string'; description = 'Target subscription ID. If omitted, evaluates all accessible subscriptions in the current tenant.' }
            }
        }
    }
    @{
        name        = 'explore_finops_kpis'
        description = 'Browse the FinOps Foundation KPIs (https://www.finops.org/finops-kpis/) that this server can inform, and learn which scan produces each one. Call with no arguments to list KPIs grouped by FinOps domain (Understand/Quantify/Optimize/Manage) with a Computable-now vs Informational flag. Call with a kpiId to get that KPI''s definition, the tool that informs it, and a plain-language explanation. Use this when a user wants to understand FinOps KPIs or map their tenant data to industry metrics. Most scan tools also attach a kpiInsights block to their own output automatically.'
        fn          = '_explore_kpis'
        category    = 'Guidance'
        inputSchema = @{
            type       = 'object'
            properties = @{
                kpiId = @{ type = 'string'; description = 'Optional KPI id (from the list) to get full detail. Omit to list all informable KPIs grouped by domain.' }
            }
        }
    }
)

# Permission requirements per tool (same as TUI)
$permissionMap = @{
    'Get-OrphanedResources'     = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Graph' }
    'Remove-OrphanedResource'   = @{ role = 'Contributor (delete)'; scope = 'Resource'; api = 'Azure Resource Manager (DELETE)' }
    'Enable-HybridBenefit'      = @{ role = 'Virtual Machine Contributor'; scope = 'Resource'; api = 'Azure Resource Manager (PATCH)' }
    'Stop-IdleVm'               = @{ role = 'Virtual Machine Contributor'; scope = 'Resource'; api = 'Azure Resource Manager (deallocate)' }
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
    'Get-BudgetHistory'         = @{ role = 'Cost Management Reader'; scope = 'Subscription'; api = 'Cost Management Query API' }
    'Get-AnomalyAlerts'         = @{ role = 'Cost Management Reader'; scope = 'Subscription'; api = 'Cost Management Alerts API' }
    'Get-OptimizationAdvice'    = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Advisor API' }
    'Get-CarbonMetrics'         = @{ role = 'Reader or Carbon Optimization Reader'; scope = 'Subscription'; api = 'Carbon Optimization API' }
    'Get-LegacyResources'       = @{ role = 'Reader'; scope = 'Subscription'; api = 'Azure Resource Graph' }
    'Get-UnitEconomics'         = @{ role = 'Cost Management Reader + Reader'; scope = 'Management Group'; api = 'Cost Management Query API + Azure Resource Graph + Azure Monitor metrics' }
    'Get-AIWorkloadMetrics'     = @{ role = 'Cost Management Reader + Reader'; scope = 'Management Group'; api = 'Azure Resource Graph + Monitor Metrics + Cost Management Query API' }
    'Get-BillingStructure'      = @{ role = 'Billing Reader'; scope = 'Billing Account'; api = 'Billing API' }
    'Get-ContractInfo'          = @{ role = 'Billing Reader'; scope = 'Billing Account'; api = 'Billing API' }
    'Get-MaccCommitment'        = @{ role = 'Billing Reader or EA Reader'; scope = 'Billing Account'; api = 'Consumption Lots API' }
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
#  HELPER: COST DATA SOURCE (HUB) CACHE
# =====================================================================
# The MCP server reads the FinOps Hub export at most once per
# subscription set, then serves spend-breakdown cost tools from that
# single read. This keeps cost scans fast and avoids repeated Cost
# Management API round-trips. Governance/optimization tools are NOT
# routed here — they always use the live Resource Graph / ARM path.
$script:McpHubCache = @{}

function Get-McpHubData {
    param(
        [Parameter(Mandatory)]
        [object[]]$Subs,
        [string]$TenantId
    )

    $key = (@($Subs.Id) | Sort-Object) -join ','
    if ($script:McpHubCache.ContainsKey($key)) { return $script:McpHubCache[$key] }

    $decision = Resolve-CostDataSource -RequestedSubscriptionIds @($Subs.Id) -TenantId $TenantId

    $raw = $null
    if ($decision.Readable -and $decision.Hub) {
        try {
            $raw = Read-FinOpsHubData -StorageAccountName $decision.Hub.Name -ResourceGroupName $decision.Hub.ResourceGroup -Months 1
        }
        catch {
            $raw = $null
        }
    }

    # No readable hub, but the resolver found a generic Cost Management
    # export covering the scope — read its CSV data (newest run per sub,
    # overlapping subs deduped) so the cost tools can serve from it.
    $exportData = $null
    if ((-not $raw -or @($raw).Count -eq 0) -and
        $decision.ExportFound -and
        $decision.Recommendation -in @('UseExport', 'UseExportPartial') -and
        (Get-Command Get-MergedCostExportData -ErrorAction SilentlyContinue)) {
        try {
            $exportData = Get-MergedCostExportData -Exports $decision.Exports
        }
        catch {
            $exportData = $null
        }
    }

    $entry = @{ Decision = $decision; Raw = $raw; ExportData = $exportData }
    $script:McpHubCache[$key] = $entry
    return $entry
}

# =====================================================================
#  HELPER: MAP FULL-SCAN RESULTS -> POWER BI SCAN-DATA SHAPE
# =====================================================================
# New-PowerBITemplate consumes the same hashtable shape the GUI keeps in
# $script:scanData. The full-scan result stores each module's raw output
# under its tool name, so the mapping is a direct key lookup.
function ConvertTo-PbiScanData {
    param([Parameter(Mandatory)][object]$FullScan)

    $r = $FullScan.results
    if (-not $r) { $r = @{} }

    return @{
        Auth          = @{
            TenantId      = (Get-AzContext).Tenant.Id
            Subscriptions = @($FullScan.subscriptions | ForEach-Object { @{ Name = $_.name; Id = $_.id } })
        }
        Costs         = $r['scan_cost_data']
        ResourceCosts = $r['scan_resource_costs']
        Tags          = $r['scan_tag_inventory']
        TagRecs       = $r['scan_tag_recommendations']
        PolicyInv     = $r['scan_policy_inventory']
        PolicyRecs    = $r['scan_policy_recommendations']
        Budgets       = $r['scan_budget_status']
        Orphans       = $r['scan_orphaned_resources']
        CostByTag     = $r['scan_cost_by_tag']
        CostTrend     = $r['scan_cost_trend']
        Commitments   = $r['scan_commitment_utilization']
        AHB           = $r['scan_ahb_opportunities']
        Optimization  = $r['scan_optimization_advice']
        Reservations  = $r['scan_reservation_advice']
        Savings       = $r['scan_savings_realized']
    }
}

# =====================================================================
#  HELPER: HUB -> OFFICIAL POWER BI REPORT CONNECTION PARAMETERS
# =====================================================================
# Shapes a Resolve-CostDataSource decision into the parameter values a
# user plugs into the FinOps Toolkit's official Power BI reports
# (src/power-bi). The Storage reports read the hub's 'ingestion'
# container; the KQL reports read the Data Explorer cluster. The exact
# clusterUri / storageUrlForPowerBI values come from the hub deployment
# Outputs, so we surface what we can infer plus where to copy the rest.
function Get-HubPbiConnection {
    param([Parameter(Mandatory)][object]$Decision)

    if (-not $Decision.HubFound -or -not $Decision.Hub) {
        return @{
            hubFound       = $false
            recommendation = 'NoHub'
            message        = 'No FinOps Hub found in scope. Deploy a FinOps Hub (https://aka.ms/finops/hubs) to use the official Power BI reports, or use generate_powerbi_template for a live-scan report.'
        }
    }

    $acct = $Decision.Hub.Name
    $storageUrl = "https://$acct.dfs.core.windows.net/ingestion"

    return @{
        hubFound         = $true
        readable         = $Decision.Readable
        recommendation   = $Decision.Recommendation
        coveragePct      = $Decision.CoveragePct
        asOf             = $Decision.Freshness
        hub              = @{
            storageAccount = $acct
            resourceGroup  = $Decision.Hub.ResourceGroup
            subscriptionId = $Decision.Hub.SubscriptionId
            location       = $Decision.Hub.Location
        }
        reportParameters = @{
            # Storage-based reports (Cost summary, Rate optimization, etc.)
            storageUrlForPowerBI = $storageUrl
            ingestionContainer   = 'ingestion'
            # KQL/ADX-based reports (Data ingestion, etc.) — copy from hub Outputs
            clusterUri           = '<copy clusterUri from the hub deployment Outputs>'
        }
        reports          = @(
            @{ name = 'Cost summary'; dataSource = 'Storage'; download = 'https://aka.ms/finops/toolkit/CostSummary.pbix' }
            @{ name = 'Rate optimization'; dataSource = 'Storage'; download = 'https://aka.ms/finops/toolkit/RateOptimization.pbix' }
            @{ name = 'Data ingestion'; dataSource = 'KQL'; download = 'https://aka.ms/finops/toolkit/DataIngestion.pbix' }
        )
        instructions     = @(
            "Download the FinOps Toolkit Power BI reports: https://aka.ms/finops/toolkit/reports",
            "Open a report in Power BI Desktop. When prompted, set 'Storage URL' to: $storageUrl",
            "For KQL reports, set 'Cluster URI' to the clusterUri value from the hub resource group's deployment Outputs.",
            "Authorize the storage source with an account that has Storage Blob Data Reader (or a SAS token).",
            "Leave 'Number of Months' empty to load all data, then Apply."
        )
        message          = $Decision.Message
    }
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

    # Targeted remediation acts on ONE resource id - it does not enumerate
    # subscriptions. Safe-by-default: dry-run unless apply=true is explicit.
    if ($toolDef.fn -eq 'Remove-OrphanedResource') {
        $rid = [string]$Arguments.resourceId
        if (-not $rid) { throw 'resourceId is required for remediate_delete_orphaned_resource.' }
        $doApply = ($Arguments.apply -eq $true)
        $confToken = if ($Arguments.confirmationToken) { [string]$Arguments.confirmationToken } else { $null }
        $remResult = Remove-OrphanedResource -ResourceId $rid -Apply:$doApply -ConfirmationToken $confToken
        return @{
            tool       = $ToolName
            module     = 'Remove-OrphanedResource'
            category   = $toolDef.category
            data       = $remResult
            source     = 'LiveApi'
            permission = if ($permissionMap.ContainsKey('Remove-OrphanedResource')) { $permissionMap['Remove-OrphanedResource'] } else { $null }
            timestamp  = (Get-Date -Format 'o')
        }
    }

    # Targeted reversible remediation (enable AHB / deallocate VM) - one
    # resource id, no subscription enumeration, routed through the gate.
    if ($toolDef.fn -in @('Enable-HybridBenefit', 'Stop-IdleVm')) {
        $rid = [string]$Arguments.resourceId
        if (-not $rid) { throw "resourceId is required for $ToolName." }
        $doApply = ($Arguments.apply -eq $true)
        $confToken = if ($Arguments.confirmationToken) { [string]$Arguments.confirmationToken } else { $null }
        $remResult = if ($toolDef.fn -eq 'Enable-HybridBenefit') {
            $lt = if ($Arguments.licenseType) { [string]$Arguments.licenseType } else { $null }
            if ($lt) { Enable-HybridBenefit -ResourceId $rid -LicenseType $lt -Apply:$doApply -ConfirmationToken $confToken }
            else { Enable-HybridBenefit -ResourceId $rid -Apply:$doApply -ConfirmationToken $confToken }
        }
        else {
            Stop-IdleVm -ResourceId $rid -Apply:$doApply -ConfirmationToken $confToken
        }
        return @{
            tool       = $ToolName
            module     = $toolDef.fn
            category   = $toolDef.category
            data       = $remResult
            source     = 'LiveApi'
            permission = if ($permissionMap.ContainsKey($toolDef.fn)) { $permissionMap[$toolDef.fn] } else { $null }
            timestamp  = (Get-Date -Format 'o')
        }
    }

    $subId = if ($Arguments.subscriptionId) { $Arguments.subscriptionId } else { $null }
    $subIdSubset = if ($Arguments.subscriptionIds) { @($Arguments.subscriptionIds) } else { $null }

    # Resolve the working subscription set, honouring an explicit subset
    # (used by the agent to chunk large tenants for incremental progress).
    $resolveSubs = {
        if ($subIdSubset) { @($subIdSubset | ForEach-Object { Get-AzSubscription -SubscriptionId $_ -ErrorAction Stop }) }
        else { Resolve-Subscriptions -SubscriptionId $subId }
    }

    # Full scan is a composite tool
    if ($toolDef.fn -eq '_full_scan') {
        $ds = if ($Arguments.dataSource) { [string]$Arguments.dataSource } else { 'auto' }
        return Invoke-FullScan -SubscriptionId $subId -ModuleFilter $Arguments.modules -DataSource $ds
    }

    # KPI catalog exploration is a static guidance helper, not a scan
    if ($toolDef.fn -eq '_explore_kpis') {
        $kpiId = if ($Arguments.kpiId) { [string]$Arguments.kpiId } else { $null }
        return @{
            tool      = $ToolName
            module    = 'Get-KpiExploration'
            category  = $toolDef.category
            data      = (Get-KpiExploration -KpiId $kpiId)
            timestamp = (Get-Date -Format 'o')
        }
    }

    # Cost data source detection is a routing helper, not a scan
    if ($toolDef.fn -eq '_detect_cost_source') {
        $subs = & $resolveSubs
        $tenantId = (Get-AzContext).Tenant.Id
        $decision = Resolve-CostDataSource -RequestedSubscriptionIds @($subs.Id) -TenantId $tenantId
        return @{
            tool      = $ToolName
            module    = 'Resolve-CostDataSource'
            category  = $toolDef.category
            data      = $decision
            timestamp = (Get-Date -Format 'o')
        }
    }

    # Power BI template generation: full scan -> CSVs + .pbit
    if ($toolDef.fn -eq '_generate_powerbi') {
        $ds = if ($Arguments.dataSource) { [string]$Arguments.dataSource } else { 'auto' }
        $scan = Invoke-FullScan -SubscriptionId $subId -DataSource $ds
        $pbiScanData = ConvertTo-PbiScanData -FullScan $scan

        $outDir = if ($Arguments.outputDir) {
            [string]$Arguments.outputDir
        }
        else {
            $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
            Join-Path ([System.IO.Path]::GetTempPath()) "FinOps-PowerBI-$stamp"
        }

        $skel = Join-Path (Join-Path $PSScriptRoot 'assets') 'skeleton.pbit'
        $built = New-PowerBITemplate -ScanData $pbiScanData -OutputDir $outDir -SkeletonPath $skel

        return @{
            tool      = $ToolName
            module    = 'New-PowerBITemplate'
            category  = $toolDef.category
            data      = @{
                pbitPath       = $built.PbitPath
                csvCount       = $built.CsvCount
                outputDir      = $built.OutputDir
                subscriptions  = $scan.subscriptions
                costDataSource = $scan.costDataSource
            }
            note      = "Open $($built.PbitPath) in Power BI Desktop. The CsvFolderPath parameter is pre-set to the exported folder; move the folder and the .pbit together or update the parameter."
            timestamp = (Get-Date -Format 'o')
        }
    }

    # Power BI hub connection: detect hub and emit toolkit-report params
    if ($toolDef.fn -eq '_connect_powerbi_hub') {
        $subs = & $resolveSubs
        $tenantId = (Get-AzContext).Tenant.Id
        $decision = Resolve-CostDataSource -RequestedSubscriptionIds @($subs.Id) -TenantId $tenantId
        return @{
            tool      = $ToolName
            module    = 'Resolve-CostDataSource'
            category  = $toolDef.category
            data      = (Get-HubPbiConnection -Decision $decision)
            timestamp = (Get-Date -Format 'o')
        }
    }

    $fn = $toolDef.fn
    $subs = & $resolveSubs
    $tenantId = (Get-AzContext).Tenant.Id

    # -----------------------------------------------------------------
    # Export-first routing for spend-breakdown cost tools. When a
    # readable FinOps Hub export covers the requested scope, serve these
    # from the export (one read, cached) instead of the Cost Management
    # API. dataSource: auto (default) | hub | api.
    #   auto -> hub only when the resolver recommends UseHub, else API
    #   hub  -> force hub (error if unreadable/empty)
    #   api  -> skip hub entirely
    # Only Get-CostData / Get-ResourceCosts / Get-CostByTag have hub
    # converters; all other cost-family tools stay on the live API.
    # -----------------------------------------------------------------
    if ($fn -in @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag')) {
        $requested = if ($Arguments.dataSource) { [string]$Arguments.dataSource } else { 'auto' }

        $hubInfo = $null
        if ($requested -ne 'api') { $hubInfo = Get-McpHubData -Subs $subs -TenantId $tenantId }

        $useHub = $false
        if ($hubInfo -and $hubInfo.Raw -and @($hubInfo.Raw).Count -gt 0) {
            if ($requested -eq 'hub') { $useHub = $true }
            elseif ($requested -eq 'auto' -and $hubInfo.Decision.Recommendation -eq 'UseHub') { $useHub = $true }
        }

        # Generic Cost Management export fast path: no hub, but a readable
        # CSV export covers the scope. Same data contract as the hub path,
        # so dataSource=hub also accepts it (it is the materialized fast path).
        $useExport = $false
        if (-not $useHub -and $hubInfo -and $hubInfo.ExportData -and @($hubInfo.ExportData.Rows).Count -gt 0) {
            $rec = $hubInfo.Decision.Recommendation
            if ($requested -eq 'hub') { $useExport = $true }
            elseif ($requested -eq 'auto' -and $rec -in @('UseExport', 'UseExportPartial')) { $useExport = $true }
        }

        if ($requested -eq 'hub' -and -not $useHub -and -not $useExport) {
            $d = if ($hubInfo) { $hubInfo.Decision } else { $null }
            $reason = if ($d) { "$($d.ReadBlocker): $($d.ReadBlockerDetail)" } else { 'no hub or export found in scope' }
            throw "Export data requested but unavailable ($reason). $($d.RemediationHint)"
        }

        if ($useHub) {
            $hubResult = switch ($fn) {
                'Get-CostData' { ConvertTo-CostDataFromHub -HubData $hubInfo.Raw }
                'Get-ResourceCosts' { ConvertTo-ResourceCostsFromHub -HubData $hubInfo.Raw }
                'Get-CostByTag' {
                    $tagInv = ConvertTo-TagInventoryFromHub -HubData $hubInfo.Raw
                    $existingTags = if ($tagInv.TagNames) { $tagInv.TagNames } else { @{} }
                    ConvertTo-CostByTagFromHub -HubData $hubInfo.Raw -ExistingTags $existingTags
                }
            }
            return @{
                tool        = $ToolName
                module      = $fn
                category    = $toolDef.category
                data        = $hubResult
                source      = 'FinOpsHub'
                asOf        = $hubInfo.Decision.Freshness
                coveragePct = $hubInfo.Decision.CoveragePct
                note        = 'Served from FinOps Hub export (billed actuals). Forecast is not included in the fast path; call with dataSource=api for live forecast.'
                permission  = if ($permissionMap.ContainsKey($fn)) { $permissionMap[$fn] } else { $null }
                timestamp   = (Get-Date -Format 'o')
            }
        }

        if ($useExport) {
            $exp = $hubInfo.ExportData
            $exportResult = switch ($fn) {
                'Get-CostData' { ConvertTo-CostDataFromExport -ExportData $exp -Subscriptions $subs }
                'Get-ResourceCosts' { ConvertTo-ResourceCostsFromExport -ExportData $exp -Subscriptions $subs }
                'Get-CostByTag' { ConvertTo-CostByTagFromExport -ExportData $exp }
            }
            return @{
                tool        = $ToolName
                module      = $fn
                category    = $toolDef.category
                data        = $exportResult
                source      = 'CostManagementExport'
                asOf        = $hubInfo.Decision.Freshness
                coveragePct = $hubInfo.Decision.CoveragePct
                note        = 'Served from a Cost Management export (billed actuals, CSV). Forecast is a linear month-to-date projection; call with dataSource=api for live forecast.'
                permission  = if ($permissionMap.ContainsKey($fn)) { $permissionMap[$fn] } else { $null }
                timestamp   = (Get-Date -Format 'o')
            }
        }
        # otherwise fall through to the live Cost Management API path below
    }

    # Build parameter set based on what the function accepts
    $cmdInfo = Get-Command $fn -ErrorAction Stop
    $params = @{}

    if ($cmdInfo.Parameters.ContainsKey('Subscriptions')) {
        $params['Subscriptions'] = $subs
    }
    if ($cmdInfo.Parameters.ContainsKey('TenantId') -and $tenantId) {
        $params['TenantId'] = $tenantId
    }

    # VM cost breakdown target args (scan_vm_cost_breakdown)
    if ($cmdInfo.Parameters.ContainsKey('VmName') -and $Arguments.vmName) {
        $params['VmName'] = [string]$Arguments.vmName
    }
    if ($cmdInfo.Parameters.ContainsKey('ResourceId') -and $Arguments.resourceId) {
        $params['ResourceId'] = [string]$Arguments.resourceId
    }
    if ($cmdInfo.Parameters.ContainsKey('ResourceGroup') -and $Arguments.resourceGroup) {
        $params['ResourceGroup'] = [string]$Arguments.resourceGroup
    }

    # Shared cost allocation args (scan_allocate_shared_cost)
    if ($cmdInfo.Parameters.ContainsKey('SharedResourceIds') -and $Arguments.sharedResourceIds) {
        $params['SharedResourceIds'] = @($Arguments.sharedResourceIds | ForEach-Object { [string]$_ })
    }
    if ($cmdInfo.Parameters.ContainsKey('SharedResourceGroup') -and $Arguments.sharedResourceGroup) {
        $params['SharedResourceGroup'] = [string]$Arguments.sharedResourceGroup
    }
    if ($cmdInfo.Parameters.ContainsKey('Spokes') -and $Arguments.spokes) {
        $params['Spokes'] = @($Arguments.spokes | ForEach-Object { [string]$_ })
    }
    if ($cmdInfo.Parameters.ContainsKey('WeightingMethod') -and $Arguments.weightingMethod) {
        $params['WeightingMethod'] = [string]$Arguments.weightingMethod
    }
    if ($cmdInfo.Parameters.ContainsKey('WeightingValues') -and $null -ne $Arguments.weightingValues) {
        $params['WeightingValues'] = $Arguments.weightingValues
    }
    if ($cmdInfo.Parameters.ContainsKey('WorkspaceId') -and $Arguments.workspaceId) {
        $params['WorkspaceId'] = [string]$Arguments.workspaceId
    }
    if ($cmdInfo.Parameters.ContainsKey('LookbackDays') -and $null -ne $Arguments.lookbackDays) {
        $params['LookbackDays'] = [int]$Arguments.lookbackDays
    }
    if ($cmdInfo.Parameters.ContainsKey('FixedRatio') -and $null -ne $Arguments.fixedRatio) {
        $params['FixedRatio'] = [double]$Arguments.fixedRatio
    }

    # Cost allocation rule write-back args (set_cost_allocation_rule).
    # apply defaults to false (dry-run) - never write unless explicitly true.
    if ($cmdInfo.Parameters.ContainsKey('BillingAccountId') -and $Arguments.billingAccountId) {
        $params['BillingAccountId'] = [string]$Arguments.billingAccountId
    }
    if ($cmdInfo.Parameters.ContainsKey('RuleName') -and $Arguments.ruleName) {
        $params['RuleName'] = [string]$Arguments.ruleName
    }
    if ($cmdInfo.Parameters.ContainsKey('SourceResourceGroup') -and $Arguments.sourceResourceGroup) {
        $params['SourceResourceGroup'] = @($Arguments.sourceResourceGroup | ForEach-Object { [string]$_ })
    }
    if ($cmdInfo.Parameters.ContainsKey('SourceSubscriptionId') -and $Arguments.sourceSubscriptionId) {
        $params['SourceSubscriptionId'] = @($Arguments.sourceSubscriptionId | ForEach-Object { [string]$_ })
    }
    if ($cmdInfo.Parameters.ContainsKey('Targets') -and $Arguments.targets) {
        $params['Targets'] = @($Arguments.targets)
    }
    if ($cmdInfo.Parameters.ContainsKey('TargetDimension') -and $Arguments.targetDimension) {
        $params['TargetDimension'] = [string]$Arguments.targetDimension
    }
    if ($cmdInfo.Parameters.ContainsKey('Status') -and $Arguments.status) {
        $params['Status'] = [string]$Arguments.status
    }
    if ($cmdInfo.Parameters.ContainsKey('Description') -and $Arguments.description) {
        $params['Description'] = [string]$Arguments.description
    }
    if ($cmdInfo.Parameters.ContainsKey('Apply') -and $Arguments.apply -eq $true) {
        $params['Apply'] = $true
    }
    if ($cmdInfo.Parameters.ContainsKey('ProbeAccess') -and $null -ne $Arguments.probeAccess) {
        $params['ProbeAccess'] = [bool]$Arguments.probeAccess
    }

    # Usage-proportional showback args (scan_usage_allocation)
    if ($cmdInfo.Parameters.ContainsKey('Preset') -and $Arguments.preset) {
        $params['Preset'] = [string]$Arguments.preset
    }
    if ($cmdInfo.Parameters.ContainsKey('PoolAmount') -and $null -ne $Arguments.poolAmount) {
        $params['PoolAmount'] = [double]$Arguments.poolAmount
    }
    if ($cmdInfo.Parameters.ContainsKey('DimensionName') -and $Arguments.dimensionName) {
        $params['DimensionName'] = [string]$Arguments.dimensionName
    }
    if ($cmdInfo.Parameters.ContainsKey('WeightingQuery') -and $Arguments.weightingQuery) {
        $params['WeightingQuery'] = [string]$Arguments.weightingQuery
    }

    # Hand the FinOps Hub export to functions that accept -HubData (e.g.
    # Get-AIWorkloadMetrics). These run their own ARG gate, so they flow
    # through the normal call path with the export injected rather than the
    # cost-family hub switch above.
    if ($cmdInfo.Parameters.ContainsKey('HubData')) {
        $aiRequested = if ($Arguments.dataSource) { [string]$Arguments.dataSource } else { 'auto' }
        if ($aiRequested -ne 'api') {
            $aiHub = Get-McpHubData -Subs $subs -TenantId $tenantId
            if ($aiHub -and $aiHub.Raw -and @($aiHub.Raw).Count -gt 0) {
                $useAiHub = ($aiRequested -eq 'hub') -or ($aiRequested -eq 'auto' -and $aiHub.Decision.Recommendation -eq 'UseHub')
                if ($useAiHub) { $params['HubData'] = $aiHub.Raw }
            }
            elseif ($aiRequested -eq 'hub') {
                $d = if ($aiHub) { $aiHub.Decision } else { $null }
                $reason = if ($d) { "$($d.ReadBlocker): $($d.ReadBlockerDetail)" } else { 'no hub found in scope' }
                throw "Hub data requested but unavailable ($reason). $($d.RemediationHint)"
            }
        }
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
    if ($toolDef.requiresBudgets) {
        # Budget history depends on Budget Status — discover budgets first
        $budgetData = Get-BudgetStatus -Subscriptions $subs
        $budgetRows = if ($budgetData.Budgets) { @($budgetData.Budgets) } else { @() }
        if ($budgetRows.Count -eq 0) {
            return @{
                tool       = $ToolName
                module     = $fn
                category   = $toolDef.category
                data       = @()
                source     = 'LiveApi'
                note       = 'No budgets configured for the requested scope; no history to report.'
                permission = if ($permissionMap.ContainsKey($fn)) { $permissionMap[$fn] } else { $null }
                timestamp  = (Get-Date -Format 'o')
            }
        }
        $params = @{ Budgets = $budgetRows }
        if ($Arguments.monthsBack) { $params['MonthsBack'] = [int]$Arguments.monthsBack }
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
        source     = 'LiveApi'
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
        [string[]]$ModuleFilter,
        [string]$DataSource = 'auto'
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

    # -----------------------------------------------------------------
    # Export-first routing for cost-family modules (mirrors single-tool
    # routing in Invoke-McpTool). Resolve the hub once; the three modules
    # with hub converters serve from the export when usable, else fall
    # through to the live Cost Management API. Governance/optimization
    # modules always use live APIs.
    #   auto -> hub only when the resolver recommends UseHub (full cover)
    #   hub  -> force hub (per-module live-API fallback if a convert fails)
    #   api  -> skip hub entirely
    # -----------------------------------------------------------------
    $costFns = @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag')
    $hubInfo = $null
    $hubUsable = $false
    if ($DataSource -ne 'api' -and ($modulesToRun | Where-Object { $_.fn -in $costFns })) {
        $hubInfo = Get-McpHubData -Subs $subs -TenantId $tenantId
        if ($hubInfo -and $hubInfo.Raw -and @($hubInfo.Raw).Count -gt 0) {
            if ($DataSource -eq 'hub') { $hubUsable = $true }
            elseif ($DataSource -eq 'auto' -and $hubInfo.Decision.Recommendation -eq 'UseHub') { $hubUsable = $true }
        }
    }

    # Generic Cost Management export fast path (no hub, readable CSV export).
    $exportUsable = $false
    if (-not $hubUsable -and $DataSource -ne 'api' -and $hubInfo -and $hubInfo.ExportData -and @($hubInfo.ExportData.Rows).Count -gt 0) {
        $rec = $hubInfo.Decision.Recommendation
        if ($DataSource -eq 'hub') { $exportUsable = $true }
        elseif ($DataSource -eq 'auto' -and $rec -in @('UseExport', 'UseExportPartial')) { $exportUsable = $true }
    }
    $hubServed = @{}

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

            # Export-first: serve cost-family modules from the hub when usable
            if ($hubUsable -and $fn -in $costFns) {
                $results[$tool.name] = switch ($fn) {
                    'Get-CostData' { ConvertTo-CostDataFromHub -HubData $hubInfo.Raw }
                    'Get-ResourceCosts' { ConvertTo-ResourceCostsFromHub -HubData $hubInfo.Raw }
                    'Get-CostByTag' {
                        $tagInv = ConvertTo-TagInventoryFromHub -HubData $hubInfo.Raw
                        $existingTags = if ($tagInv.TagNames) { $tagInv.TagNames } else { @{} }
                        ConvertTo-CostByTagFromHub -HubData $hubInfo.Raw -ExistingTags $existingTags
                    }
                }
                $hubServed[$tool.name] = $true
                continue
            }

            # Export-first: serve cost-family modules from a generic CSV export
            if ($exportUsable -and $fn -in $costFns) {
                $exp = $hubInfo.ExportData
                $results[$tool.name] = switch ($fn) {
                    'Get-CostData' { ConvertTo-CostDataFromExport -ExportData $exp -Subscriptions $subs }
                    'Get-ResourceCosts' { ConvertTo-ResourceCostsFromExport -ExportData $exp -Subscriptions $subs }
                    'Get-CostByTag' { ConvertTo-CostByTagFromExport -ExportData $exp }
                }
                $hubServed[$tool.name] = $true
                continue
            }

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
            if ($tool.requiresBudgets) {
                $budgetResult = $results['scan_budget_status']
                $budgetRows = if ($budgetResult -and $budgetResult.Budgets) { @($budgetResult.Budgets) } else { @() }
                if ($budgetRows.Count -eq 0) {
                    $results[$tool.name] = @()
                    continue
                }
                $params = @{ Budgets = $budgetRows }
            }

            $results[$tool.name] = & $fn @params
        }
        catch {
            $errors[$tool.name] = $_.Exception.Message
        }
    }

    return @{
        tool             = 'run_full_scan'
        subscriptions    = @($subs | ForEach-Object { @{ id = $_.Id; name = $_.Name } })
        results          = $results
        errors           = $errors
        modulesRun       = $modulesToRun.Count
        costDataSource   = if ($hubUsable) { 'FinOpsHub' } elseif ($exportUsable) { 'CostManagementExport' } else { 'LiveApi' }
        hubAsOf          = if ($hubUsable -or $exportUsable) { $hubInfo.Decision.Freshness } else { $null }
        hubCoveragePct   = if ($hubUsable -or $exportUsable) { $hubInfo.Decision.CoveragePct } else { $null }
        hubServedModules = @($hubServed.Keys)
        timestamp        = (Get-Date -Format 'o')
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
        serverInfo      = @{
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
        # Redirect non-error streams (warning/verbose/debug/information) to
        # $null so nothing from module execution leaks onto stdout. The
        # function's return value (stream 1) still flows into $result.
        $result = Invoke-McpTool -ToolName $toolName -Arguments $arguments 3>$null 4>$null 5>$null 6>$null
        # Attach FinOps KPI correlations (additive; no-op for tools with no mapping)
        try { $result = Add-KpiInsights -Result $result } catch { }
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
            'initialize' { Handle-Initialize -Id $id }
            'initialized' { <# notification, no response #> }
            'tools/list' { Handle-ToolsList -Id $id }
            'tools/call' { Handle-ToolsCall -Id $id -Params $params }
            'resources/list' { Handle-ResourcesList -Id $id }
            'resources/read' { Handle-ResourcesRead -Id $id -Params $params }
            'notifications/initialized' { <# notification, no response #> }
            'ping' { Send-Result -Id $id -Result @{} }
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
