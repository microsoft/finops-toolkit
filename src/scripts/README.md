# 📜 FinOps toolkit scripts

FinOps toolkit scripts are used for local development, testing, and publishing only.

On this page:

- [🆕 Init-Repo](#-init-repo)
- [📦 Build-Toolkit](#-build-toolkit)
- [🚀 Deploy-Toolkit](#-deploy-toolkit)
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
- Bicep

<br>

## 📦 Build-Toolkit

[Build-Toolkit.ps1](./Build-Toolkit.ps1) builds toolkit modules and templates for local testing and and to prepare them for publishing.

Example:

```powershell
./Build-Toolkit
```

Build-Toolkit runs the following scripts internally:

- [Build-Bicep](./Build-Bicep.ps1) for Bicep Registry modules
- [Build-Workbook](./Build-Workbook.ps1) for Azure Monitor workbook templates

<br>

## 🚀 Deploy-Toolkit

[Deploy-Toolkit.ps1](./Deploy-Toolkit.ps1) deploys toolkit templates for local testing purposes.

| Parameter        | Description                                                                                                                        |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `-Template`      | Required. Name of the template or module to deploy. Default = finops-hub.                                                          |
| `-ResourceGroup` | Optional. Name of the resource group to deploy to. Will be created if it doesn't exist. Default = `ftk-<username>-<computername>`. |
| `-Location`      | Optional. Azure location to execute the deployment from. Default = `westus`.                                                       |
| `-Parameters`    | Optional. Parameters to pass thru to the deployment. Defaults per template/module are configured in the script.                    |
| `-Build`         | Optional. Indicates whether the the `Build-Toolkit` command should be executed first. Default = `false`.                           |
| `-Test`          | Optional. Indicates whether to run the template or module test instead of the template or module itself. Default = `false`.        |
| `-Debug`         | Optional. Writes script execution troubleshooting details to console. Does not execute deployment.                                 |
| `-WhatIf`        | Optional. Validates the deployment without executing it or changing resources.                                                     |

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

<br>

## 🚚 Publish-Toolkit

[Publish-Toolkit.ps1](./Publish-Toolkit.ps1) publishes a template to the Azure Quickstart Templates repository.

| Parameter      | Description                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `-Template`    | Required. Name of the template or module to deploy.                                                                      |
| `-Destination` | Required. Path to the local clone of the Azure Quickstart Templates repository.                                          |
| `-Build`       | Optional. Indicates whether the the `Build-Toolkit` command should be executed first. Default = `false`.                 |
| `-Commit`      | Optional. Indicates whether to commit the changes and start a pull request in the Azure Quickstart Templates repository. |

Example:

```powershell
./Publish-Toolkit "finops-hub" "../../../aqt" -Build -Commit
```

<br>

## 📦 Package-Toolkit

[Package-Toolkit.ps1](./Package-Toolkit.ps1) packages all toolkit templates as ZIP files for release.

| Parameter   | Description                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------ |
| `-Template` | Optional. Name of the template or module to package. Default = \* (all).                         |
| `-Build`    | Optional. Indicates whether the Build-Toolkit command should be executed first. Default = false. |

Examples:

- Generate ZIP files for each template using an existing build.

  ```powershell
  ./Package-Toolkit
  ```

- Builds the latest code and generates ZIP files for each template.

  ```powershell
  ./Package-Toolkit -Build
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
| `-Branch`      | Optional. Name of the branch to merge into. Default = "." (current branch).                                                                                                                                 |
| `-TortoiseGit` | Optional. Indicates whether to use TortoiseGit to resolve conflicts. Default = false.                                                                                                                       |
| `-Silent`      | Optional. Indicates whether to hide informational output. Will abort merge if there are any conflicts. Use `$LASTEXITCODE` to determine status (0 = successful, 1 = error, 2 = conflicts). Default = false. |

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
