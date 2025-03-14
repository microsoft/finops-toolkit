# 📜 FinOps toolkit scripts

FinOps toolkit scripts are used for local development, testing, and publishing only.

On this page:

- [🆕 Init-Repo](#-init-repo)
- [🌐 Build-OpenData](#-build-opendata)
- [📦 Build-Toolkit](#-build-toolkit)
- [🚀 Deploy-Toolkit](#-deploy-toolkit)
- [🧪 Test-PowerShell](#-test-powershell)
- [🏷️ Get-Version](#️-get-version)
- [🏷️ Update-Version](#️-update-version)
- [🚚 Publish-Toolkit](#-publish-toolkit)
- [📦 Package-Toolkit](#-package-toolkit)
- [©️ Add-CopyrightHeader](#️-add-copyrightheader)
- [📁 New-Directory](#-new-directory)
- [🌿 New-FeatureBranch](#-new-featurebranch)
- [🔀 Merge-DevBranch](#-merge-devbranch)

---

## 🆕 Init-Repo

[Init-Repo.ps1](./Init-Repo.ps1) initializes your local dev environment with the following tools, which are required for development and testing:

- Az PowerShell module
- Bicep CLI

The following optional apps/modules can be installed with the corresponding parameters or with the `‑All` parameter:

- Visual Studio Code
- Bicep PowerShell module
- NodeJS and configured modules (-NPM parameter)
- Pester PowerShell module

If an app or module is already installed, it will be skipped. To see which apps would be installed, use the -WhatIf parameter.

Examples:

- Checks to see what apps/modules would be installed:

  ```powershell
  ./Init-Repo -All -WhatIf
  ```

- Installs only required apps/modules:

  ```powershell
  ./Init-Repo
  ```

- Installs all required and specific apps/modules:

  ```powershell
  ./Init-Repo -VSCode -NPM -Pester
  ```

- Installs all required and optional apps/modules:

  ```powershell
  ./Init-Repo -All
  ```

<br>

## 🌐 Build-OpenData

[Build-OpenData.ps1](./Build-OpenData.ps1) generates data files, PowerShell commands, and FinOps hubs KQL functions for open data. PowerShell commands are private and not shared externally today &ndash; they're meant to be used by other specifically-designed commands, which is outside the scope of Build-OpenData. FinOps hubs KQL functions are available from the hub Ingestion database. File updates must be manually checked in and the script only needs to be run when datasets are added or updated.

Examples:

- Build all PowerShell functions:

  ```powershell
  ./Build-OpenData
  ```

- Build one PowerShell function:

  ```powershell
  ./Build-OpenData -Name Regions
  ```

- Build data files only:

  ```powershell
  ./Build-OpenData -Data
  ```

- Build FinOps hubs KQL functions only:

  ```powershell
  ./Build-OpenData -Hubs
  ```

  After running this script, if new open data KQL files are created, you will need to also update dataExplorer.bicep to include them in the Data Explorer deployment.

- Build data files and PowerShell functions:

  ```powershell
  ./Build-OpenData -All
  ```

- Run PowerShell tests after the build completes:

  ```powershell
  ./Build-OpenData -Test
  ```

<br>

## 📦 Build-Toolkit

[Build-Toolkit.ps1](./Build-Toolkit.ps1) builds toolkit modules and templates for local testing and and to prepare them for publishing.

Examples:

- Build all toolkit modules and templates:

  ```powershell
  ./Build-Toolkit
  ```

- Build all toolkit modules and templates from any directory via NPM:

  ```console
  npm run build
  ```

- Build all toolkit modules and templates from VS Code:

  <kbd>Ctrl+Shift+P</kbd> > <kbd>Run Build Task</kbd> > <kbd>Build Toolkit</kbd>

Build-Toolkit runs the following scripts internally:

- [Build-Bicep](./Build-Bicep.ps1) for Bicep Registry modules
- [Build-Workbook](./Build-Workbook.ps1) for Azure Monitor workbook templates

<br>

## 🚀 Deploy-Toolkit

[Deploy-Toolkit.ps1](./Deploy-Toolkit.ps1) deploys toolkit templates for local testing purposes.

| Parameter        | Description                                                                                                                        |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `‑Template`      | Required. Name of the template or module to deploy. Default = finops-hub.                                                          |
| `‑ResourceGroup` | Optional. Name of the resource group to deploy to. Will be created if it doesn't exist. Default = `ftk-<username>-<computername>`. |
| `‑Location`      | Optional. Azure location to execute the deployment from. Default = `westus`.                                                       |
| `‑Parameters`    | Optional. Parameters to pass thru to the deployment. Defaults per template/module are configured in the script.                    |
| `‑Build`         | Optional. Indicates whether the the `Build-Toolkit` command should be executed first. Default = `false`.                           |
| `‑Test`          | Optional. Indicates whether to run the template or module test instead of the template or module itself. Default = `false`.        |
| `‑Debug`         | Optional. Writes script execution troubleshooting details to console. Does not execute deployment.                                 |
| `‑WhatIf`        | Optional. Validates the deployment without executing it or changing resources.                                                     |

Examples:

- Basic template deployment validation (requires resource group to exist):

  ```powershell
  ./Deploy-Toolkit -WhatIf
  ```

- Deploy a specific template:

  ```powershell
  ./Deploy-Toolkit "finops-hub"
  ```

- Build and deploy a Bicep Registry module test:

  ```powershell
  ./Deploy-Toolkit "subscription-scheduled-action" -Build -Test
  ```

- Build and deploy a module from any directory via NPM:

  ```console
  npm run deploy "finops-hub"
  ```

- Build and deploy a module test (`main.test.bicep` file) from any directory via NPM:

  ```console
  npm run deploy-test "finops-hub"
  ```

<br>

## 🧪 Test-PowerShell

[Test-PowerShell.ps1](./Test-PowerShell.ps1) runs Pester tests.

By default, only unit tests are run. If only one test type is specified, only that test type will be run. If multiple are specified, each of them will be run. Other options will apply to all test types that are selected. Select -AllTests to run all test types.

To investigate the previous test run, use `$global:ftk_TestPowerShell_Results`.

To view a summary of only the failed tests, use `$global:ftk_TestPowerShell_Summary`.

To view the configuration used to re-run previously failed tests, use `$global:ftk_TestPowerShell_FailedTests`.

| Parameter      | Description                                                                                                                                            |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `‑Cost`        | Optional. Indicates whether to run Cost Management tests.                                                                                              |
| `‑Data`        | Optional. Indicates whether to run open data tests.                                                                                                    |
| `‑Exports`     | Optional. Indicates whether to run Cost Management export tests.                                                                                       |
| `‑FOCUS`       | Optional. Indicates whether to run FOCUS tests.                                                                                                        |
| `‑Hubs`        | Optional. Indicates whether to run FinOps hubs tests.                                                                                                  |
| `‑Toolkit`     | Optional. Indicates whether to run generic toolkit tests.                                                                                              |
| `‑Integration` | Optional. Indicates whether to run integration tests, which take more time than unit tests by testing external dependencies. Default = false.          |
| `‑Lint`        | Optional. Indicates whether to run lint tests, which validate local files are meeting dev standards. Default = false.                                  |
| `‑Unit`        | Optional. Indicates whether to run unit tests. Default = true.                                                                                         |
| `‑AllTests`    | Optional. Indicates whether to run all lint, unit, and integration tests. If set, this overrides Lint, Unit, and Integration options. Default = false. |

Examples:

- Run all unit tests:

  ```powershell
  ./Test-PowerShell
  ```

- Run all integration tests:

  ```powershell
  ./Test-PowerShell -Integration
  ```

- Run unit and integration tests for a specific area:

  ```powershell
  ./Test-PowerShell -Hubs -Integration
  ```

- Run all tests:

  ```powershell
  ./Test-PowerShell -AllTests
  ```

- Re-run failed tests:

  ```powershell
  ./Test-PowerShell -RunFailed
  ```

<br>

## 🏷️ Get-Version

[Get-Version.ps1](./Get-Version.ps1) gets the latest version of the toolkit.

| Parameter          | Description                                                                                                                               |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `‑AsDotNetVersion` | Optional. Indicates that the returned version should be in the format "x.x.x.x". Otherwise, semantic versioning is used. Deafult = false. |

Example:

```powershell
./Get-Version
```

<br>

## 🏷️ Update-Version

[Update-Version.ps1](./Update-Version.ps1) updates the toolkit version in the following places:

- NPM (central tracking for the version)
- PowerShell's private Get-VersionNumber command (used for internal version number usage)
- All `ftkver.txt` files in the repo (used for templates and docs)

| Parameter     | Description                                                                                                      |
| ------------- | ---------------------------------------------------------------------------------------------------------------- |
| `‑Major`      | Optional. Increments the major version number (x.0).                                                             |
| `‑Minor`      | Optional. Increments the minor version number (0.x).                                                             |
| `‑Patch`      | Optional. Increments the patch version number (0.0.x).                                                           |
| `‑Prerelease` | Optional. Increments the prerelease version number (0.0.0-ooo.x).                                                |
| `‑Label`      | Optional. Indicates the label to use for prerelease versions. Allowed: dev, rc, alpha, preview. Default = "dev". |
| `‑Version`    | Optional. Sets the version number to an explicit value.                                                          |

Examples:

- Increments the major version number (for example, `1.0` to `2.0`).

  ```powershell
  ./Update-Version -Major
  ```

- Increments the prerelease version number with an "alpha" preview label (for example, `1.0` to `1.0.1-alpha`).

  ```powershell
  ./Update-Version -Prerelease -Label "alpha"
  ```

<br>

## 🚚 Publish-Toolkit

[Publish-Toolkit.ps1](./Publish-Toolkit.ps1) publishes a toolkit template, module, or documentation to its destination repo.

| Parameter         | Description                                                                                                             |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `‑Template`       | Name of the template or module to publish. Default = * (all templates).                                                 |
| `‑QuickstartRepo` | Optional. Name of the folder where the Azure Quickstart Templates repo is cloned. Default = azure-quickstart-templates. |
| `‑RegistryRepo`   | Optional. Name of the folder where the Bicep Registry repo is cloned. Default = bicep-registry-modules.                 |
| `‑Build`          | Optional. Indicates whether the the Build-Toolkit command should be executed first. Default = false.                    |
| `‑Branch`         | Optional. Indicates whether the changes should be committed to a new branch in the Git repo. Default = false.           |

Examples:

- Builds and publishes the FinOps hub template to the Azure Quickstart Templates repo, commits changes, and pushes to the fork to prepare for a PR.
  
  ```powershell
  ./Publish-Toolkit "finops-hub" -Build -Commit
  ```

- Builds and publishes the resource group scheduled action module to the Bicep Registry repo locally but does not commit.
  
  ```powershell
  ./Publish-Toolkit "resourcegroup-scheduled-action" -Build
  ```

- Publishes documentation to the Microsoft Learn repo locally but does not commit.
  
  ```powershell
  ./Publish-Toolkit "docs"
  ```

<br>

## 📦 Package-Toolkit

[Package-Toolkit.ps1](./Package-Toolkit.ps1) packages all toolkit templates as ZIP files for release.

| Parameter   | Description                                                                                                                |
| ----------- | -------------------------------------------------------------------------------------------------------------------------- |
| `‑Template` | Optional. Name of the template or module to package. Default = \* (all).                                                   |
| `‑Build`    | Optional. Indicates whether the Build-Toolkit command should be executed first. Default = false.                           |
| `‑PowerBI`  | Optional. Indicates whether to open Power BI files as part of the packaging process. Default = false.                      |
| `‑Preview`  | Optional. Indicates that the template(s) should be saved as a preview only. Does not package other files. Default = false. |

Examples:

- Generate ZIP files for each template using an existing build.

  ```powershell
  ./Package-Toolkit
  ```

- Builds the latest code and generates ZIP files for each template.

  ```powershell
  ./Package-Toolkit -Build

- Builds the latest version of a specific template and updates the deployment files for the website.

  ```powershell
  ./Package-Toolkit finops-workbooks -Build -Preview
  ```

<br>

## ©️ Add-CopyrightHeader

[Add-CopyrightHeader.ps1](./Add-CopyrightHeader.ps1) checks all files to ensure they have a copyright header. Generates a summary of the number of files checked, files updated, and file types that are not supported. Run this script whenever adding new code files.

If unsupported file types are found, the script needs to be updated to either specify the comment character(s) or ignore the file type.

To specify the comment character(s), update the `$fileTypes` variable:

```powershell
$fileTypes = @{
    "bicep" = "//"
    "ps1"   = "#"
    "psd1"  = "#"
    "psm1"  = "#"
}
```

To ignore a file type, add it to the `Get-ChildItem -Exclude` list:

```powershell
Get-ChildItem `
    -Path ../ `
    -Recurse `
    -Include *.* `
    -Exclude *.abf, *.bim, .buildignore, .gitignore, *.json, *.md, *.pbidataset, *.pbip, *.pbir, *.pbix, *.png, *.svg `
    -File
```

<br>

## 📁 New-Directory

[New-Directory.ps1](./New-Directory.ps1) creates a new directory without failing if it already exists and without writing data to the console.

Example:

```powershell
./New-Directory "C:\Temp\NewDirectory"
```

<br>

## 🌿 New-FeatureBranch

[New-FeatureBranch.ps1](./New-FeatureBranch.ps1) creates a new feature branch.

Example:

```powershell
./New-FeatureBranch "foo"
```

<br>

## 🔀 Merge-DevBranch

[Merge-DevBranch.ps1](./Merge-DevBranch.ps1) merges the `dev` branch into the specified branch.

| Parameter      | Description                                                                                                                                                                                                 |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Branch`      | Optional. Name of the branch to merge into. Default = "." (current branch).                                                                                                                                 |
| `‑TortoiseGit` | Optional. Indicates whether to use TortoiseGit to resolve conflicts. Default = false.                                                                                                                       |
| `‑Silent`      | Optional. Indicates whether to hide informational output. Will abort merge if there are any conflicts. Use `$LASTEXITCODE` to determine status (0 = successful, 1 = error, 2 = conflicts). Default = false. |

Examples:

- Merge the `dev` branch into the current branch.

  ```powershell
  ./Merge-DevBranch
  ```

- Merge the `dev` branch into the `features/foo` branch and uses TortoiseGit to resolve conflicts.

  ```powershell
  ./Merge-DevBranch features/foo -TortoiseGit
  ```

- Merge the `dev` branch into all feature branches. Does not resolve conflicts.

  ```powershell
  ./Merge-DevBranch *
  ```

<br>
