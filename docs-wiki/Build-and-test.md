<!-- markdownlint-disable MD041 -->

This document summarizes how to build and test FinOps toolkit solutions.

On this page:

- [⚙️ Building tools](#️-building-tools)
- [🤏 Lint tests](#-lint-tests)
- [🤞 PS -WhatIf / az validate](#-ps--whatif--az-validate)
- [👍 Manually deployed + verified](#-manually-deployed--verified)
- [💪 Unit tests](#-unit-tests)
- [🙌 Integration tests](#-integration-tests)
- [PR deployment and cleanup](#pr-deployment-and-cleanup)

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

Power BI reports cannot be built automatically. Generating PBIT and PBIX files must be done manually:

1. Open the desired Power BI report.
2. Save the report as a `.pbix` file using the same name in the `releases` folder.
3. Remove unnecessary queries.
4. Remove setup instructions for unnecessary parameters.
5. Remove unnecessary parameters.
6. Save the report again.
7. Copy the first paragraph description from the main page.
8. Save the report as a `.pbit` file using the copied description and add "To learn more, see https://aka.ms/ftk/<report-name-no-spaces>".

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

## PR deployment and cleanup

### Test PR changes

`PR Deploy` runs only for PRs from branches in this repository. It runs build scripts and deploys templates with Azure credentials. It checks out the exact commit from the PR event and does not save Git credentials. Its module cache uses a new name to exclude entries from earlier fork deployments. Adding the `Needs: Deployment` label does not deploy a fork PR.

To test a fork contribution:

1. Record the full commit ID (SHA) from the fork PR.
2. Review that exact commit, including scripts, workflows, templates, dependencies, and other code.
3. Copy only the reviewed commit to a branch in this repository. Follow the repository's Git policy to preserve commit history.
4. Open a PR from that branch and select the deployment checkboxes in its description.
5. Review each new fork commit before you update the repository branch. Do not copy later fork commits automatically.

A branch in this repository can run code with Azure credentials. A maintainer must review fork code before copying it to that branch. `Initialize-CI.ps1` creates `ftk-pr` without required reviewers. Check its current settings before use. Deployment options, template path filters, Azure resource names, and automatic cleanup do not change.

### Review Copilot changes

Copilot cloud agent creates `copilot/*` branches in this repository. These branches pass the same-repository check, but the check does not establish that someone reviewed the code.

By default, GitHub waits for **Approve and run workflows** before it runs workflows after a Copilot push. Review the exact proposed commit before you select this button. If deployment checkboxes are selected, this approval can allow deployment with Azure credentials. Do not enable automatic workflow runs for Copilot as a replacement for code review.

See [Review output from Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/review-copilot-output).

### Cleanup event policy

`PR Cleanup` keeps `pull_request_target: closed`. This event starts cleanup when a PR closes, including a PR from a fork. The task needs Azure sign-in and repository write permissions to delete test resource groups and report failures. It does not check out code, run PR scripts, or use files from PR builds. Its permissions apply only to the cleanup job. Keep credentials for both `ftk-pr` and `ftk-fork` while cleanup can need them.

The October 28 reminder extends the deadline from November 2 to **December 2, 2026**. The notice states that GitHub will block this trigger in public repositories without an applicable event policy. A repository administrator must obtain temporary administrator access through JIT (just-in-time access). The administrator must then:

1. Open **Settings > Actions > Policy insights** to check which runs GitHub will block.
2. Set an event policy that allows only `.github/workflows/ftk-pr-cleanup.yml`.
3. Keep `.github/workflows/ftk-pr-deploy.yml` outside that policy. Deployment no longer uses `pull_request_target`.
4. Check the policy and required environment approvals before a cleanup test.

Do not allow this trigger for the whole repository. This code change does not change repository settings, environment protection, Azure permissions, or the event policy. Cleanup will stop at the deadline without a policy that allows it.

Before use, run the five CodeQL checks for untrusted checkout and checkout timing errors against these two workflows. Require zero findings, or obtain the security-team review allowed by the notice. Checking out an exact commit prevents the checked version from changing. It does not make unreviewed code safe.

Run the local workflow tests from the repository root:

```powershell
Invoke-Pester -Path ./src/powershell/Tests/Unit/PrWorkflowSecurity.Tests.ps1 -Output Detailed
```

These tests check deployment restrictions, all six checkboxes, template file selection, API errors, and resource deletion. Azure commands use test responses; the tests do not connect to Azure or delete resources. Bash is required. On Windows, the tests use Bash from Git for Windows. The separate Fabric URI extractor requires GNU grep and is not part of these local tests.

References: [Preventing pwn requests](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/) and [GitHub Actions: New patterns and mitigations](https://securitylab.github.com/resources/github-actions-new-patterns-and-mitigations/).

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
