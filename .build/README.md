# 📜 FinOps toolkit build automation

Tools to support the management and distribution of [FinOpsToolkit](.././src/powershell/FinOpsToolkit.psm1).

On this page:

- [🆕 Start](#-start)
- [📦 Build](#-build)
- [📦 Build Helper](#-build-helper)

---

## 🆕 Start

[start.ps1](./start.ps1) bootstraps the build process by processing arguments and passing them to ./build.ps1 (InvokeBuild).

Example:

```powershell
./start.ps1 -Task "Test.All"
```

Run all unit and style tests.

Example:

```powershell
./start.ps1 -Task "Build.Module" -Version "1.0.0"
```

Build FinOpsToolkit module and output to "release" folder.

Example:

```powershell
./start.ps1 -Task "Publish.Module" -Version "1.0.0"
```

Build and subsequently publish FinOpsToolkit module to the PowerShell gallery.

<br>

## 📦 Build

[build.ps1](./build.ps1) build script for defining and invoking build automation processes.

Example:

```powershell
./build.ps1 -Version "1.0.0"
```

build.ps1 defines and performs incremental tasks. For more information, see [InvokeBuild](https://github.com/nightroman/Invoke-Build).

### Build Tasks

| Task           | Dependency Task(s)                   | Description                                                                                                        |
| -------------- | ------------------------------------ |------------------------------------------------------------------------------------------------------------------- |
| PreRequisites  | None                                 | Imports [BuildHelper](./BuildHelper.psm1) module.                                                                  |
| Build.Module   | PreRequisites                        | Compiles versioned [FinOpsToolkit](.././src/powershell/FinOpsToolkit.psm1) module.                                 |
| Publish.Module | PreRequisites, Build.Module          | Publishes versioned [FinOpsToolkit](.././src/powershell/FinOpsToolkit.psm1) module to the [PowerShell Gallery](https://www.powershellgallery.com/).                                                                                                                                        |
| Tests.Unit     | PreRequisites                        | Runs unit tests from [FinOpsToolkit.Tests.ps1](.././src/powershell/Tests/Unit/FinOpsToolkit.Tests.ps1).            |
| Tests.Meta     | PreRequisites                        | Runs style tests using default rules from [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer).      |
| Tests.All      | PreRequisites, Tests.Unit, Tests.All | Imports [BuildHelper](./BuildHelper.psm1) module.                                                                  |

<br>

### build.depends.psd1

[./build.depends.psd1](./build.depends.psd1) Static dependency definition for build process. For more information, see [PsDepend](https://github.com/RamblingCookieMonster/PSDepend).

## 📦 Build Helper

[BuildHelper.psm1](./BuildHelper.psm1) Internal module for build automation.

### Commands

#### Build-FinOpsModule

[Build-FinOpsModule.ps1](./BuildHelper/Build-FinOpsModule.ps1) Compiles the FinOpsToolkit module into a versioned package ready for publishing.

| Parameter        | Description                                                                                       |
| ---------------- | ------------------------------------------------------------------------------------------------- |
| `-Version`       | Required. Semantic version for the module.                                                        |
| `-PreReleaseTag` | Optional. Tag indicating the version is a pre-release. Acceptable values are: "alpha", "preview". |

### Start-PesterTest

[Start-PesterTest.ps1](./BuildHelper/Start-PesterTest.ps1) Runs [Pester](https://pester.dev/) tests for the FinOpsToolkit module.

| Parameter | Description                                                            |
| --------- | -----------------------------------------------------------------------|
| `-Type`   | Required. Type of tests to run. Acceptable values are: "Unit", "Meta". |

### New-Directory

[New-Directory.ps1](./BuildHelper/New-Directory.ps1) Creates new directory if it does not exist.

| Parameter | Description                      |
| --------- | -------------------------------- |
| `-Path`   | Required. Folder path to create. |

<br>
