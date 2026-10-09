# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Opens a Power BI project in Power BI Desktop, refreshes it, and saves it as a PBIX file.

    .DESCRIPTION
    Automates the one release step that needs Power BI Desktop: saving demo reports with data.

    1. Opens the project in Power BI Desktop.
    2. Refreshes the data model through the local Analysis Services engine that Power BI Desktop
       runs, so refresh errors are reported instead of silently saving an empty report.
    3. Applies the sensitivity label, when Power BI Desktop offers one.
    4. Saves the report as a PBIX file with Save as.
    5. Closes Power BI Desktop.

    This uses Windows UI Automation to drive Power BI Desktop, which only runs on Windows. If a step
    can't be automated, the script stops with a message that says which step failed and saves a
    screenshot next to the destination file. Save that project by hand and rerun Package-PowerBI.

    Run Package-PowerBI -Unattended instead of calling this directly. It saves every project that
    still needs to be saved, validates the result, and packages PowerBI-demo.zip.

    .PARAMETER Path
    Required. Path to the PBIP file to open.

    .PARAMETER Destination
    Optional. Path of the PBIX file to save. Default = the PBIP path with a .pbix extension.

    .PARAMETER SensitivityLabel
    Optional. Name of the sensitivity label to apply, when the tenant has labels. Skipped when Power BI Desktop doesn't offer any. Default = "Public".

    .PARAMETER TimeoutMinutes
    Optional. Maximum number of minutes to wait for Power BI Desktop to open and refresh the report. Default = 30.

    .PARAMETER SkipRefresh
    Optional. Saves the report without refreshing data. Default = false.

    .EXAMPLE
    ./Save-PowerBIProject ../../release/pbix/CostSummary.storage.pbip

    Refreshes the Cost summary demo project and saves it as CostSummary.storage.pbix.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-save-powerbiproject
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]
    $Path,

    [string]
    $Destination,

    [string]
    $SensitivityLabel = 'Public',

    [int]
    $TimeoutMinutes = 30,

    [switch]
    $SkipRefresh
)

$ErrorActionPreference = 'Stop'

if ($null -ne $IsWindows -and -not $IsWindows)
{
    throw 'Power BI Desktop only runs on Windows. Run this command on Windows or save the project by hand.'
}

$Path = (Resolve-Path $Path).Path
if (-not $Destination) { $Destination = [System.IO.Path]::ChangeExtension($Path, '.pbix') }
$Destination = [System.IO.Path]::GetFullPath($Destination)
$reportLabel = [System.IO.Path]::GetFileNameWithoutExtension($Path)
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing, System.IO.Compression.FileSystem

Add-Type -Namespace FinOpsToolkit -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
[DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
'@ -ErrorAction SilentlyContinue

$uia = [System.Windows.Automation.AutomationElement]
$tree = [System.Windows.Automation.TreeScope]
$props = [System.Windows.Automation.AutomationElement]
$types = [System.Windows.Automation.ControlType]

#region Helpers

function Write-Step([string] $Message)
{
    Write-Host "    $Message"
}

function Wait-Until([scriptblock] $Condition, [string] $Description, [int] $Seconds = 0)
{
    $until = if ($Seconds -gt 0) { (Get-Date).AddSeconds($Seconds) } else { $deadline }
    while ((Get-Date) -lt $until)
    {
        $result = & $Condition
        if ($result) { return $result }
        Start-Sleep -Milliseconds 500
    }
    throw "Timed out waiting for $Description."
}

function Get-ProcessWindow([int] $ProcessId)
{
    $condition = New-Object System.Windows.Automation.PropertyCondition($props::ProcessIdProperty, $ProcessId)
    return @($uia::RootElement.FindAll($tree::Children, $condition))
}

function Find-Element($Root, [string] $Name, [System.Windows.Automation.ControlType[]] $ControlTypes, [string] $AutomationId)
{
    if (-not $Root) { return $null }

    $conditions = New-Object System.Collections.Generic.List[System.Windows.Automation.Condition]
    if ($Name) { $conditions.Add((New-Object System.Windows.Automation.PropertyCondition($props::NameProperty, $Name))) }
    if ($AutomationId) { $conditions.Add((New-Object System.Windows.Automation.PropertyCondition($props::AutomationIdProperty, $AutomationId))) }

    $condition = if ($conditions.Count -eq 1) { $conditions[0] } else { New-Object System.Windows.Automation.AndCondition($conditions.ToArray()) }
    foreach ($element in @($Root.FindAll($tree::Descendants, $condition)))
    {
        if (-not $ControlTypes -or $ControlTypes -contains $element.Current.ControlType)
        {
            if (-not $element.Current.IsOffscreen) { return $element }
        }
    }
    return $null
}

<#
    .SYNOPSIS
    Finds a control in a file dialog by automation id and window class.

    .DESCRIPTION
    The Windows file dialog reports almost everything as a pane, so control types can't be used to
    tell its parts apart. Ids aren't unique either: the file name box and the address bar are both
    1001, and only their window class separates them.
#>
function Find-DialogElement($Dialog, [string] $AutomationId, [string] $ClassName)
{
    $condition = New-Object System.Windows.Automation.PropertyCondition($props::AutomationIdProperty, $AutomationId)
    return @($Dialog.FindAll($tree::Descendants, $condition)) `
    | Where-Object { -not $ClassName -or $_.Current.ClassName -eq $ClassName } `
    | Select-Object -First 1
}

function Invoke-Element($Element)
{
    $attempts = @(
        @{ Pattern = [System.Windows.Automation.InvokePattern]::Pattern; Action = { param($p) $p.Invoke() } }
        @{ Pattern = [System.Windows.Automation.SelectionItemPattern]::Pattern; Action = { param($p) $p.Select() } }
        @{ Pattern = [System.Windows.Automation.ExpandCollapsePattern]::Pattern; Action = { param($p) $p.Expand() } }
        @{ Pattern = [System.Windows.Automation.TogglePattern]::Pattern; Action = { param($p) $p.Toggle() } }
    )
    foreach ($attempt in $attempts)
    {
        $pattern = $null
        if (-not $Element.TryGetCurrentPattern($attempt.Pattern, [ref]$pattern)) { continue }

        # A control can report a pattern and still refuse it, so the next one is tried instead
        try { & $attempt.Action $pattern; return }
        catch { Write-Verbose "  $($attempt.Pattern.ProgrammaticName) failed: $($_.Exception.Message)" }
    }

    # Some Power BI Desktop controls only respond to a real click
    $rect = $Element.Current.BoundingRectangle
    $x = [int]($rect.X + $rect.Width / 2)
    $y = [int]($rect.Y + $rect.Height / 2)
    [FinOpsToolkit.NativeMethods]::SetCursorPos($x, $y) | Out-Null
    [FinOpsToolkit.NativeMethods]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero) # left down
    [FinOpsToolkit.NativeMethods]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero) # left up
}

function Send-KeyInput($Window, [string] $Keys)
{
    [FinOpsToolkit.NativeMethods]::SetForegroundWindow([IntPtr]$Window.Current.NativeWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 300
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
}

<#
    .SYNOPSIS
    Writes what a window contains to a file, so a control that moved can be found without guessing.
#>
function Save-WindowTree($Window, [string] $Path)
{
    try
    {
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add("$($Window.Current.Name) [$($Window.Current.ClassName)]")
        foreach ($element in @($Window.FindAll($tree::Descendants, [System.Windows.Automation.Condition]::TrueCondition)))
        {
            $current = $element.Current
            $lines.Add("  $($current.ControlType.ProgrammaticName -replace '^ControlType\.', '')  name='$($current.Name)'  id='$($current.AutomationId)'  class='$($current.ClassName)'  enabled=$($current.IsEnabled)")
        }
        [System.IO.File]::WriteAllLines($Path, $lines)
        Write-Host "    Saved what the dialog contains: $Path"
    }
    catch { Write-Verbose "Could not write the window tree: $($_.Exception.Message)" }
}

function Save-Screenshot([string] $Reason)
{
    try
    {
        $screenshot = [System.IO.Path]::ChangeExtension($Destination, '.error.png')
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $bitmap.Save($screenshot, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose()
        $bitmap.Dispose()
        Write-Host "    Saved a screenshot of the failure: $screenshot"
    }
    catch
    {
        Write-Verbose "Could not save a screenshot for '$Reason': $($_.Exception.Message)"
    }
}

function Stop-Desktop([System.Diagnostics.Process] $Process)
{
    if (-not $Process -or $Process.HasExited) { return }

    Get-CimInstance Win32_Process -Filter "ParentProcessId = $($Process.Id)" -ErrorAction SilentlyContinue `
    | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
}

function Import-TabularLibrary
{
    if ('Microsoft.AnalysisServices.Tabular.Server' -as [type]) { return }

    if (-not (Get-Package Microsoft.AnalysisServices -ErrorAction SilentlyContinue))
    {
        Write-Verbose 'Installing the Analysis Services package...'
        Install-Package -Name Microsoft.AnalysisServices -ProviderName NuGet -Scope CurrentUser -Force | Out-Null
    }
    $script:TabularDllPath = "$((Get-Item (Get-Package Microsoft.AnalysisServices).Source).Directory)/lib/net8.0/Microsoft.AnalysisServices.Tabular.dll"
    Add-Type -Path $script:TabularDllPath
}

<#
    .SYNOPSIS
    Reports Power BI Desktop windows that are waiting for someone to answer them.

    .DESCRIPTION
    Power BI Desktop asks for data source credentials the first time it reads a source, including
    anonymous ones like a file on GitHub. Nothing here can answer those, and the refresh just
    stops until someone does, so each one is named as it appears.
#>
<#
    .SYNOPSIS
    Runs a TMSL command against the Power BI Desktop engine and reports what it's waiting on.

    .DESCRIPTION
    Engine commands block until they finish, so they run on their own thread. That leaves this
    one free to report credential prompts and to give up at the deadline instead of hanging.
#>
function Invoke-EngineCommand([string] $Command, [string] $Description, [int] $Port, $MainWindow, $Process, $Database)
{
    $worker = [powershell]::Create()
    $null = $worker.AddScript({
            param($DllPath, $Port, $Command)
            Add-Type -Path $DllPath
            $server = New-Object Microsoft.AnalysisServices.Tabular.Server
            $server.Connect("Data Source=localhost:$Port")
            try { return @($server.Execute($Command) | ForEach-Object { $_.Messages } | Where-Object { $_.GetType().Name -eq 'XmlaError' } | ForEach-Object { $_.Description }) }
            finally { $server.Disconnect() }
        }).AddArgument($script:TabularDllPath).AddArgument($Port).AddArgument($Command)

    $reported = New-Object System.Collections.Generic.HashSet[string]
    $handle = $worker.BeginInvoke()
    $lastProgress = Get-Date
    try
    {
        while (-not $handle.AsyncWaitHandle.WaitOne(2000))
        {
            Show-PendingPrompt $MainWindow $Process.Id $reported

            # Power BI Desktop shows a "Refresh now" banner the whole time an engine refresh runs,
            # because it isn't driving it. Table states don't help either: the refresh is one
            # transaction, so every table stays NoData until it commits. What the engine process
            # is consuming is the signal that work is happening.
            if (((Get-Date) - $lastProgress).TotalSeconds -ge 30)
            {
                $lastProgress = Get-Date
                $engine = Get-Process msmdsrv -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 1
                if ($engine)
                {
                    $elapsed = [int]((Get-Date) - $started).TotalMinutes
                    Write-Step "Still loading: engine has used $([int]$engine.CPU)s CPU and $([int]($engine.WorkingSet64 / 1MB)) MB ($elapsed min elapsed)..."
                }
            }
            if ((Get-Date) -ge $deadline)
            {
                $worker.Stop()
                throw "$Description didn't finish within $TimeoutMinutes minutes.$(if ($reported.Count -gt 0) { " It was waiting on: $($reported -join ', ')" })"
            }
        }

        $errors = @($worker.EndInvoke($handle))
        if ($reported.Count -gt 0) { Write-Step "Continuing after $($reported.Count) prompt$(if ($reported.Count -ne 1) { 's' })..." }
        return , $errors
    }
    finally { $worker.Dispose() }
}

function Show-PendingPrompt($MainWindow, [int] $ProcessId, [System.Collections.Generic.HashSet[string]] $Reported)
{
    foreach ($window in @(Get-ProcessWindow $ProcessId))
    {
        if ($MainWindow -and $window.Current.NativeWindowHandle -eq $MainWindow.Current.NativeWindowHandle) { continue }

        $name = $window.Current.Name
        if (-not $name) { continue }

        # Either a known prompt title or any dialog offering to connect or sign in
        $isPrompt = $name -match "(?i)sign in|sign-in|credential|authenticat|your account|access web content|connect to"
        if (-not $isPrompt)
        {
            $isPrompt = [bool](@('Connect', 'Sign in') | Where-Object { Find-Element $window $_ @($types::Button) } | Select-Object -First 1)
        }
        if (-not $isPrompt) { continue }

        if ($Reported.Add($name))
        {
            Write-Host ''
            Write-Host "    ⚠️ ACTION NEEDED: Power BI Desktop is waiting on '$name'." -ForegroundColor Yellow
            Write-Host '       Answer it in that window. Everything continues on its own afterward.' -ForegroundColor Yellow
            Write-Host ''
        }
    }
}

<#
    .SYNOPSIS
    Finds the port of the Analysis Services engine that a Power BI Desktop process started.
#>
function Get-DesktopEnginePort([int] $ProcessId)
{
    $engine = Get-CimInstance Win32_Process -Filter "Name = 'msmdsrv.exe' AND ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $engine)
    {
        # Fall back to the newest engine started after this script opened the report
        $engine = Get-CimInstance Win32_Process -Filter "Name = 'msmdsrv.exe'" -ErrorAction SilentlyContinue `
        | Where-Object { $_.CreationDate -ge $started } `
        | Sort-Object CreationDate -Descending `
        | Select-Object -First 1
    }
    if (-not $engine -or $engine.CommandLine -notmatch '-s\s+"(?<dir>[^"]+)"') { return $null }

    $portFile = Join-Path $Matches.dir 'msmdsrv.port.txt'
    if (-not (Test-Path $portFile)) { return $null }

    # The port file is written as UTF-16LE
    $port = ([System.IO.File]::ReadAllText($portFile, [System.Text.Encoding]::Unicode) -replace '[^0-9]', '')
    if ($port) { return [int]$port }
    return $null
}

#endregion Helpers

$desktop = $null
$server = $null
$started = Get-Date

try
{
    #region Open

    Write-Step "Opening $reportLabel in Power BI Desktop..."

    # Saving as the wrong type writes folders named after the PBIX. Those block the next save, so
    # anything named after the destination is cleared first. The project itself is named
    # differently (CostSummary.storage.Report, not CostSummary.storage.pbix.Report) and is kept.
    $destinationName = [System.IO.Path]::GetFileName($Destination)
    Get-ChildItem ([System.IO.Path]::GetDirectoryName($Destination)) -Force -ErrorAction SilentlyContinue `
    | Where-Object { $_.Name -eq $destinationName -or $_.Name -like "$destinationName.*" } `
    | ForEach-Object {
        if ($_.PSIsContainer) { Write-Verbose "  Removing $($_.Name), left over from a save that wrote a project instead of a file." }
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item ([System.IO.Path]::ChangeExtension($Destination, '.error.png')) -Force -ErrorAction SilentlyContinue
    Remove-Item ([System.IO.Path]::ChangeExtension($Destination, '.dialog.txt')) -Force -ErrorAction SilentlyContinue

    $existing = @(Get-Process PBIDesktop -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    Start-Process -FilePath $Path

    # Use the file association so the installed and Microsoft Store versions both work
    $desktop = Wait-Until -Description 'Power BI Desktop to start' -Seconds 120 -Condition {
        Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $existing -notcontains $_.Id } | Select-Object -First 1
    }

    $promptedAt = $null
    $mainWindow = Wait-Until -Description "the $reportLabel report to open" -Condition {
        $windows = @(Get-ProcessWindow $desktop.Id)

        # Nothing here can sign in, so say so plainly and wait for the person at the keyboard
        $signIn = @($windows | Where-Object { $_.Current.Name -match "(?i)sign in|sign-in|credential|authenticat|your account" }) | Select-Object -First 1
        if ($signIn)
        {
            if (-not $promptedAt)
            {
                $promptedAt = Get-Date
                Write-Host ''
                Write-Host "    ⚠️ ACTION NEEDED: Power BI Desktop is asking you to sign in ('$($signIn.Current.Name)')." -ForegroundColor Yellow
                Write-Host '       Complete the sign-in in that window. Everything continues on its own afterward.' -ForegroundColor Yellow
                Write-Host ''
            }
            return $null
        }

        if ($promptedAt)
        {
            Write-Step "Signed in after $([int]((Get-Date) - $promptedAt).TotalSeconds) seconds. Continuing..."
            $promptedAt = $null
        }

        $windows | Where-Object { $_.Current.Name -like "*$reportLabel*" } | Select-Object -First 1
    }

    #endregion Open

    #region Refresh

    Import-TabularLibrary
    $port = Wait-Until -Description 'the Power BI Desktop data model to load' -Condition { Get-DesktopEnginePort $desktop.Id }

    $server = New-Object Microsoft.AnalysisServices.Tabular.Server
    $server.Connect("Data Source=localhost:$port")
    $database = Wait-Until -Description 'the Power BI Desktop data model to load' -Condition {
        $server.Refresh($true)
        $server.Databases | Where-Object { $_.Model -and $_.Model.Tables.Count -gt 0 } | Select-Object -First 1
    }

    if ($SkipRefresh)
    {
        Write-Step 'Skipping data refresh.'
    }
    else
    {
        Write-Step "Refreshing $($database.Model.Tables.Count) tables..."
        $refreshStarted = Get-Date

        # Refresh policies only apply in the Power BI service
        $command = @{ refresh = @{ type = 'full'; applyRefreshPolicy = $false; objects = @(@{ database = $database.Name }) } } | ConvertTo-Json -Depth 5 -Compress

        $errors = Invoke-EngineCommand $command 'Data refresh' $port $mainWindow $desktop $database
        if ($errors.Count -gt 0)
        {
            # The engine reports what went wrong but not where, and one failure cancels the whole
            # transaction. Refreshing each table on its own says which tables are actually broken.
            Write-Step 'Refresh failed. Checking each table to find the cause...'
            $broken = New-Object System.Collections.Generic.List[string]
            foreach ($table in @($database.Model.Tables))
            {
                if ((Get-Date) -ge $deadline)
                {
                    $broken.Add('(ran out of time before checking every table)')
                    break
                }

                $tableCommand = @{ refresh = @{ type = 'full'; applyRefreshPolicy = $false; objects = @(@{ database = $database.Name; table = $table.Name }) } } | ConvertTo-Json -Depth 5 -Compress
                try
                {
                    $tableResults = $server.Execute($tableCommand)
                    $tableErrors = @($tableResults | ForEach-Object { $_.Messages } | Where-Object { $_.GetType().Name -eq 'XmlaError' } | ForEach-Object { $_.Description })
                }
                catch
                {
                    $tableErrors = @($_.Exception.GetBaseException().Message)
                }

                # Errors about a cancelled transaction come from another table, not this one
                $tableErrors = @($tableErrors | Where-Object { $_ -notmatch 'another operation in the transaction' })
                if ($tableErrors.Count -gt 0) { $broken.Add("$($table.Name): $(($tableErrors | Select-Object -First 2) -join ' ')") }
            }

            $detail = if ($broken.Count -gt 0) { "`n  $($broken -join "`n  ")" } else { "`n  $($errors -join "`n  ")" }
            throw "Data refresh failed:$detail"
        }

        # A refresh through the engine leaves calculated columns, tables, and relationships stale,
        # which is what Power BI Desktop's "calculated objects need to be manually refreshed"
        # banner is about. Recalculating here means the saved report doesn't need that click.
        Write-Step 'Recalculating calculated columns and tables...'
        $calculate = @{ refresh = @{ type = 'calculate'; objects = @(@{ database = $database.Name }) } } | ConvertTo-Json -Depth 5 -Compress
        $calculateErrors = Invoke-EngineCommand $calculate 'Recalculating' $port $mainWindow $desktop
        if ($calculateErrors.Count -gt 0) { throw "Recalculating failed:`n  $($calculateErrors -join "`n  ")" }

        $database.Refresh($true)
        $notReady = @($database.Model.Tables `
            | Where-Object { @($_.Partitions | Where-Object { $_.State -ne [Microsoft.AnalysisServices.Tabular.ObjectState]::Ready }).Count -gt 0 } `
            | ForEach-Object { $_.Name })
        if ($notReady.Count -gt 0)
        {
            throw "Data refresh didn't finish for: $($notReady -join ', ')"
        }

        Write-Step "Refreshed in $([int]((Get-Date) - $refreshStarted).TotalSeconds) seconds."
    }

    $server.Disconnect()
    $server = $null

    #endregion Refresh

    #region Sensitivity label

    # The Sensitivity button is only shown when the signed-in account has labels to apply
    # Tenants without labels still show the button, greyed out, so being there isn't enough
    $sensitivity = if ($SensitivityLabel) { Find-Element $mainWindow 'Sensitivity' @($types::SplitButton, $types::Button, $types::MenuItem) } else { $null }
    if ($sensitivity -and -not $sensitivity.Current.IsEnabled)
    {
        Write-Step 'Sensitivity labels are turned off here. Skipping.'
        $sensitivity = $null
    }
    elseif (-not $SensitivityLabel)
    {
        Write-Step 'No sensitivity label requested. Skipping.'
    }

    if ($sensitivity)
    {
        Write-Step "Applying the '$SensitivityLabel' sensitivity label..."
        try
        {
            Invoke-Element $sensitivity
            $label = Wait-Until -Description "the '$SensitivityLabel' sensitivity label" -Seconds 15 -Condition {
                foreach ($window in @($mainWindow) + @(Get-ProcessWindow $desktop.Id))
                {
                    $item = Find-Element $window $SensitivityLabel @($types::MenuItem, $types::ListItem, $types::Button, $types::RadioButton, $types::CheckBox)
                    if ($item) { return $item }
                }
            }
            Invoke-Element $label
            Start-Sleep -Seconds 1
        }
        catch
        {
            # Saving is the expensive part, so a label that can't be set doesn't stop it. The
            # label is checked when the saved file is validated.
            Write-Warning "Could not apply the '$SensitivityLabel' label to $reportLabel ($($_.Exception.Message)). Set it by hand if validation reports it."
        }
    }
    elseif ($SensitivityLabel)
    {
        Write-Step 'No sensitivity labels are available. Skipping.'
    }

    #endregion Sensitivity label

    #region Save as

    Write-Step "Saving $([System.IO.Path]::GetFileName($Destination))..."

    # File > Save as. Keytips are used when the ribbon isn't exposed to UI Automation.
    $fileTab = $null
    try { $fileTab = Wait-Until -Description 'the File menu' -Seconds 120 -Condition { Find-Element $mainWindow 'File' @($types::TabItem, $types::Button, $types::MenuItem) } }
    catch { Write-Verbose 'The File menu is not exposed to UI Automation. Using keytips.' }
    if ($fileTab) { Invoke-Element $fileTab } else { Send-KeyInput $mainWindow '%f' }

    $saveAs = Wait-Until -Description 'the Save as option in the File menu' -Seconds 30 -Condition {
        Find-Element $mainWindow 'Save as' @($types::ListItem, $types::Button, $types::MenuItem, $types::TabItem, $types::Hyperlink)
    }
    Invoke-Element $saveAs

    # Newer versions show a "Browse this device" option before the file dialog
    $dialog = Wait-Until -Description 'the Save as dialog' -Seconds 60 -Condition {
        # Power BI Desktop has other dialogs of the same class, including Open. Typing a file name
        # into one of those and pressing its default button does something else entirely, so the
        # title decides, and a Save control is only used when a dialog has no title to go by.
        $dialogs = @(Get-ProcessWindow $desktop.Id `
            | ForEach-Object { $_; @($_.FindAll($tree::Children, [System.Windows.Automation.Condition]::TrueCondition)) } `
            | Where-Object { $_.Current.ClassName -eq '#32770' })

        $fileDialog = @($dialogs | Where-Object { $_.Current.Name -match '(?i)save' }) | Select-Object -First 1
        if (-not $fileDialog)
        {
            $fileDialog = @($dialogs `
                | Where-Object { -not $_.Current.Name -or $_.Current.Name -notmatch '(?i)open|import|confirm' } `
                | Where-Object { Find-Element $_ 'Save' @($types::Button, $types::SplitButton) }) | Select-Object -First 1
        }
        if ($fileDialog) { return $fileDialog }

        foreach ($other in $dialogs) { Write-Verbose "  Ignoring the '$($other.Current.Name)' dialog." }

        $browse = Find-Element $mainWindow 'Browse this device' @($types::Button, $types::ListItem, $types::Hyperlink)
        if ($browse) { Invoke-Element $browse }
        return $null
    }

    # Power BI Desktop's Save as dialog has no file type list, so the extension decides the
    # format. Typing a name ending in .pbix is what makes it save a file instead of a project.
    function Get-FileTypeValue($Combo)
    {
        $pattern = $null
        if ($Combo.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) { return $pattern.Current.Value }
        $selected = @($Combo.FindAll($tree::Descendants, (New-Object System.Windows.Automation.PropertyCondition($props::ControlTypeProperty, $types::ListItem)))) `
        | Where-Object { $_.Current.IsOffscreen -eq $false } | Select-Object -First 1
        return $selected.Current.Name
    }

    $fileType = Find-Element $dialog $null @($types::ComboBox) 'FileTypeControlHost'
    if (-not $fileType) { $fileType = Find-Element $dialog 'Save as type:' @($types::ComboBox) }
    if (-not $fileType)
    {
        Write-Verbose '  No file type list in this dialog. The .pbix extension decides the format.'
    }
    else
    {

    $expand = $null
    if ($fileType.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand))
    {
        try { $expand.Expand() } catch { Write-Verbose "  Could not open the file type list: $($_.Exception.Message)" }
    }
    Start-Sleep -Milliseconds 500

    $pbixType = @($fileType.FindAll($tree::Descendants, (New-Object System.Windows.Automation.PropertyCondition($props::ControlTypeProperty, $types::ListItem)))) `
    | Where-Object { $_.Current.Name -match '(?i)pbix' } `
    | Select-Object -First 1
    if ($pbixType) { Invoke-Element $pbixType }
    elseif ($fileType.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$null))
    {
        $value = $null
        $null = $fileType.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$value)
        try { $value.SetValue('Power BI files (*.pbix)') } catch { Write-Verbose "  Could not set the file type: $($_.Exception.Message)" }
    }
    if ($expand) { try { $expand.Collapse() } catch { Write-Verbose '  File type list already closed.' } }
    Start-Sleep -Milliseconds 500

    # Saving as the wrong type makes a mess that's hard to recognize later, so stop before that
    $selectedType = Get-FileTypeValue $fileType
    Write-Verbose "  File type: $selectedType"
    if ($selectedType -and $selectedType -notmatch '(?i)pbix')
    {
        Save-WindowTree $dialog ([System.IO.Path]::ChangeExtension($Destination, '.dialog.txt'))
        throw "The Save as dialog is still set to '$selectedType'. Saving now would write a project, not a PBIX."
    }

    }

    # The search box and the address bar are editable too, and writing a path into either one
    # makes the dialog reject it. Candidates are tried in order and the value is read back.
    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in @(
            (Find-DialogElement $dialog '1001' 'Edit'),
            (Find-Element $dialog 'File name:' @($types::Edit)),
            $(
                $host_ = Find-Element $dialog $null @($types::ComboBox) 'FileNameControlHost'
                if ($host_) { Find-Element $host_ $null @($types::Edit) }
            )
        ))
    {
        if ($candidate) { $candidates.Add($candidate) }
    }

    @($dialog.FindAll($tree::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) `
    | Where-Object { $_.Current.IsEnabled -and -not $_.Current.IsOffscreen -and $_.Current.ClassName -eq 'Edit' } `
    | Where-Object { "$($_.Current.Name) $($_.Current.AutomationId) $($_.Current.ClassName)" -notmatch '(?i)search|address|breadcrumb|toolbar' } `
    | ForEach-Object { $candidates.Add($_) }

    # Typing just the name avoids the path separators the dialog rejects in a file name, but only
    # when the dialog is already in the right folder. The address bar says where that is.
    $destinationFolder = [System.IO.Path]::GetDirectoryName($Destination)
    $address = @($dialog.FindAll($tree::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) `
    | Where-Object { $_.Current.Name -match '^Address: (?<path>.+)$' } `
    | Select-Object -First 1

    $currentFolder = if ($address -and $address.Current.Name -match '^Address: (?<path>.+)$') { $Matches.path.TrimEnd('\') } else { $null }
    $inDestination = $currentFolder -and ($currentFolder -eq $destinationFolder.TrimEnd('\') -or (Split-Path $currentFolder -Leaf) -eq (Split-Path $destinationFolder -Leaf))
    if (-not $currentFolder) { Write-Verbose '  The Save as dialog does not say what folder it is in. Using the full path.' }

    $fileNameOnly = if ($inDestination) { [System.IO.Path]::GetFileName($Destination) } else { $Destination }
    Write-Verbose "  Saving as '$fileNameOnly'$(if ($currentFolder) { " (dialog is in $currentFolder)" })"
    $named = $false
    foreach ($candidate in $candidates)
    {
        $value = $null
        if (-not $candidate.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$value)) { continue }

        try { $value.SetValue($fileNameOnly) }
        catch
        {
            Write-Verbose "  Could not type into '$($candidate.Current.Name)': $($_.Exception.Message)"
            continue
        }

        # The right box keeps what was typed. The wrong one rejects it or is replaced.
        try { $named = $value.Current.Value -eq $fileNameOnly }
        catch { $named = $false }
        if ($named) { break }

        Write-Verbose "  '$($candidate.Current.Name)' didn't keep the file name. Trying the next box."
    }

    if (-not $named)
    {
        Save-WindowTree $dialog ([System.IO.Path]::ChangeExtension($Destination, '.dialog.txt'))
        throw "Could not type the file name into the '$($dialog.Current.Name)' dialog [$($dialog.Current.ClassName)]."
    }

    $saveButton = Find-DialogElement $dialog '1' 'Button'
    if (-not $saveButton) { $saveButton = Find-Element $dialog 'Save' @($types::Button, $types::SplitButton) }
    if (-not $saveButton)
    {
        Save-WindowTree $dialog ([System.IO.Path]::ChangeExtension($Destination, '.dialog.txt'))
        throw "Could not find the Save button in the '$($dialog.Current.Name)' dialog [$($dialog.Current.ClassName)]."
    }
    Invoke-Element $saveButton

    # A rejected file name leaves a message box on screen and the dialog open behind it
    Start-Sleep -Seconds 2
    $complaint = @(Get-ProcessWindow $desktop.Id | Where-Object { $_.Current.ClassName -eq '#32770' -and -not (Find-Element $_ $null @($types::Edit) '1001') }) `
    | Where-Object { $_.Current.Name -match '(?i)confirm folder replace|replace' -or @($_.FindAll($tree::Descendants, (New-Object System.Windows.Automation.PropertyCondition($props::ControlTypeProperty, $types::Text)))) | Where-Object { $_.Current.Name -match "(?i)file name|can't|cannot|invalid|merge this folder" } } `
    | Select-Object -First 1
    if ($complaint)
    {
        $message = (@($complaint.FindAll($tree::Descendants, (New-Object System.Windows.Automation.PropertyCondition($props::ControlTypeProperty, $types::Text)))) | ForEach-Object { $_.Current.Name }) -join ' '
        Save-WindowTree $dialog ([System.IO.Path]::ChangeExtension($Destination, '.dialog.txt'))
        foreach ($dismiss in 'No', 'Cancel', 'OK')
        {
            $button = Find-Element $complaint $dismiss @($types::Button)
            if ($button) { Invoke-Element $button; break }
        }
        throw "The Save as dialog rejected the file name: $message"
    }

    # Wait for the file to be written, answering prompts Power BI Desktop shows while saving
    Wait-Until -Description "$([System.IO.Path]::GetFileName($Destination)) to be saved" -Seconds 600 -Condition {
        # Skip the main window and the Save as dialog, which is still closing
        $prompts = @(Get-ProcessWindow $desktop.Id `
            | Where-Object { $_.Current.NativeWindowHandle -ne $mainWindow.Current.NativeWindowHandle } `
            | Where-Object { -not (Find-Element $_ $null @($types::Edit) '1001') })
        foreach ($window in $prompts)
        {
            # Never confirm an error, or the failure would be hidden until the timeout
            $text = @($window.FindAll($tree::Descendants, (New-Object System.Windows.Automation.PropertyCondition($props::ControlTypeProperty, $types::Text))) | ForEach-Object { $_.Current.Name }) -join ' '
            if ("$($window.Current.Name) $text" -match "(?i)\b(error|failed|couldn't|could not|unable)\b")
            {
                throw "Power BI Desktop showed '$($window.Current.Name)': $text"
            }

            $label = Find-Element $window $SensitivityLabel @($types::ListItem, $types::RadioButton, $types::Button, $types::MenuItem)
            if ($label)
            {
                Write-Step "Selecting the '$SensitivityLabel' sensitivity label in '$($window.Current.Name)'..."
                Invoke-Element $label
            }
            foreach ($confirm in 'OK', 'Apply', 'Save')
            {
                $button = Find-Element $window $confirm @($types::Button)
                if ($button)
                {
                    Write-Step "Selecting $confirm in '$($window.Current.Name)'..."
                    Invoke-Element $button
                    break
                }
            }
        }

        if (-not (Test-Path $Destination)) { return $false }
        $size = (Get-Item $Destination).Length
        Start-Sleep -Seconds 2
        if ($size -eq 0 -or $size -ne (Get-Item $Destination).Length) { return $false }
        try
        {
            [System.IO.Compression.ZipFile]::OpenRead($Destination).Dispose()
            return $true
        }
        catch
        {
            return $false
        }
    } | Out-Null

    #endregion Save as

    #region Close

    $windowPattern = $null
    if ($mainWindow.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$windowPattern)) { $windowPattern.Close() }

    try
    {
        Wait-Until -Description 'Power BI Desktop to close' -Seconds 60 -Condition {
            if ($desktop.HasExited) { return $true }
            foreach ($window in Get-ProcessWindow $desktop.Id)
            {
                $dontSave = Find-Element $window "Don't save" @($types::Button)
                if ($dontSave) { Invoke-Element $dontSave }
            }
            return $false
        } | Out-Null
    }
    catch
    {
        Write-Verbose 'Power BI Desktop did not close on its own. Stopping it.'
    }

    #endregion Close

    [PSCustomObject]@{
        Path     = $Destination
        Size     = (Get-Item $Destination).Length
        Duration = (Get-Date) - $started
    }
}
catch
{
    Save-Screenshot $_.Exception.Message
    throw "Could not save $reportLabel automatically: $($_.Exception.Message) Save it by hand from Power BI Desktop, then rerun Package-PowerBI."
}
finally
{
    if ($server) { try { $server.Disconnect() } catch { Write-Verbose 'Engine connection already closed.' } }
    Stop-Desktop $desktop
}
