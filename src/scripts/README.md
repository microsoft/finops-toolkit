# FinOps toolkit scripts

FinOps toolkit scripts are used for local development and testing only.

On this page:

- [Init-Repo](#init-repo)
- [Deploy-Toolkit](#deploy-toolkit)

---

## Init-Repo

[Init-Repo.ps1](./Init-Repo.ps1) initializes your local dev environment with the following tools, which are required for development and testing:

- Az PowerShell module
- Bicep

<br>

## Deploy-Toolkit

[Deploy-Toolkit.ps1](./Deploy-Toolkit.ps1) deploys toolkit templates for local testing purposes.

Parameters:

- ResourceGroup (Default: "ftk-<username>-<computername>")
- Location (Default: "westus")
- Template (Default: "finops-hub")
