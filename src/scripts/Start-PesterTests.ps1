$requiredModules = @(
    @{
        Name    = 'Pester'
        Version = '5.4.1'
    },
    @{
        Name    = 'PSScriptAnalyzer'
        Version = '1.21.0'
    }
)

$repository = Get-PSRepository -Name 'PsGallery'
if ($repository.InstallationPolicy -ne 'Trusted')
{
    Set-PSRepository PSGallery -InstallationPolicy 'Trusted'
}

foreach ($module in $requiredModules)
{
    $foundModule = Get-Module -Name $module.Name -ListAvailable
    if (-not $foundModule -or $foundModule.Version.ToString() -ne $module.Version)
    {
        Install-Module -Name $module.Name -RequiredVersion $module.Version -Force -AllowClobber
    }
}

Import-Module -Name $requiredModules.Name
$rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent).FullName
$metaTestPath = Join-Path -Path $rootPath -ChildPath 'src/powershell/Tests/Meta'

# Run Meta tests
$pesterArgs = [PesterConfiguration]::Default
$pesterArgs.Run.Path = $metaTestPath
$pesterArgs.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $pesterArgs

# Run unit tests
$powerShellPath = Join-Path -Path $rootPath -ChildPath 'src/powershell'
$unitTestPath = Join-Path -Path $rootPath -ChildPath 'src/powershell/Tests/Unit'

$pesterArgs = [PesterConfiguration]::Default
$pesterArgs.Run.Path = $unitTestPath
$pesterArgs.Output.Verbosity = 'Detailed'
$pesterArgs.CodeCoverage.Enabled = $true
$pesterArgs.CodeCoverage.Path = "$powerShellPath/*.ps*1"
$pesterArgs.CodeCoverage.OutputFormat = 'JaCoCo'
$pesterArgs.CodeCoverage.OutputPath = "$rootPath/coverage.xml"

Invoke-Pester -Configuration $pesterArgs
