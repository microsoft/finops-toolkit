# 🔍 Azure Optimization Engine

This folder contains all the assets needed to deploy and manage the Azure Optimization Engine (AOE). AOE is an extensible solution designed to generate optimization recommendations for your Azure environment. To contribute to AOE, we recommend you to first deploy it in your environment, preferably in an Azure tenant in which you have all the required and optional permissions (see [requirements](#-requirements)). Reading the [AOE documentation](https://aka.ms/AzureOptimizationEngine) is also recommended.

On this page:

- [🏯 Architecture](#-architecture)
- [📋 Requirements](#-requirements)
- [➕ Deployment instructions](#-deployment-instructions)
- [🛫 Get started with AOE](#-get-started-with-aoe)

## 🏯 Architecture

AOE runs mostly on top of Azure Automation and Log Analytics. The diagram below depicts the architectural components. For a more detailed description, please
read [this blog post](https://aka.ms/AzureOptimizationEngine/rightsizeblogpt1).

![Azure Optimization Engine architecture](images/aoe/architecture.jpg "Azure Optimization Engine architecture")

## 📋 Requirements

To deploy and test AOE in your development environment, you need to fulfill some tooling and Azure permissions requirements. See more details [here](https://aka.ms/AzureOptimizationEngine/requirements).

## ➕ Deployment instructions

The simplest, quickest and recommended method for installing AOE is by using the **Azure Cloud Shell** (PowerShell). Check [here](https://aka.ms/AzureOptimizationEngine/deployment) the detailed list of deployment instructions. If you are working on a branch other than `main` and need to test the AOE deployment, use the following PowerShell instruction:

```powershell
.\Deploy-AzureOptimizationEngine.ps1 -TemplateUri "https://raw.githubusercontent.com/<GitHub user>/<repository>/<branch name>/src/optimization-engine/azuredeploy.bicep"

# Example:

.\Deploy-AzureOptimizationEngine.ps1 -TemplateUri "https://raw.githubusercontent.com/helderpinto/finops-toolkit-hp-fork/features/aoe/src/optimization-engine/azuredeploy.bicep"
```

## 🛫 Get started with AOE

After deploying AOE, there are several ways for you to get started contributing:

1. Develop new Azure Workbooks or improve existing ones. AOE Workbooks are available from within the Log Analytics workspace chosen during installation (check the `Workbooks` blade inside the workspace). Check the Workbooks [code](./views/workbooks/) and [documentation](https://aka.ms/AzureOptimizationEngine/reports). 

1. Improve the built-in [Power BI report](./views/). See [documentation](https://aka.ms/AzureOptimizationEngine/reports) for an understanding of all report pages.

1. Contribute with new optimization recommendations or improve existing ones (check the [Runbooks folder](./runbooks/)).
