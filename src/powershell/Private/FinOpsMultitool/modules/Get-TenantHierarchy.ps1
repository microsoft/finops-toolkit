###########################################################################
# GET-TENANTHIERARCHY.PS1
# AZURE FINOPS MULTITOOL - Management Group & Subscription Hierarchy
###########################################################################
# Purpose: Retrieve the full management group tree with subscriptions
#          nested under their parent groups.
###########################################################################

function Get-TenantHierarchy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter()]
        [object[]]$Subscriptions,

        [Parameter()]
        [int]$TimeoutSeconds = 60
    )

    try {
        # Run in a background runspace with timeout to prevent UI freeze
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript({
            param($tid)
            Get-AzManagementGroup -GroupId $tid -Expand -Recurse -ErrorAction Stop
        }).AddArgument($TenantId)

        $asyncResult = $ps.BeginInvoke()
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

        # Pump WPF dispatcher while waiting so the UI stays responsive
        while (-not $asyncResult.IsCompleted -and (Get-Date) -lt $deadline) {
            try {
                $frame = [System.Windows.Threading.DispatcherFrame]::new()
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                    [System.Windows.Threading.DispatcherPriority]::Background,
                    [action]{ $frame.Continue = $false }
                )
                [System.Windows.Threading.Dispatcher]::PushFrame($frame)
            } catch { }
            Start-Sleep -Milliseconds 100
        }

        if ($asyncResult.IsCompleted) {
            $rootGroup = $ps.EndInvoke($asyncResult)
            if ($ps.Streams.Error.Count -gt 0) {
                throw $ps.Streams.Error[0].Exception
            }
            $ps.Dispose(); $rs.Close()

            if ($rootGroup) {
                $actual = if ($rootGroup -is [array]) { $rootGroup[0] } else { $rootGroup }
                $subMap = @{}
                Build-SubMap -Group $actual -Map ([ref]$subMap)
                return [PSCustomObject]@{
                    RootGroup       = $actual
                    SubscriptionMap = $subMap
                }
            }
        } else {
            # Timed out — stop and fall through to fallback
            $ps.Stop()
            $ps.Dispose(); $rs.Close()
            Write-Warning "Management group hierarchy timed out after $TimeoutSeconds seconds. Using flat subscription list."
        }

        # Fallback
        $subs = if ($Subscriptions) { @($Subscriptions) } else {
            @(Get-AzSubscription -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Enabled' })
        }
        $fallbackRoot = [PSCustomObject]@{
            DisplayName = "Tenant Root"
            Name        = $TenantId
            Children    = @()
        }
        return [PSCustomObject]@{
            RootGroup       = $fallbackRoot
            SubscriptionMap = @{}
            FlatSubs        = $subs
        }
    } catch {
        Write-Warning "Failed to load management group hierarchy: $($_.Exception.Message)"
        Write-Warning "Falling back to flat subscription list."

        $subs = if ($Subscriptions) { @($Subscriptions) } else {
            @(Get-AzSubscription -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Enabled' })
        }
        $fallbackRoot = [PSCustomObject]@{
            DisplayName = "Tenant Root"
            Name        = $TenantId
            Children    = @()
        }

        return [PSCustomObject]@{
            RootGroup       = $fallbackRoot
            SubscriptionMap = @{}
            FlatSubs        = $subs
        }
    }
}

function Build-SubMap {
    param(
        [object]$Group,
        [ref]$Map
    )

    if ($Group.Children) {
        foreach ($child in $Group.Children) {
            if ($child.Type -eq '/subscriptions') {
                $Map.Value[$child.Name] = $Group.DisplayName
            }
            elseif ($child.Children) {
                Build-SubMap -Group $child -Map $Map
            }
        }
    }
}
