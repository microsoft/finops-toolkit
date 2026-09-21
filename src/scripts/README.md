# 📜 FinOps toolkit scripts

FinOps toolkit scripts are used for local development, testing, and publishing only.

On this page:

- [🆕 Init-Repo](#-init-repo)
- [🔧 Initialize-CI](#-initialize-ci)
- [🌐 Build-OpenData](#-build-opendata)
- [📦 Build-Toolkit](#-build-toolkit)
- [🚀 Deploy-Hub](#-deploy-hub)
- [🚀 Deploy-Toolkit](#-deploy-toolkit)
- [🧪 Test-PowerShell](#-test-powershell)
- [🏷️ Get-Version](#️-get-version)
- [🏷️ Update-Version](#️-update-version)
- [🚚 Publish-Toolkit](#-publish-toolkit)
- [🎬 Deploy-Demo](#-deploy-demo)
- [📊 Build-PowerBI](#-build-powerbi)
- [📊 Package-PowerBI](#-package-powerbi)
- [📊 Save-PowerBIProject](#-save-powerbiproject)
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

## 🔧 Initialize-CI

[Initialize-CI.ps1](./Initialize-CI.ps1) is a one-time setup script that creates the Azure AD app registration, service principal, federated credential, and GitHub environment needed for per-PR deployment CI.

Prerequisites:

- Logged into Azure (`Connect-AzAccount`) with permissions to create app registrations and grant subscription-level RBAC (Contributor + User Access Administrator).
- Logged into GitHub CLI (`gh auth login`) with permissions to create environments and secrets in the target repository.

| Parameter          | Description                                                                                    |
| ------------------ | ---------------------------------------------------------------------------------------------- |
| `‑SubscriptionId`  | Required. Azure subscription ID for PR deployments and cost exports.                           |
| `‑Repository`      | Optional. GitHub repo in `owner/repo` format. Default: `microsoft/finops-toolkit`.             |
| `‑WhatIf`          | Optional. Preview without making changes.                                                      |

Examples:

- Set up CI for a subscription:

  ```powershell
  ./Initialize-CI -SubscriptionId "aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e"
  ```

- Preview what would be created:

  ```powershell
  ./Initialize-CI -SubscriptionId "aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" -WhatIf
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

## 🚀 Deploy-Hub

[Deploy-Hub.ps1](./Deploy-Hub.ps1) is a wrapper around Deploy-Toolkit that simplifies FinOps hub deployments by providing scenario-based flags instead of requiring you to remember all the Bicep parameter names.

By default, deploys with Azure Data Explorer (dev SKU). Use `-StorageOnly` for storage-only or `-Fabric` for Fabric-based deployments.

All resources use an `{initials}-{name}` naming convention where initials are pulled from `git config user.name` and name defaults to `adx`. Pass a name as the first positional parameter to use a custom value (e.g., `216` for Feb 16).

| Parameter          | Description                                                                                                                                                                          |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `‑Name`            | Optional. First positional parameter. Suffix for `{initials}-{name}` convention. Default: `adx`.                                                                                     |
| `‑HubName`         | Optional. Name of the hub instance. Default: `hub`.                                                                                                                                  |
| `‑ADX`             | Optional. Name of the Azure Data Explorer cluster. Overrides the `{initials}-{name}` convention.                                                                                     |
| `‑ResourceGroup`   | Optional. Name of the resource group. Overrides the `{initials}-{name}` convention.                                                                                                  |
| `‑Fabric`          | Optional. Deploy with Microsoft Fabric. Provide the eventhouse query URI.                                                                                                            |
| `‑StorageOnly`     | Optional. Deploy a storage-only hub (no Azure Data Explorer or Fabric).                                                                                                              |
| `‑Recommendations` | Optional. Enable recommendations with all noisy recommendation types (AHB, Spot).                                                                                                    |
| `‑Scope`           | Optional. Azure scope ID for cost data exports (e.g., `/subscriptions/{id}`). With `-ManagedExports`, enables managed exports. Without it, creates exports manually.                 |
| `‑ManagedExports`  | Optional. Use managed exports instead of manual exports. Requires `-Scope`. Passes `scopesToMonitor` to the template and grants the hub identity required roles.                     |
| `‑PR`              | Optional. PR number for CI deployments. Resources are named `pr-{number}` or `pr-{number}-{name}` when `-Name` is also specified.                                                    |
| `‑Location`        | Optional. Azure location. Default: `westus`.                                                                                                                                         |
| `‑Remove`          | Optional. Remove test environments. With a name, deletes the target RG. Alone, lists all `{initials}-*`.                                                                             |
| `‑Build`           | Optional. Build the template before deploying.                                                                                                                                       |
| `‑WhatIf`          | Optional. Validate the deployment without making changes.                                                                                                                            |

Examples:

- Deploy a hub with ADX (e.g., RG `aa-adx`, ADX `aa-adx`):

  ```powershell
  ./Deploy-Hub
  ```

- Deploy to a named environment (e.g., RG `aa-216`, ADX `aa-216`):

  ```powershell
  ./Deploy-Hub 216
  ```

- Deploy a storage-only hub:

  ```powershell
  ./Deploy-Hub -StorageOnly
  ```

- Deploy with Microsoft Fabric:

  ```powershell
  ./Deploy-Hub -Fabric "https://my-eventhouse.kusto.data.microsoft.com"
  ```

- Build the template first, then deploy:

  ```powershell
  ./Deploy-Hub -Build
  ```

- Clean up a specific test environment (e.g., `aa-210`):

  ```powershell
  ./Deploy-Hub -Remove 210
  ```

- List all test environments:

  ```powershell
  ./Deploy-Hub -Remove
  ```

- Deploy with PR naming convention (e.g., RG `pr-123-adx`, ADX `pr-123-adx`):

  ```powershell
  ./Deploy-Hub -PR 123 -Name adx
  ```

- Deploy with managed exports:

  ```powershell
  ./Deploy-Hub -PR 123 -Name adx -Scope "/subscriptions/{id}" -ManagedExports -Build
  ```

- Deploy storage-only with manual exports:

  ```powershell
  ./Deploy-Hub -StorageOnly -Scope "/subscriptions/{id}" -Build
  ```

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

| Parameter          | Description                                                                                                                     |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| `‑Template`        | Optional. Name of the template or module to publish. Default = * (all templates).                                               |
| `‑QuickstartRepo`  | Optional. Name of the folder where the Azure Quickstart Templates repo is cloned. Default = azure-quickstart-templates.         |
| `‑RegistryRepo`    | Optional. Name of the folder where the Bicep Registry repo is cloned. Default = bicep-registry-modules.                         |
| `‑AppInsightsRepo` | Optional. Name of the folder where the Application Insights Workbooks repo is cloned. Default = Application-Insights-Workbooks. |
| `‑DocsRepo`        | Optional. Name of the folder where the Partner Center documentation repo is cloned. Default = partner-center-pr.                |
| `‑Build`           | Optional. Indicates whether the Build-Toolkit command should be executed first. Default = false.                                |
| `‑Branch`          | Optional. Indicates whether the changes should be committed to a new branch in the Git repo. Alias: Commit. Default = false.    |

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

## 🎬 Deploy-Demo

[Deploy-Demo.ps1](./Deploy-Demo.ps1) deploys and refreshes the FinOps hub instances that demo Power BI reports are built from.

Demo reports in `PowerBI-demo.zip` are saved with data from a demo hub, so that hub has to be on the version being released and have data for the current month. Otherwise the demo either fails to refresh or ships with stale numbers.

Two kinds of instances:

- `ftk-demo` is the current demo hub, with 12 months of data. Demo reports are built from it.
- `ftk-demo-v{version}` keeps one month of data for testing an older release. Stop its Data Explorer cluster after ingestion and it costs almost nothing to keep.

Run `-Check` before a release. It reports the hub version and months of data, and fails when the hub is behind the toolkit version or has no data for the current month.

| Parameter        | Description                                                                                       |
| ---------------- | ------------------------------------------------------------------------------------------------- |
| `‑Version`       | Optional. Deploys the versioned instance for a release (for example, "v15"). Default = the current demo hub. |
| `‑Subscription`  | Optional. Name or ID of the subscription to deploy to. Default = "FTK Prod".                       |
| `‑ResourceGroup` | Optional. Name of the resource group. Default = the instance name.                                 |
| `‑Location`      | Optional. Azure region. Default = "westus".                                                        |
| `‑Scope`         | Optional. Resource IDs to export cost data for. Default = the subscription being deployed to.      |
| `‑Retention`     | Optional. Months of data the hub keeps. Default = 12, or 1 for a versioned instance.               |
| `‑Backfill`      | Optional. Months of history to load. Backfilling is a one-time task for a new instance, so nothing is backfilled unless specified. |
| `‑Check`         | Optional. Reports whether the demo hub is ready for a release without changing anything.           |
| `‑Stop`          | Optional. Stops the Data Explorer cluster when finished. Default = true for versioned instances.   |
| `‑Build`         | Optional. Builds the templates before deploying.                                                   |

Examples:

- Check whether the demo hub is ready for a release.

  ```powershell
  ./Deploy-Demo -Check
  ```

- Deploy or update the demo hub. Exports keep running on their own, so nothing is backfilled.

  ```powershell
  ./Deploy-Demo
  ```

- Load 12 months of history, which a new instance needs once.

  ```powershell
  ./Deploy-Demo -Backfill 12
  ```

- Deploy the versioned instance for v15.

  ```powershell
  ./Deploy-Demo -Version v15 -Backfill 1
  ```

<br>

## 📊 Build-PowerBI

[Build-PowerBI.ps1](./Build-PowerBI.ps1) generates the Power BI release artifacts:

- One PBIT template per report in `release/pbit`, zipped into `PowerBI-kql.zip` and `PowerBI-storage.zip`.
- One PBIP project per demo report (storage reports) in `release/pbix`, containing only the tables, relationships, and queries that report needs.

Both come from a single prune, so the template and the demo report always match. The tables and queries each report keeps are listed in [src/power-bi/reports.json](../power-bi/reports.json). When you add a table or query to a report, add it there too.

Templates ship with the data source parameters set to null. Demo projects keep the data source saved in the semantic model, which points at the demo hub.

Demo reports ship to customers, so they read open data over HTTP like the templates do. They can't use the release URL, because it resolves to the last published release, which doesn't have open data files added during the release being built. `‑OpenDataUrl` sets where they read it from, and defaults to the open data files in the `main` branch. Every URL is checked at build time, so a file that isn't published yet fails here instead of when someone refreshes the demo.

The URL ends up inside the demo reports, so it has to outlive the release. Only the `main` branch and release URLs are accepted. The release process merges to `main` before packaging Power BI, so the default is correct at release time.

To build demo reports before that merge, add `‑TestOpenDataUrl` and pass a branch with `‑OpenDataUrl`. Those reports can't be released: the build warns, records it in the manifest, and `Package-PowerBI` refuses to package them.


The build fails, with a message that names the report and what to add to `reports.json`, when:

- A table the report keeps has columns that only differ by case, which Power BI can't load.
- A visual on a visible page reads from a table the report doesn't keep. Hidden pages only log a warning.
- A query, table, or measure the report keeps uses a table or query the report doesn't keep.

| Parameter  | Description                                                                                  |
| ---------- | -------------------------------------------------------------------------------------------- |
| `‑Name`    | Optional. Name of the report to build. Wildcards supported. Default = \* (all).              |
| `‑KQL`     | Optional. Builds the KQL reports. Default = false (builds all if no types are selected).     |
| `‑Storage` | Optional. Builds the storage reports. Default = false (builds all if no types are selected). |
| `‑NoPbip`  | Optional. Skips generating PBIP projects and only builds PBIT templates. Default = false.    |

Examples:

- Generate all templates and projects.

  ```powershell
  ./Build-PowerBI
  ```

- Generate the Cost summary storage template and project.

  ```powershell
  ./Build-PowerBI CostSummary -Storage
  ```

<br>

## 📊 Package-PowerBI

[Package-PowerBI.ps1](./Package-PowerBI.ps1) packages the three Power BI release files and reports what's left to do.

On Windows, `-Unattended` does everything with one command: build, save demo PBIX files with Power BI Desktop (using [Save-PowerBIProject](#-save-powerbiproject)), validate, and package. Don't use the mouse or keyboard while it runs.

Without `-Unattended`, the command is resumable: run it, save the projects it opens, then run it again. Either way, it works out which steps are already done, does the next one, and validates the result.

Saved PBIX files are checked for the mistakes that are easy to make by hand — saved without data, saved from the unpruned source project, saved on the wrong page, saved with the wrong sensitivity label, or saved before the latest build — so a missed step fails here instead of shipping. With `-Unattended`, files that fail these checks are saved again automatically.

| Parameter           | Description                                                                                                                        |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `‑Unattended`       | Optional. Saves the projects with Power BI Desktop automatically, then validates and packages them. Windows only. Default = false. |
| `‑Open`             | Optional. Opens the projects that still need to be saved as PBIX files. Default = false.                                           |
| `‑Build`            | Optional. Rebuilds the templates and projects even if they already exist. Default = false.                                         |
| `‑Status`           | Optional. Reports what's done and what's left without changing anything. Default = false.                                          |
| `‑SensitivityLabel` | Optional. Sensitivity label demo reports must have, if they have one. Default = "Public".                                          |

Examples:

- Build, save, validate, and package everything (Windows).

  ```powershell
  ./Package-PowerBI -Unattended
  ```

- Build whatever is missing and report the next step.

  ```powershell
  ./Package-PowerBI
  ```

- Open the projects that still need to be saved as PBIX files.

  ```powershell
  ./Package-PowerBI -Open
  ```

<br>

## 📊 Save-PowerBIProject

[Save-PowerBIProject.ps1](./Save-PowerBIProject.ps1) opens one Power BI project in Power BI Desktop, refreshes its data, applies the sensitivity label, saves it as a PBIX file, and closes Power BI Desktop. `Package-PowerBI -Unattended` calls it for each demo report, so you usually don't need to run it directly.

Data is refreshed through the Analysis Services engine that Power BI Desktop runs locally, so refresh errors stop the script instead of saving an empty report. Saving uses Windows UI Automation. If a step can't be automated, the script stops with a message that names the step and saves a screenshot next to the PBIX file (`*.error.png`). Save that report by hand and rerun `Package-PowerBI`.

Requirements:

- Windows with Power BI Desktop installed and associated with `.pbip` files.
- An interactive desktop session. Don't use the mouse or keyboard while it runs.
- Sign in to Power BI Desktop, and refresh one demo project by hand once so Power BI Desktop stores the credentials for the demo data source. Nothing here can sign in or answer a credential prompt. A sign-in window stops the script right away, and a missing credential fails the refresh with the error the engine reports.

The sensitivity label is only applied when Power BI Desktop offers one, which needs a signed-in account. A report saved without a label still passes validation; a report saved with any label other than the expected one fails.

| Parameter           | Description                                                                                                    |
| ------------------- | -------------------------------------------------------------------------------------------------------------- |
| `‑Path`             | Required. Path to the PBIP file to open.                                                                       |
| `‑Destination`      | Optional. Path of the PBIX file to save. Default = the PBIP path with a .pbix extension.                       |
| `‑SensitivityLabel` | Optional. Name of the sensitivity label to apply. Default = "Public".                                          |
| `‑TimeoutMinutes`   | Optional. Maximum number of minutes to wait for Power BI Desktop to open and refresh the report. Default = 30. |
| `‑SkipRefresh`      | Optional. Saves the report without refreshing data. Default = false.                                           |

Example:

- Refresh the Cost summary demo project and save it as a PBIX file.

  ```powershell
  ./Save-PowerBIProject ../../release/pbix/CostSummary.storage.pbip
  ```

<br>

## 📦 Package-Toolkit

[Package-Toolkit.ps1](./Package-Toolkit.ps1) packages all toolkit templates as ZIP files for release.

| Parameter   | Description                                                                                                                |
| ----------- | -------------------------------------------------------------------------------------------------------------------------- |
| `‑Template` | Optional. Name of the template or module to package. Default = \* (all).                                                   |
| `‑Build`    | Optional. Indicates whether the Build-Toolkit command should be executed first. Default = false.                           |
| `‑CopyFiles` | Optional. Indicates whether to copy templates and open data files. Default = false.                                       |
| `‑OpenPBI`  | Optional. Opens the generated Power BI projects to be saved as PBIX files. Same as `Package-PowerBI -Open`. Default = false. |
| `‑ZipPBI`   | Optional. Validates the saved PBIX files and packages PowerBI-demo.zip. Same as `Package-PowerBI`. Default = false.        |
| `‑Preview`  | Optional. Indicates that the template(s) should be saved as a preview only. Does not package other files. Default = false. |

Examples:

- Generate ZIP files for each template using an existing build.

  ```powershell
  ./Package-Toolkit
  ```

- Builds the latest code and generates ZIP files for each template.

  ```powershell
  ./Package-Toolkit -Build

  ```

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
