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
    Optional. Name of the sensitivity label to apply. Default = "Public".

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

function Invoke-Element($Element)
{
    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) { $pattern.Invoke(); return }
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) { $pattern.Select(); return }
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$pattern)) { $pattern.Expand(); return }
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern, [ref]$pattern)) { $pattern.Toggle(); return }

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
    $dllPath = "$((Get-Item (Get-Package Microsoft.AnalysisServices).Source).Directory)/lib/net8.0/Microsoft.AnalysisServices.Tabular.dll"
    Add-Type -Path $dllPath
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
    Remove-Item $Destination -Force -ErrorAction SilentlyContinue
    Remove-Item ([System.IO.Path]::ChangeExtension($Destination, '.error.png')) -Force -ErrorAction SilentlyContinue

    $existing = @(Get-Process PBIDesktop -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    Start-Process -FilePath $Path

    # Use the file association so the installed and Microsoft Store versions both work
    $desktop = Wait-Until -Description 'Power BI Desktop to start' -Seconds 120 -Condition {
        Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $existing -notcontains $_.Id } | Select-Object -First 1
    }

    $mainWindow = Wait-Until -Description "the $reportLabel report to open" -Condition {
        $windows = @(Get-ProcessWindow $desktop.Id)

        # Nothing here can sign in, so stop immediately instead of waiting out the timeout
        $signIn = @($windows | Where-Object { $_.Current.Name -match "(?i)sign in|sign-in|credential|authenticat|your account" }) | Select-Object -First 1
        if ($signIn) { throw "Power BI Desktop is asking to sign in ('$($signIn.Current.Name)'). Sign in to Power BI Desktop, refresh this report once to save its data source credentials, then rerun." }

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
        $results = $server.Execute($command)

        $errors = @($results | ForEach-Object { $_.Messages } | Where-Object { $_.GetType().Name -eq 'XmlaError' } | ForEach-Object { $_.Description })
        if ($errors.Count -gt 0)
        {
            throw "Data refresh failed:`n  $($errors -join "`n  ")"
        }

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
    $sensitivity = Find-Element $mainWindow 'Sensitivity' @($types::SplitButton, $types::Button, $types::MenuItem)
    if ($sensitivity)
    {
        Write-Step "Applying the '$SensitivityLabel' sensitivity label..."
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
    else
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
        $fileDialog = Get-ProcessWindow $desktop.Id `
        | ForEach-Object { $_; @($_.FindAll($tree::Children, [System.Windows.Automation.Condition]::TrueCondition)) } `
        | Where-Object { $_.Current.ClassName -eq '#32770' } `
        | Select-Object -First 1
        if ($fileDialog) { return $fileDialog }

        $browse = Find-Element $mainWindow 'Browse this device' @($types::Button, $types::ListItem, $types::Hyperlink)
        if ($browse) { Invoke-Element $browse }
        return $null
    }

    # Pick the PBIX file type first so the dialog doesn't append the PBIP extension
    $fileType = Find-Element $dialog $null @($types::ComboBox) 'FileTypeControlHost'
    if ($fileType)
    {
        $expand = $null
        if ($fileType.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) { $expand.Expand() }
        Start-Sleep -Milliseconds 500
        $pbixType = @($fileType.FindAll($tree::Descendants, (New-Object System.Windows.Automation.PropertyCondition($props::ControlTypeProperty, $types::ListItem)))) `
        | Where-Object { $_.Current.Name -match 'pbix' } `
        | Select-Object -First 1
        if (-not $pbixType) { throw 'The Save as dialog has no PBIX file type.' }
        Invoke-Element $pbixType
        if ($expand) { try { $expand.Collapse() } catch { Write-Verbose 'File type list already closed.' } }
    }

    $fileName = Find-Element $dialog $null @($types::Edit) '1001'
    if (-not $fileName) { throw 'Could not find the file name box in the Save as dialog.' }
    $value = $null
    if (-not $fileName.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$value)) { throw 'The file name box in the Save as dialog is read-only.' }
    $value.SetValue($Destination)

    $saveButton = Find-Element $dialog $null @($types::Button) '1'
    if (-not $saveButton) { throw 'Could not find the Save button in the Save as dialog.' }
    Invoke-Element $saveButton

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
