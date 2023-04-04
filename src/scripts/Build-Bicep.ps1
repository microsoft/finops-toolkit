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
    [switch]
    $IncludeTests,

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

if ($IncludeTests)
{
    $testPath = Join-Path -Path $parentFolderPath -ChildPath 'Test'
    if (Test-Path -Path $testPath)
    {
        $tests = (Get-ChildItem -Path $testPath -Filter '*test.bicep').FullName
        foreach ($test in $tests)
        {
            $testLines = Get-Content -Path $test
            $testNumber = 1
            foreach ($scope in $scopes)
            {
                # Setup output directory
                $outputDirectory = Join-Path -Path $OutputPath -ChildPath "$Scope-$parentFolderName\Test"
                if (-not (Test-Path -Path $outputDirectory))
                {
                    $outputDirectory = (New-Item -Path $outputDirectory -ItemType 'Directory').FullName
                }

                $outputFileName = Join-Path -Path $outputDirectory -ChildPath "$moduleName.test.bicep"   
                $testOtherScopeString = "\/\/region\s@($($allScopes.Where({$_ -ne $scope}) -join '|'))+"
                $testString = '\/\/Test:'
                $testScopeMatchString = "\/\/(region\s@$scope)+"
                $outputString = [System.Text.StringBuilder]::new()
                $readmeOutput = [System.Text.StringBuilder]::new()
                $i = 0
                while ($i -lt $testLines.Count)
                {
                    $line = $testLines[$i]
                    $isModule = $false
                    if ($line -match $testScopeMatchString)
                    {
                        $i++
                        $stopIndex = Get-NextEndRegionIndex -Content $testLines -StartingIndex $i
                        for ($x = $i; $x -lt $stopIndex; $x++)
                        {
                            if ($testLines[$x] -match $testString)
                            {
                                $cleanString = $testLines[$x] -replace $testString
                                $null = $readmeOutput.AppendLine().AppendLine("### Example $testNumber").AppendLine('')
                                $null = $readmeOutput.AppendLine($cleanString)
                                $null = $readmeOutput.AppendLine('```bicep')
                                $isModule = $true
                                $testNumber++
                            }
                            else
                            {
                                $null = $outputString.AppendLine($testLines[$x].Replace('//', ''))
                                if ($isModule)
                                {
                                    $null = $readmeOutput.AppendLine($testLines[$x].Replace('//', ''))
                                }
                            }

                            if ($x -eq $stopIndex - 1 -and $isModule)
                            {
                                $null = $readmeOutput.AppendLine('```')
                            }
                        }
                        
                        $i = $stopIndex + 1
                    }
                    elseif ($line -match $testOtherScopeString)
                    {
                        $stopIndex = Get-NextEndRegionIndex -Content $testLines -StartingIndex $i
                        $i = $stopIndex + 1
                    }
                    else
                    {
                        $null = $outputString.AppendLine($line)
                        $i++
                    }
                }

                $outputString.ToString() | Out-File -FilePath $outputFileName
                $readmeOutput.ToString() | Out-File (Join-Path -Path $parentFolderPath -ChildPath 'README.md') -Append
            }        
        }
    }
}
