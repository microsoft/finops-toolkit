<!-- markdownlint-disable MD041 -->

This document summarizes how to build and test FinOps toolkit solutions.

On this page:

- [⚙️ Building tools](#️-building-tools)
- [🤏 Lint tests](#-lint-tests)
- [🤞 PS -WhatIf / az validate](#-ps--whatif--az-validate)
- [👍 Manually deployed + verified](#-manually-deployed--verified)
- [💪 Unit tests](#-unit-tests)
- [🙌 Integration tests](#-integration-tests)

---

Automated tests in the FinOps toolkit use Pester, a PowerShell-based testing and mocking framework.

<br>

## ⚙️ Building tools

FinOps toolkit solutions are built using PowerShell. Each type of tool has its own nuances and actions that are performed as part of the build process. Refer to the following sections for details.

### Building templates

Templates (only FinOps hub as of May 2024) leverage a straightforward bicep build process. We generally publish all templates to the Azure Quickstart Templates repository which comes with a few additional requirements, so we do have a set of unique files to facilitate these requirements.

To build a single template, run:

```powershell
cd "<repo-root>"
src/scripts/Build-Toolkit "<template-name>"
```

To build all templates and modules, simply remove the template name or run `npm run build`, if you have NPM setup. To learn more about the build script, see [Build-Toolkit](../tree/dev/src/scripts/README.md#-build-toolkit).

To build and deploy templates, run:

```powershell
cd "<repo-root>"
src/scripts/Deploy-Toolkit "<template-name>" -Build
```

For more local deployment options, see [Deploy-Toolkit](../tree/dev/src/scripts/README.md#-deploy-toolkit).

To learn more, see [FinOps toolkit templates](../tree/dev/src/templates/README.md).

### Building workbooks

Workbooks include a standard deployment template that is generated as part of the build script. The build script also joins multiple workbooks into a single file for deployment to support hosted workbooks in the Azure Workbooks repository as well as self-managed workbooks in the toolkit.

Building and deploying workbooks uses the same PowerShell commands as templates. To build, run:

```powershell
cd "<repo-root>"
src/scripts/Build-Toolkit "<workbook-name>-workbook"
```

To build and deploy, run:

```powershell
cd "<repo-root>"
src/scripts/Deploy-Toolkit "<workbook-name>-workbook" -Build
```

The Build-Toolkit script calls an internal Build-Workbook script, which does all the work. You can also call this directly; however, we recommend running the Build-Toolkit script for a complete build process.

To learn more, see [Workbook modules](../tree/dev/src/workbooks/README.md).

### Building Bicep Registry modules

Bicep Registry modules support a custom "language" that enables reusing code across target scopes. Bicep Registry modules designed to support multiple scopes will generate multiple output folders for each module.

To build all bicep modules, run:

```powershell
cd "<repo-root>"
src/scripts/Build-Toolkit
```

To build only a single module, run:

```powershell
cd "<repo-root>"
src/scripts/Build-Bicep ..\bicep-registry\<module>
```

Bicep Registry modules include a `main.test.bicep` file that includes all tests. To test Bicep Registry modules, run:

```powershell
cd "<repo-root>"
src/scripts/Deploy-Toolkit "<module-name>" -Build -Test
```

To learn more, see [Bicep Registry modules](../tree/dev/src/bicep-registry/README.md).

### Building open data files

The build script for open data files generates the resource types file from Azure portal metadata and then generates PowerShell commands and tests for each file.

To build open data, run:

```powershell
src/Build-OpenData
```

To learn more about open data, see [Open data](../tree/dev/src/open-data/README.md).

### Building PowerShell

The PowerShell module generates a single module file from functions created in separate files.

To build the PowerShell module, run the following as an administrator:

```powershell
cd "<repo-root>"
src/scripts/Build-PowerShell
```

To install the PowerShell module locally, run:

```powershell
cd "<repo-root>"
Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName src/powershell/FinOpsToolkit.psm1
```

The Build-PowerShell script calls an Invoke-Build task internally.

> [!NOTE]
> We have a partial implementation of Invoke-Build but this has not been fully  implemented, so there is a mix of custom scripts and Invoke-Build scripts. If anyone has experience in this area, we would love to get help centralizing on a single build system.

### Building Power BI reports

Run [Build-PowerBI](../src/scripts/README.md#-build-powerbi) to generate the Power BI release artifacts:

```powershell
cd <root>/src/scripts
./Build-PowerBI
```

This generates two things from a single prune, so the template and the demo report can't drift:

- PBIT templates in `release/pbit`, zipped into `PowerBI-kql.zip` and `PowerBI-storage.zip`.
- PBIP projects in `release/pbix`, each containing only the tables, relationships, and queries that report needs.

Power BI Desktop has to load and save the demo PBIX files, so that step is still manual. Use [Package-PowerBI](../src/scripts/README.md#-package-powerbi), which reports what's left to do and validates the saved files.

### Building documentation

Documentation does not currently require a build process. Documentation is automatically generated via GitHub Pages. To test documentation generation:

1. Fork the FinOps toolkit repository.
2. From your forked repo, go to **Settings** > **Pages** (in the left nav).
3. Under Build and deployment, set the following:
   - Source = Deploy from branch
   - Branch = features/services
   - Folder = /docs
4. Wait 5m for everything to build (or go to Actions to track the deployment proactively).
5. Go to (your-username).github.io/finops-toolkit in the browser to view the docs.

<br>

## 🤏 Lint tests

Linters are static code analysis tools that identify programming and stylistic errors or anti-patterns in source code. The FinOps toolkit uses the following linters:

- [Bicep linter](https://learn.microsoft.com/azure/azure-resource-manager/bicep/linter)
- [PowerShell Script Analyzer](https://aka.ms/psscriptanalyzer)

Lint tests are run on bicep code during the build process. Simply build the target solution and resolve any lint errors written to the console.

To run PowerShell lint tests, run:

```powershell
cd "<repo-root>"
src/scripts/Test-PowerShell -Lint
```

<br>

## 🤞 PS -WhatIf / az validate

Running `-WhatIf` or `validate` is generally not a great way to confirm tools are working as desired. We do not recommend relying on this for any substantial changes.

To run `-WhatIf` for a deployment, run:

```powershell
cd "<repo-root>"
src/scripts/Deploy-Toolkit "<tool-name>" -Build -WhatIf
```

<br>

## 👍 Manually deployed + verified

Manual verification is always expected; however, we do prefer automated tests. Unit test are preferred with integration tests next. Refer to the details above for how to build and deploy each type of tool.

<br>

## 💪 Unit tests

Unit tests validate compartmentalized functionality without calling code outside the "unit" being tested. Mocking is used to avoid calling code outside the target code block.

To run PowerShell unit tests, run:

```powershell
cd "<repo-root>"
src/scripts/Test-PowerShell
```

The Test-PowerShell script runs unit tests by default. To opt in to multiple types of tests, include `-Unit` for the unit tests.

<br>

## 🙌 Integration tests

Integration tests validate a full stack of functionality, including all dependencies. Integration tests are typically simpler to implement but require cleanup.

To run PowerShell integration tests, run:

```powershell
cd "<repo-root>"
src/scripts/Test-PowerShell -Integration
```

<br>
