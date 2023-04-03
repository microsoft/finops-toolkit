<#
    .SYNOPSIS
        Builds all toolkit templates for publishing to Azure Quickstart Templates.

    .PARAMETER Module
        Path to the module to build.

    .PARAMETER Scopes
        Optional. Scope to build. If not specified, all scopes will be built.

    .PARAMETER CopySupportingFiles
        Optional. Copies supporting files to the output directory.

    .PARAMETER OutputPath
        Path to save resulting templates. Defaults to ../Release.

    .EXAMPLE
        ./Build-Bicep ../bicep-registry/module-name
        Generates separate modules for each supported scope for the specified module.

    .EXAMPLE
        ./Build-Bicep ../bicep-registry/module-name -Scope subscription
        Generates the module for only one scope (subscription in this case).

    .EXAMPLE
        ./Build-Bicep ../bicep-registry/module-name -Scope subscription -CopySupportingFiles
        Generates module for the subscription scope and copies associated files.
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path -Path $_})]
    [string]
    $Module,

    [Parameter()]
    [ValidateSet('Subscription', 'ResourceGroup', 'ManagementGroup', 'Tenant')]
    [string[]]
    $Scopes = ('Subscription', 'ResourceGroup', 'ManagementGroup', 'Tenant'),

    [Parameter()]
    [switch]
    $CopySupportingFiles,

    [Parameter()]
    [string]
    $OutputPath = "../Release"
)


function Get-NextEndRegionIndex
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [psobject[]]
        $Content,

        [Parameter(Mandatory = $true)]
        [int]
        $StartingIndex
    )

    for ($i = $StartingIndex; $i -lt $Content.Count; $i++)
    {
        if ($Content[$i] -match '//endregion')
        {
            return $i
        }
    }
}

$moduleName = [System.IO.Path]::GetFileNameWithoutExtension($Module)
$parentFolderPath = Split-Path -Path $Module -Parent
$parentFolderName = Split-Path -Path $parentFolderPath -Leaf
$lines = Get-Content -Path $module

# Matches any scope
$allScopes = 'Subscription', 'ResourceGroup', 'ManagementGroup', 'Tenant'

foreach ($scope in $scopes)
{
    $genericScopeString = "\/\/region\s@($($allScopes.Where({$_ -ne $scope}) -join '|'))+"

    # Setup output directory
    $outputDirectory = Join-Path -Path $OutputPath -ChildPath "$Scope-$parentFolderName"
    if (-not (Test-Path -Path $outputDirectory))
    {
        $outputDirectory = (New-Item -Path $outputDirectory -ItemType 'Directory').FullName
    }
    $outputFileName = Join-Path -Path $outputDirectory -ChildPath "$moduleName.bicep"
    
    # Matches only the current scope
    $scopeMatchString = "\/\/(region\s@$scope)+"
    $outputString = [System.Text.StringBuilder]::new()
    $i = 0
    while ($i -lt $lines.Count)
    {
        $line = $lines[$i]

        # Match current scope
        if ($line -match $scopeMatchString)
        {
            $i++
            $stopIndex = Get-NextEndRegionIndex -Content $lines -StartingIndex $i
            Write-Debug -Message ("MATCH: Scope: Line {0}: {1}" -f ($i - 1), $line)
            for ($x = $i; $x -lt $stopIndex; $x++)
            {
                $null = $outputString.AppendLine($lines[$x].Replace('//', ''))
            }
            
            $i = $stopIndex + 1
        }
        elseif ($line -match $genericScopeString)
        {
            $stopIndex = Get-NextEndRegionIndex -Content $lines -StartingIndex $i
            $i = $stopIndex + 1
        }
        else
        {
            $null = $outputString.AppendLine($line)
            $i++
        }
    }

    $outputString.ToString() | Out-File -FilePath $outputFileName
}

# Copy supporting files.
if ($CopySupportingFiles)
{
    Get-ChildItem -Path $parentFolderPath -Exclude (Split-Path -Path $Module -Leaf) -Recurse | Copy-Item -Destination $outputDirectory
}

# Copy tests to README.md examples
$testPath = Join-Path -Path $parentFolderPath -ChildPath 'Test'
if (Test-Path -Path $testPath)
{
    $tests = (Get-ChildItem -Path $testPath -Filter '*test.bicep').FullName
    foreach ($test in $tests)
    {
        $sb = [System.Text.StringBuilder]::new()
        $writingModule = $false
        $lines = Get-Content -Path $test
        foreach ($line in $lines)
        {
            # If test comment, write example header
            if ($line -match '^\s*//\s*Test\s')
            {
                # Parse test number and description
                $regex = [regex]::Matches($line.Trim(), '^//\s*Test\s*([0-9]+)\s*-\s*(.*)')
                $number = $regex.Groups[1].Value
                $text = $regex.Groups[2].Value

                [void]$sb.AppendLine().AppendLine("### Example $number").AppendLine()
                [void]$sb.AppendLine($text).AppendLine()
                [void]$sb.AppendLine('```bicep')
            }
            # If module, adjust the target destination
            elseif ($line -match '^module\s*' -and $line -match '../main.bicep')
            {
                $line = $line -replace "../main.bicep", "br/public:cost/$($parentFolderName):1.0"
                [void]$sb.AppendLine($line)
                $writingModule = $true
            }
            # If module body, append code
            elseif ($writingModule -and -not ($line -match '^}$'))
            {
                [void]$sb.AppendLine($line)
            }
            # If end of module, close code block
            elseif ($writingModule -and $line -eq '}')
            {
                [void]$sb.AppendLine($line).AppendLine('```')
                [void]$sb.AppendLine($line).AppendLine('')
                $writingModule = $false
            }
        }

        # Append examples to README file
        $sb.ToString() | Out-File (Join-Path -Path $parentFolderPath -ChildPath 'README.md') -Append
    }
}
