###########################################################################
# INITIALIZE-SCANNER.PS1
# AZURE FINOPS MULTITOOL - Authentication & Prerequisites
###########################################################################
# Purpose: Validate required Az modules, authenticate to Azure, and return
#          tenant context for the scanner to operate against.
###########################################################################

function Show-TenantPicker {
    param([object[]]$Tenants)

    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue

    $pickerXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Select Tenant" Width="520" Height="420"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#F0F0F0" FontFamily="Segoe UI">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Select the tenant to scan:" FontSize="14" FontWeight="SemiBold"
                   Foreground="#333" Margin="0,0,0,12"/>
        <ListBox Grid.Row="1" Name="TenantList" FontSize="13" Margin="0,0,0,12"
                 BorderBrush="#CCC" BorderThickness="1"/>
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="OkBtn" Content="Select" Width="90" Height="32" FontSize="13" FontWeight="SemiBold"
                    Background="#0078D4" Foreground="White" BorderThickness="0" Margin="0,0,8,0" IsEnabled="False"/>
            <Button Name="CancelBtn" Content="Cancel" Width="90" Height="32" FontSize="13"
                    Background="White" Foreground="#333" BorderBrush="#CCC" BorderThickness="1"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $rdr = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($pickerXaml))
    $dlg = [System.Windows.Markup.XamlReader]::Load($rdr)

    $list      = $dlg.FindName('TenantList')
    $okBtn     = $dlg.FindName('OkBtn')
    $cancelBtn = $dlg.FindName('CancelBtn')

    foreach ($t in $Tenants) {
        $envTag = if ($t.PSObject.Properties['Environment']) { $t.Environment } else { '' }
        $envLabel = switch ($envTag) {
            'AzureUSGovernment' { ' [GOV]' }
            'AzureCloud'        { ' [Commercial]' }
            default             { '' }
        }
        $display = if ($t.Name -and $t.Name -ne $t.TenantId) { "$($t.Name)$envLabel  ($($t.TenantId))" } else { "$($t.TenantId)$envLabel" }
        $item = [System.Windows.Controls.ListBoxItem]::new()
        $item.Content = $display
        $item.Tag = "$($t.TenantId)|$envTag"
        $list.Items.Add($item) | Out-Null
    }

    $list.Add_SelectionChanged({ $okBtn.IsEnabled = ($list.SelectedItem -ne $null) })
    $list.Add_MouseDoubleClick({ if ($list.SelectedItem) { $dlg.DialogResult = $true; $dlg.Close() } })
    $okBtn.Add_Click({ $dlg.DialogResult = $true; $dlg.Close() })
    $cancelBtn.Add_Click({ $dlg.DialogResult = $false; $dlg.Close() })

    if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }

    $picked = $dlg.ShowDialog()
    if ($picked -and $list.SelectedItem) {
        $parts = $list.SelectedItem.Tag -split '\|', 2
        return [PSCustomObject]@{ TenantId = $parts[0]; Environment = $parts[1] }
    }
    return $null
}

function Initialize-Scanner {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('AzureCloud', 'AzureUSGovernment', 'AzureChinaCloud', 'AzureGermanCloud', '')]
        [string]$Environment = '',

        [Parameter()]
        [System.Windows.Window]$ParentWindow,

        [Parameter()]
        [switch]$IncludeAlternateCloud
    )

    $requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.ResourceGraph', 'Az.CostManagement', 'Az.Advisor', 'Az.Billing')
    $missing = @()

    foreach ($mod in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            $missing += $mod
        }
    }

    if ($missing.Count -gt 0) {
        throw "Missing required modules: $($missing -join ', '). Run: Install-Module $($missing -join ', ') -Scope CurrentUser"
    }

    # Check for existing session and auto-detect environment
    $ctx = Get-AzContext -ErrorAction SilentlyContinue

    # If caller specified an environment, use it; otherwise detect from session
    if (-not $Environment) {
        if ($ctx) {
            $Environment = $ctx.Environment.Name
            Write-Host "  Detected Azure environment: $Environment" -ForegroundColor Cyan
        } else {
            $Environment = 'AzureCloud'
        }
    }

    # Disable the new Az login experience subscription picker (Az.Accounts 12+)
    # so Connect-AzAccount goes straight through without console prompts
    $env:AZURE_LOGIN_EXPERIENCE_V2 = 'Off'

    # Reuse existing session if one exists in the target cloud; otherwise prompt login
    if ($ctx -and $ctx.Account -and $ctx.Environment.Name -eq $Environment) {
        Write-Host "  Using existing Azure session: $($ctx.Account.Id) ($Environment)" -ForegroundColor Cyan
    } else {
        Write-Host "  Authenticating to Azure ($Environment)..." -ForegroundColor Cyan
        if ($ParentWindow) { $ParentWindow.WindowState = 'Minimized' }
        try {
            Connect-AzAccount -Environment $Environment -ErrorAction Stop | Out-Null
        } finally {
            if ($ParentWindow) { $ParentWindow.WindowState = 'Normal'; $ParentWindow.Activate() }
        }
        $ctx = Get-AzContext
    }

    # List all accessible tenants across environments
    Write-Host "  Loading accessible tenants..." -ForegroundColor Cyan
    $allTenants = [System.Collections.Generic.List[object]]::new()
    $seenTenantIds = @{}

    # Get tenants from current environment
    $tenants = @(Get-AzTenant -ErrorAction SilentlyContinue)
    foreach ($t in $tenants) {
        $t | Add-Member -NotePropertyName 'Environment' -NotePropertyValue $Environment -Force
        $allTenants.Add($t)
        $seenTenantIds[$t.TenantId] = $true
    }

    # Probe the alternate environment for additional tenants (opt-in only)
    if ($IncludeAlternateCloud) {
        $altEnv = if ($Environment -eq 'AzureCloud') { 'AzureUSGovernment' } else { 'AzureCloud' }
        try {
            Write-Host "  Checking $altEnv for additional tenants..." -ForegroundColor Cyan
            if ($ParentWindow) { $ParentWindow.WindowState = 'Minimized' }
            Connect-AzAccount -Environment $altEnv -ErrorAction Stop | Out-Null
            if ($ParentWindow) { $ParentWindow.WindowState = 'Normal'; $ParentWindow.Activate() }
            $altTenants = @(Get-AzTenant -ErrorAction SilentlyContinue)
            foreach ($t in $altTenants) {
                if (-not $seenTenantIds.ContainsKey($t.TenantId)) {
                    $t | Add-Member -NotePropertyName 'Environment' -NotePropertyValue $altEnv -Force
                    $allTenants.Add($t)
                    $seenTenantIds[$t.TenantId] = $true
                }
            }
            # Switch back to original environment context
            Connect-AzAccount -Environment $Environment -ErrorAction SilentlyContinue | Out-Null
        } catch {
            Write-Host "  No additional tenants found in $altEnv" -ForegroundColor DarkGray
            if ($ParentWindow) { $ParentWindow.WindowState = 'Normal'; $ParentWindow.Activate() }
        }
    }

    if ($allTenants.Count -eq 0) {
        throw "No accessible tenants found."
    }

    # Always show tenant picker (even with 1 tenant, let user confirm)
    $selection = Show-TenantPicker -Tenants $allTenants
    if (-not $selection) {
        throw "Tenant selection cancelled."
    }

    $selectedTenantId = $selection.TenantId
    $selectedEnv = if ($selection.Environment) { $selection.Environment } else { $Environment }

    # Switch to the selected tenant - use Set-AzContext if same cloud, full Connect if different
    if ($selectedTenantId -ne $ctx.Tenant.Id -or $selectedEnv -ne $ctx.Environment.Name) {
        Write-Host "  Switching to tenant $selectedTenantId ($selectedEnv)..." -ForegroundColor Cyan
        if ($ParentWindow) { $ParentWindow.WindowState = 'Minimized' }
        try {
            Connect-AzAccount -Environment $selectedEnv -TenantId $selectedTenantId -ErrorAction Stop | Out-Null
        } finally {
            if ($ParentWindow) { $ParentWindow.WindowState = 'Normal'; $ParentWindow.Activate() }
        }
    } else {
        # Same tenant selected - explicitly set context to be safe
        Write-Host "  Confirming context for tenant $selectedTenantId..." -ForegroundColor Cyan
        Set-AzContext -TenantId $selectedTenantId -ErrorAction SilentlyContinue | Out-Null
    }
    $ctx = Get-AzContext

    # Verify the context actually landed on the right tenant
    if ($ctx.Tenant.Id -ne $selectedTenantId) {
        throw "Context mismatch: expected tenant $selectedTenantId but got $($ctx.Tenant.Id). Try closing all PowerShell sessions and re-running."
    }

    $tenantId = $ctx.Tenant.Id
    $accountName = $ctx.Account.Id

    # Get all accessible subscriptions
    $subscriptions = @(Get-AzSubscription -TenantId $tenantId -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Enabled' })

    # Categorize subscriptions: separate VS/MSDN/DevTest/Free subs
    # These have spending limits, often fail Cost Management APIs, and
    # looping through hundreds of them in a large tenant wastes hours.
    $prodSubs = [System.Collections.Generic.List[object]]::new()
    $skippedSubs = [System.Collections.Generic.List[object]]::new()

    $skipPatterns = @(
        'Visual Studio', 'MSDN',
        'Free Trial', 'Sponsorship', 'Access to Azure Active Directory',
        'Azure Pass', 'BizSpark', 'Imagine', 'MPN', 'Azure in Open'
    )
    $skipRegex = ($skipPatterns | ForEach-Object { [regex]::Escape($_) }) -join '|'

    foreach ($sub in $subscriptions) {
        if ($sub.Name -match $skipRegex) {
            [void]$skippedSubs.Add($sub)
        } else {
            [void]$prodSubs.Add($sub)
        }
    }

    if ($skippedSubs.Count -gt 0) {
        Write-Host "  Subscriptions: $($prodSubs.Count) production, $($skippedSubs.Count) skipped (VS/MSDN/DevTest/Free)" -ForegroundColor Yellow
    }

    # Classify tenant size for adaptive scan strategies
    $tenantSize = if ($prodSubs.Count -le 10) { 'Small' }
                  elseif ($prodSubs.Count -le 50) { 'Medium' }
                  else { 'Large' }
    $sizeNote = switch ($tenantSize) {
        'Small'  { "fast scan mode" }
        'Medium' { "standard scan mode" }
        'Large'  { "optimized scan mode (sampling + Resource Graph)" }
    }
    Write-Host "  Tenant size: $tenantSize ($($prodSubs.Count) subs) - $sizeNote" -ForegroundColor Cyan

    return [PSCustomObject]@{
        TenantId         = $tenantId
        AccountName      = $accountName
        Subscriptions    = @($prodSubs)
        AllSubscriptions = $subscriptions
        SkippedSubs      = @($skippedSubs)
        Environment      = $ctx.Environment.Name
        TenantSize       = $tenantSize
    }
}
