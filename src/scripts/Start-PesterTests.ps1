$pesterModule = Get-Module -Name 'Pester' -ListAvailable
$pesterVersion = '5.4.1'
if (-not $pesterModule -or $pesterModule.Version.ToString() -ne $pesterVersion)
{
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module -Name 'Pester' -RequiredVersion $pesterVersion -Force -AllowClobber
}

Import-Module -Name 'Pester'
$rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent).FullName
$powerShellPath = Join-Path -Path $rootPath -ChildPath 'src/powershell'

$pesterArgs = [PesterConfiguration]::Default
$pesterArgs.Run.Path = $powerShellPath
$pesterArgs.Output.Verbosity = 'Detailed'
$pesterArgs.CodeCoverage.Enabled = $true
$pesterArgs.CodeCoverage.Path = "$powerShellPath/*.ps*1"
$pesterArgs.CodeCoverage.OutputFormat = 'JaCoCo'
$pesterArgs.CodeCoverage.OutputPath = "$rootPath/coverage.xml"

Invoke-Pester -Configuration $pesterArgs
