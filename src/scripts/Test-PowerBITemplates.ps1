# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Opens each Power BI template (PBIT) in Power BI Desktop and checks what a person sees.

    .DESCRIPTION
    Replaces the manual check of opening every template in Power BI Desktop, confirming there is
    no error, and reading the parameter prompt. For each template, this:

    1. Opens the PBIT in Power BI Desktop.
    2. Answers the "Potential security risk" dialog with OK, when it appears (KQL templates).
    3. Waits for the parameter prompt, whose title is the template name.
    4. Fails when any other dialog or error window shows up first.
    5. Reads the prompt and checks its title, parameter names, and values against what the PBIT
       defines. A template that ships with a data source filled in (like a demo hub) fails here.
    6. Saves a screenshot, then ends the Power BI Desktop process this script started.

    The prompt is read through its web page, not through Windows UI Automation. Power BI Desktop
    shows its dialogs in an embedded browser control, and UI Automation doesn't list those windows
    or what's in them: it only sees the main window. The dialogs are found by listing the
    process's windows (the title is the dialog title), and the page is read through the browser
    control's document (the same way screen readers do). Nothing is typed or clicked with the
    mouse: buttons are pressed through the page, so the mouse and keyboard stay free, but dialogs
    do open and take focus while this runs.

    What this can't check: the report pages. Power BI Desktop doesn't expose report page tabs
    to any automation, and loading the report needs a data source, so nothing past the prompt is
    opened. Run Test-PowerShell to check what is inside each template without Power BI Desktop
    (src/powershell/Tests/Unit/PowerBITemplates.Tests.ps1).

    Only Power BI Desktop processes this script starts are ended. Instances you already had open
    are left alone.

    Windows only. Requires Power BI Desktop, associated with .pbit files.

    .PARAMETER Path
    Optional. Folder with the PBIT files, or the path to one PBIT file. Default = release/pbit.

    .PARAMETER Name
    Optional. Name of the report to check, like CostSummary. Wildcards supported. Default = * (all).

    .PARAMETER KQL
    Optional. Checks the KQL templates. Default = false (checks all if no types are selected).

    .PARAMETER Storage
    Optional. Checks the storage templates. Default = false (checks all if no types are selected).

    .PARAMETER TimeoutSeconds
    Optional. Maximum number of seconds to wait for the parameter prompt for each template. Default = 180.

    .PARAMETER ScreenshotPath
    Optional. Folder to save one screenshot per template to. Default = release/pbit-test.

    .EXAMPLE
    ./Test-PowerBITemplates CostSummary -Storage

    Checks the Cost summary storage template.

    .EXAMPLE
    ./Test-PowerBITemplates

    Checks all 12 templates. This takes about 30 seconds each.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-test-powerbitemplates
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]
    $Name = '*',

    [string]
    $Path,

    [switch]
    $KQL,

    [switch]
    $Storage,

    [int]
    $TimeoutSeconds = 180,

    [string]
    $ScreenshotPath
)

$ErrorActionPreference = 'Stop'

if ($null -ne $IsWindows -and -not $IsWindows)
{
    throw 'Power BI Desktop only runs on Windows. Run the template tests in src/powershell/Tests/Unit/PowerBITemplates.Tests.ps1 to check the templates on other platforms.'
}

$relDir = Join-Path $PSScriptRoot '../../release'
if (-not $Path) { $Path = Join-Path $relDir 'pbit' }
if (-not $ScreenshotPath) { $ScreenshotPath = Join-Path $relDir 'pbit-test' }
$ScreenshotPath = [System.IO.Path]::GetFullPath($ScreenshotPath, $PWD.Path)
if (-not $KQL -and -not $Storage) { $KQL = $Storage = $true }

$templates = @(
    if (Test-Path $Path -PathType Leaf) { Get-Item $Path }
    elseif (Test-Path $Path -PathType Container) { Get-ChildItem $Path -Filter '*.pbit' }
) | Where-Object {
    $report, $type = $_.BaseName -split '\.'
    $report -like $Name -and (($type -eq 'kql' -and $KQL) -or ($type -eq 'storage' -and $Storage))
} | Sort-Object Name

if ($templates.Count -eq 0)
{
    throw "No templates found in '$Path'$(if ($Name -ne '*') { " matching '$Name'" }). Build them with ./Build-PowerBI -NoPbip."
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing, System.IO.Compression.FileSystem

# A type can't be redefined once it's loaded, so it's compiled under a name nothing has used yet. That
# way a session never has to be restarted to pick up changes here.
$script:Win32Name = "Win32_$([guid]::NewGuid().ToString('N'))"
Add-Type -Namespace FinOpsToolkit -Name $script:Win32Name -MemberDefinition @'
private delegate bool EnumTopProc(IntPtr hWnd, IntPtr lParam);
[DllImport("user32.dll")] private static extern bool EnumWindows(EnumTopProc callback, IntPtr lParam);
[DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
[DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
// The callbacks have to be compiled code. A PowerShell scriptblock passed as the delegate never gets
// called, so enumerations live here and hand back plain arrays.
public static IntPtr[] GetTopLevelWindows(int processId)
{
    var found = new System.Collections.Generic.List<IntPtr>();
    EnumWindows((h, l) => { uint owner; GetWindowThreadProcessId(h, out owner); if (owner == (uint)processId && IsWindowVisible(h)) { found.Add(h); } return true; }, IntPtr.Zero);
    return found.ToArray();
}
private delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
[DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr lParam);
public static IntPtr[] GetDescendants(IntPtr parent)
{
    var found = new System.Collections.Generic.List<IntPtr>();
    EnumChildWindows(parent, (h, l) => { found.Add(h); return true; }, IntPtr.Zero);
    return found.ToArray();
}
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder name, int count);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder name, int count);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern uint RegisterWindowMessage(string msg);
[DllImport("user32.dll", CharSet = CharSet.Auto)] private static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
[DllImport("oleacc.dll")] private static extern int ObjectFromLresult(IntPtr lResult, ref Guid riid, IntPtr wParam, [MarshalAs(UnmanagedType.IUnknown)] out object ppvObject);
// Asks an embedded browser control (class "Internet Explorer_Server") for its HTML document, which is
// how accessibility tools read it. Returns null when the page isn't ready.
public static object GetHtmlDocument(IntPtr hwnd)
{
    uint message = RegisterWindowMessage("WM_HTML_GETOBJECT");
    IntPtr result;
    SendMessageTimeout(hwnd, message, IntPtr.Zero, IntPtr.Zero, 2, 5000, out result); // SMTO_ABORTIFHUNG
    if (result == IntPtr.Zero) { return null; }
    Guid iid = new Guid("626FC520-A41E-11cf-A731-00A0C9082637"); // IHTMLDocument2
    object document;
    return ObjectFromLresult(result, ref iid, IntPtr.Zero, out document) == 0 ? document : null;
}
'@
$win32 = "FinOpsToolkit.$script:Win32Name" -as [type]

#region Helpers

function Write-Step([string] $Message)
{
    Write-Host "    $Message"
}

function Get-WindowClass([IntPtr] $Handle)
{
    $text = New-Object System.Text.StringBuilder 256
    $null = $win32::GetClassName($Handle, $text, $text.Capacity)
    return $text.ToString()
}

function Get-WindowTitle([IntPtr] $Handle)
{
    $text = New-Object System.Text.StringBuilder 512
    $null = $win32::GetWindowText($Handle, $text, $text.Capacity)
    return $text.ToString()
}

<#
    .SYNOPSIS
    Lists the visible windows of a process other than its main window, with what they host.

    .DESCRIPTION
    Dialogs are either web pages in an embedded browser control (the security warning, the parameter
    prompt, and Power BI Desktop's own errors) or ordinary Windows dialogs. UI Automation lists
    neither kind, so they're found from Windows' own list of the process's windows.
#>
function Get-DesktopDialog([int] $ProcessId)
{
    $dialogs = foreach ($handle in @($win32::GetTopLevelWindows($ProcessId)))
    {
        $title = Get-WindowTitle $handle

        # The main window is titled after the open file, like "Untitled - Power BI Desktop"
        if ($title -match 'Power BI Desktop$') { continue }

        $browser = @($win32::GetDescendants($handle) | Where-Object { (Get-WindowClass $_) -eq 'Internet Explorer_Server' }) | Select-Object -First 1
        [PSCustomObject]@{ Handle = $handle; Title = $title; Browser = $browser }
    }
    return , @($dialogs | Where-Object { $_ })
}

function Get-HtmlText($Element)
{
    return ("$($Element.innerText)" -replace '\s+', ' ').Trim()
}

<#
    .SYNOPSIS
    Reads a dialog's page. Returns null while the page isn't ready.
#>
function Read-DialogPage($Dialog)
{
    if (-not $Dialog.Browser) { return $null }

    try
    {
        $document = $win32::GetHtmlDocument($Dialog.Browser)
        if (-not $document) { return $null }

        $elements = @($document.getElementsByTagName('div'))
        $title = $elements | Where-Object { $_.id -eq 'dialogTitle' } | Select-Object -First 1
        $body = @($document.getElementsByTagName('body')) | Select-Object -First 1
        $parameters = foreach ($field in @($elements | Where-Object { $_.className -eq 'o-group-fieldTemplate' }))
        {
            $label = @($field.getElementsByTagName('*') | Where-Object { $_.className -eq 'o-content-label' }) | Select-Object -First 1
            $box = @($field.getElementsByTagName('input')) | Select-Object -First 1
            if ($label) { [PSCustomObject]@{ Name = Get-HtmlText $label; Value = if ($box) { "$($box.value)" } else { $null } } }
        }

        return [PSCustomObject]@{
            Document   = $document
            Title      = if ($title) { Get-HtmlText $title } else { $null }
            Text       = if ($body) { Get-HtmlText $body } else { '' }
            Parameters = @($parameters | Where-Object { $_ })
        }
    }
    catch
    {
        # The page can change under us while it loads, so try again on the next pass
        Write-Verbose "Could not read the dialog page: $($_.Exception.Message)"
        return $null
    }
}

<#
    .SYNOPSIS
    Presses a button in a dialog's page, without the mouse.
#>
function Invoke-DialogButton($Page, [string] $Text)
{
    $button = @($Page.Document.getElementsByTagName('div')) `
    | Where-Object { $_.className -match '\bo-action-button\b' -and (Get-HtmlText $_) -eq $Text } `
    | Select-Object -First 1
    if (-not $button) { return $false }

    $button.click()
    return $true
}

function Save-Screenshot([string] $File)
{
    try
    {
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $bitmap.Save($File, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose()
        $bitmap.Dispose()
        return $File
    }
    catch
    {
        Write-Verbose "Could not save a screenshot: $($_.Exception.Message)"
        return $null
    }
}

<#
    .SYNOPSIS
    Ends a Power BI Desktop process this script started, and the processes it started.
#>
function Stop-Desktop([System.Diagnostics.Process] $Process)
{
    if (-not $Process -or $Process.HasExited) { return }

    Get-CimInstance Win32_Process -Filter "ParentProcessId = $($Process.Id)" -ErrorAction SilentlyContinue `
    | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    try { [void]$Process.WaitForExit(10000) } catch { Write-Verbose "Could not wait for Power BI Desktop to exit: $($_.Exception.Message)" }
}

<#
    .SYNOPSIS
    Reads a part of a PBIT as text. Power BI writes most parts as UTF-16LE, with or without a byte order mark.
#>
function Read-PbitText([string] $File, [string] $Part)
{
    $archive = [System.IO.Compression.ZipFile]::OpenRead($File)
    try
    {
        $entry = $archive.GetEntry($Part)
        if (-not $entry) { throw "$File has no $Part part." }

        $stream = $entry.Open()
        try
        {
            $buffer = New-Object System.IO.MemoryStream
            $stream.CopyTo($buffer)
            $bytes = $buffer.ToArray()
        }
        finally { $stream.Dispose() }
    }
    finally { $archive.Dispose() }

    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { return [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2) }
    if ($bytes.Length -ge 4 -and $bytes[1] -eq 0 -and $bytes[3] -eq 0) { return [System.Text.Encoding]::Unicode.GetString($bytes) }
    return [System.Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
}

<#
    .SYNOPSIS
    Works out what the parameter prompt should show for a template, from the parameters in its data model.

    .DESCRIPTION
    The prompt lists the parameters in query order and starts each one at its default value when the
    parameter declares one, and at its current value otherwise. Text shows without quotes, true and
    false show as TRUE and FALSE, and an empty (null) parameter shows nothing.
#>
function Get-ExpectedPrompt([string] $File)
{
    $model = (Read-PbitText $File 'DataModelSchema' | ConvertFrom-Json -Depth 100 -AsHashtable).model

    $order = @()
    $orderAnnotation = @($model.annotations | Where-Object { $_.name -eq 'PBI_QueryOrder' }) | Select-Object -First 1
    if ($orderAnnotation) { $order = @($orderAnnotation.value | ConvertFrom-Json) }

    $parameters = New-Object System.Collections.Generic.List[object]
    foreach ($expression in @($model.expressions))
    {
        $text = @($expression.expression) -join "`n"
        if ($text -notmatch '(?s)^\s*(?<value>.+?)\s+meta\s*\[(?<meta>[^\]]*IsParameterQuery\s*=\s*true[^\]]*)\]\s*$') { continue }

        $value = $Matches.value
        if ($Matches.meta -match 'DefaultValue\s*=\s*(?<default>"[^"]*"|[^,\]\s]+)') { $value = $Matches.default }

        $shown = switch -Regex ($value)
        {
            '^null$' { '' }
            '^"(?<text>.*)"$' { $Matches.text }
            '^(true|false)$' { $value.ToUpperInvariant() }
            default { $value }
        }
        $index = [array]::IndexOf($order, $expression.name)
        $parameters.Add([PSCustomObject]@{ Name = $expression.name; Value = $shown; Order = if ($index -ge 0) { $index } else { [int]::MaxValue } })
    }

    return @($parameters | Sort-Object Order)
}

#endregion Helpers

#region Test

<#
    .SYNOPSIS
    Opens one template in Power BI Desktop and returns what was found.
#>
function Test-Template([System.IO.FileInfo] $Template)
{
    $label = $Template.BaseName
    $failures = New-Object System.Collections.Generic.List[string]
    $result = [PSCustomObject]@{
        Template       = $label
        Passed         = $false
        SecurityDialog = $false
        Parameters     = @()
        Screenshot     = $null
        Seconds        = 0
        Failures       = $failures
    }
    $started = Get-Date
    $desktop = $null

    try
    {
        $expected = Get-ExpectedPrompt $Template.FullName

        $existing = @(Get-Process PBIDesktop -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
        Start-Process -FilePath $Template.FullName

        # Power BI Desktop is found by being new, so only a process this script started is ever ended
        $limit = (Get-Date).AddSeconds(120)
        while (-not $desktop -and (Get-Date) -lt $limit)
        {
            $desktop = Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $existing -notcontains $_.Id } | Select-Object -First 1
            if (-not $desktop) { Start-Sleep -Milliseconds 500 }
        }
        if (-not $desktop)
        {
            $failures.Add('Power BI Desktop did not start. Check that it is installed and opens .pbit files.')
            return $result
        }

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $pressed = @{}
        $unexpected = New-Object System.Collections.Generic.List[string]
        $prompt = $null

        while ((Get-Date) -lt $deadline -and -not $prompt)
        {
            if ($desktop.HasExited)
            {
                $failures.Add("Power BI Desktop exited before showing the parameter prompt (exit code $($desktop.ExitCode)).")
                break
            }

            foreach ($dialog in (Get-DesktopDialog $desktop.Id))
            {
                $page = Read-DialogPage $dialog
                $title = if ($dialog.Title) { $dialog.Title } elseif ($page) { $page.Title } else { $null }

                if ($title -eq 'Potential security risk')
                {
                    # Templates that read from more than one source warn before the prompt. Answer it once it has
                    # loaded, and again if it is still there a few seconds later.
                    $result.SecurityDialog = $true
                    $last = $pressed[[string]$dialog.Handle]
                    if ($page -and (-not $last -or ((Get-Date) - $last).TotalSeconds -ge 5))
                    {
                        if (Invoke-DialogButton $page 'OK') { Write-Step 'Answered the "Potential security risk" dialog with OK.' }
                        $pressed[[string]$dialog.Handle] = Get-Date
                    }
                }
                elseif ($title -eq $label)
                {
                    # The prompt appears before its fields are drawn
                    if ($page -and $page.Parameters.Count -gt 0) { $prompt = $page }
                }
                elseif ($title -or ($page -and $page.Text -match '(?i)\b(error|failed|couldn.t|could not|unable)\b'))
                {
                    $text = if ($page) { $page.Text } else { '' }
                    $summary = "'$title' dialog$(if ($text) { ": $($text.Substring(0, [Math]::Min(300, $text.Length)))" })"
                    if (-not $unexpected.Contains($summary)) { $unexpected.Add($summary) }
                }
            }

            # An error ends the wait early. The prompt never follows one.
            if ($unexpected.Count -gt 0 -and $deadline -gt (Get-Date).AddSeconds(10)) { $deadline = (Get-Date).AddSeconds(10) }
            if (-not $prompt) { Start-Sleep -Milliseconds 500 }
        }

        if ($prompt)
        {
            # Give an error that follows the prompt a moment to show, then read what's there
            Start-Sleep -Seconds 3
            $dialogs = Get-DesktopDialog $desktop.Id
            foreach ($dialog in $dialogs)
            {
                $page = Read-DialogPage $dialog
                $title = if ($dialog.Title) { $dialog.Title } elseif ($page) { $page.Title } else { $null }
                if ($title -and $title -ne $label -and $title -ne 'Potential security risk')
                {
                    $unexpected.Add("'$title' dialog$(if ($page) { ": $($page.Text.Substring(0, [Math]::Min(300, $page.Text.Length)))" })")
                }
                if ($title -eq $label) { $prompt = $page }
            }

            $result.Screenshot = Save-Screenshot (Join-Path $ScreenshotPath "$label.png")
            $result.Parameters = $prompt.Parameters
        }

        foreach ($summary in $unexpected) { $failures.Add("Power BI Desktop showed a $summary") }

        if (-not $prompt)
        {
            $result.Screenshot = Save-Screenshot (Join-Path $ScreenshotPath "$label.png")
            if ($unexpected.Count -eq 0) { $failures.Add("The parameter prompt did not appear within $TimeoutSeconds seconds.") }
            return $result
        }

        # The dialog is titled after the template
        if ($prompt.Title -ne $label) { $failures.Add("The prompt is titled '$($prompt.Title)', not '$label'.") }

        # Templates ship without a data source: the fields people fill in start empty, whatever the model says
        foreach ($parameter in $prompt.Parameters | Where-Object { $_.Name.EndsWith(' URL') -or $_.Name -in 'RangeStart', 'RangeEnd' })
        {
            if ($parameter.Value) { $failures.Add("'$($parameter.Name)' starts as '$($parameter.Value)'. Templates ship without a data source, so it should be empty.") }
        }
        if ((@($prompt.Parameters | ForEach-Object { $_.Value }) + $prompt.Text) -match '(?i)ftk-?demo') { $failures.Add('The prompt mentions a demo hub or demo storage account (ftk-demo).') }

        # Parameter names and values, in order
        $actualNames = @($prompt.Parameters | ForEach-Object { $_.Name })
        $expectedNames = @($expected | ForEach-Object { $_.Name })
        $missing = @($expectedNames | Where-Object { $actualNames -notcontains $_ })
        $extra = @($actualNames | Where-Object { $expectedNames -notcontains $_ })
        if ($missing) { $failures.Add("The prompt is missing: $($missing -join ', ').") }
        if ($extra) { $failures.Add("The prompt has unexpected parameters: $($extra -join ', ').") }
        if (-not $missing -and -not $extra -and (($actualNames -join "`n") -ne ($expectedNames -join "`n")))
        {
            $failures.Add("The prompt lists parameters as '$($actualNames -join "', '")', expected '$($expectedNames -join "', '")'.")
        }
        foreach ($parameter in $prompt.Parameters)
        {
            $want = $expected | Where-Object { $_.Name -eq $parameter.Name } | Select-Object -First 1
            if ($want -and $parameter.Value -ne $want.Value)
            {
                $failures.Add("'$($parameter.Name)' shows '$($parameter.Value)', expected '$($want.Value)'.")
            }
        }
    }
    catch
    {
        $failures.Add("Unexpected error: $($_.Exception.Message)")
        if (-not $result.Screenshot) { $result.Screenshot = Save-Screenshot (Join-Path $ScreenshotPath "$label.png") }
    }
    finally
    {
        Stop-Desktop $desktop
        $result.Seconds = [int]((Get-Date) - $started).TotalSeconds
        $result.Passed = $failures.Count -eq 0
    }

    return $result
}

#endregion Test

$null = New-Item $ScreenshotPath -ItemType Directory -Force

Write-Host "Opening $($templates.Count) template$(if ($templates.Count -ne 1) { 's' }) in Power BI Desktop. Windows open and take focus while this runs, but the mouse and keyboard aren't used."
if (@(Get-Process PBIDesktop -ErrorAction SilentlyContinue).Count -gt 0)
{
    Write-Host '    Power BI Desktop is already running. Those windows are left open.' -ForegroundColor Yellow
}
Write-Host ''

$results = foreach ($template in $templates)
{
    Write-Host "  $($template.BaseName)..."
    $result = Test-Template $template
    if ($result.Passed)
    {
        Write-Host "  ✅ $($template.BaseName)  $($result.Parameters.Count) parameters, $($result.Seconds) s$(if ($result.SecurityDialog) { ', security dialog answered' })" -ForegroundColor Green
    }
    else
    {
        Write-Host "  ❌ $($template.BaseName)" -ForegroundColor Red
        $result.Failures | ForEach-Object { Write-Host "       $_" -ForegroundColor Red }
        if ($result.Screenshot) { Write-Host "       Screenshot: $($result.Screenshot)" -ForegroundColor Red }
    }
    $result
}

Write-Host ''
$failed = @($results | Where-Object { -not $_.Passed })
if ($failed.Count -gt 0)
{
    throw "$($failed.Count) of $(@($results).Count) templates failed in Power BI Desktop: $(($failed | ForEach-Object { $_.Template }) -join ', ')."
}

Write-Host "✅ $(@($results).Count) template$(if (@($results).Count -ne 1) { 's' }) opened in Power BI Desktop with the expected parameter prompt" -ForegroundColor Green
return $results
