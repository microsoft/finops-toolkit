# 📜 FinOps toolkit scripts

FinOps toolkit scripts are used for local development and testing only.

On this page:

- [🆕 Init-Repo](#-init-repo)
- [📦 Build-Toolkit](#-build-toolkit)
- [🚀 Deploy-Toolkit](#-deploy-toolkit)
- [📁 New-Directory](#-new-directory)

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
- [Build-Workbook](./Build-Workbook.ps1) for workbooks

<br>

## 🚀 Deploy-Toolkit

[Deploy-Toolkit.ps1](./Deploy-Toolkit.ps1) deploys toolkit templates for local testing purposes.

Parameters:


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

## 📁 New-Directory

[New-Directory.ps1](./New-Directory.ps1) creates a new directory without failing if it already exists and without writing data to the console.

Example:

```powershell
./New-Directory "C:\Temp\NewDirectory"
```

<br>
