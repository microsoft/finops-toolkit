---
name: "(Internal only) Release checklist"
about: List of tasks needed to ship a new FinOps toolkit release
title: "\U0001F4CB Mmmm yyyy (v#.#) release checklist"
labels: "Type: Release \U0001F680"
assignees: ''

---

Complete the following tasks to publish a monthly release.

<!--
Status icons:
🔜 Not started
🔄️ In progress
✅ Completed
-->

## 🔜 Monthly updates

- [ ] Update open data files ([learn more](https://github.com/microsoft/finops-toolkit/tree/dev/src/open-data)).
  - [ ] Update pricing units:
    - [ ] Run the pricing units extraction query.
    - [ ] Copy the output and replace the contents of [PricingUnits.csv](https://github.com/microsoft/finops-toolkit/tree/dev/src/open-data/PricingUnits.csv).
    - [ ] Compare changes and revert any removed units. We need to keep all historical units for historical data analysis.
  - [ ] Regions
  - [ ] Services
  - [ ] Update resource types and re-gen internal PowerShell functions:
    ```powershell
    cd "<repo-root>/src/scripts"
    ./Build-OpenData -PowerShell -Test
    ```
  - [ ] Consider automating this process in [Build-OpenData](https://github.com/microsoft/finops-toolkit/tree/dev/src/scripts/Build-OpenData.ps1).
- [ ] Update Bicep CLI ([docs](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#azure-cli))
  ```console
  az bicep upgrade
  ```

---

## 🔜 Core features

- [ ] Review issues and PRs assigned to the [target milestone](https://github.com/microsoft/finops-toolkit/milestones).
  - [ ] Create a new milestone for the next monthly release.
  - [ ] Move issues that cannot be resolved in time to a new milestone.
  - [ ] Submit PRs for issues that can be resolved.
  - [ ] Complete [open PRs](https://github.com/microsoft/finops-toolkit/pulls) that are ready to be resolved.
- [ ] Confirm there are no pending changes in dev.
  ```powershell
  cd "<repo-root>"
  git checkout dev
  git status
  ```
- [ ] Update feature branches and confirm if they're ready for release.
  - [ ] Augo-merge feature branch with `dev`:
    ```powershell
    cd "<repo-root>/src/scripts"
    ./Merge-DevBranch *
    ```
  - [ ] Manually update remaining feature branches.
    ```powershell
    cd "<repo-root>/src/scripts"
    ./Merge-DevBranch features/<name>
    ```
    - [ ] TODO: Add branches
    - [ ] features/exports
    - [ ] features/governance
    - [ ] features/aoe
    - [ ] Commit the changes and push to the feature branch.
  - [ ] Build all solutions and confirm all tests pass.
  - [ ] Confirm if all features are code complete and not missing any functionality required for release.
    > _Once in `dev`, the feature is considered part of the next release and can be pushed out at any time. Any broken features will be reverted._
  - [ ] Confirm new or updated functionality is documented in the [changelog](https://github.com/microsoft/finops-toolkit/blob/dev/docs/changelog.md).
    > _See [Changelog guidance](#-changelog-guidance) for details about changelog requirements._
  - [ ] Confirm new or updated functionality must be documented in the [documentation](https://github.com/microsoft/finops-toolkit/blob/dev/docs).
  - [ ] If adding a new tool, update the [list of available tools](https://github.com/microsoft/finops-toolkit/tree/dev/docs#-available-tools) on the documentation home page.
- [ ] Merge any feature branches that are ready to `dev`.
  - [ ] Create a PR to merge the feature branch into `dev`.
  - [ ] Follow the normal PR process to merge the PR.

---

## 🔜 Finalize release

- [ ] Review the [changelog](../docs/_resources/changelog.md) to ensure it encapsulates all changes.
  - [ ] Move all released changes to an official numbered version section.
  - [ ] If there are committed changes in a feature branch that you want to mention, add them to an "Unreleased" section.
- [ ] Update the version.
  ```powershell
  <root>/src/scripts/Update-Version [-Major|Minor|Patch]
  ```
- [ ] Build all toolkit templates and resolve any issues.
  > _This step is optional, but can catch issues earlier. You can also add the `-Build` parameter to the publish command in the next step._
  ```powershell
  <root>/src/scripts/Build-Toolkit
  ```
- [ ] Ensure all tests pass:
  ```powershell
  <root>/src/scripts/Test-PowerShell
  ```
- Package all release files 
  - [ ] Run `Package-Toolkit -Build -PowerBI` script.
  - For each Power BI report:
    - [ ] Save the file as a PBIX file to the release folder.
    - [ ] Change the sensitivity to **Public**. If the option is disabled, close the file and reopen it.
      > ⚠️ _Power BI does not remember the sensitivity setting for Power BI projects so this needs to be done for each release. If not done, the report will not open for anyone outside of Microsoft._
    - [ ] For the Cost summary and Data ingestion reports, remove the following from the Transform data (query editor):
      - [ ] Delete both **Recommendations\*** queries.
      - [ ] Delete the **InstanceSizeFlexibility** query.
      - [ ] Open the **▶️ START HERE** query in the advanced editor and remove connector settings and generated rows in the table from the separator line to the end.
    - [ ] For the Cost summary and Commitment discounts reports, remove the following from the Transform data (query editor):
      - [ ] Delete all **Hub\*** queries.
    - [ ] Save PBIX again in the release folder.
      > ⚠️ _**DO NOT** save the above changes back to the Power BI project files!_
    - [ ] Copy the first paragraph from the **Get started** page and export a template (PBIT file) in the release folder. Use the copied text for the description and add "Learn more at https://aka.ms/ftk/{report-name}" as a separate paragraph in the description.
- [ ] ~Check the docs for broken links:~
  - [ ] Create a personal fork of the main repo.
  - [ ] If you already have one, update it to the latest.
  - [ ] Enable GitHub pages in your fork to use the `dev` branch `docs` folder.
  - [ ] Verify the `pages build and deployment` action completes successfully.
  - [ ] Open a dead link checker (e.g., [deadlinkchecker.com](https://www.deadlinkchecker.com/website-dead-link-checker.asp)) and check `https://{your-username}.github.io/finops-toolkit`.
    - [ ] Ignore **link/href** errors for new pages that have not been released in the official `main` branch.
    - [ ] Ignore any **Download** errors for the new release or any new files that haven't been released in the official `main` branch.
    - [ ] Ignore the **Full changelog** error for the new release, which hasn't been released in the official `main` branch.
    - [ ] Ignore the 403 error for learn.finops.org.
    - [ ] Ignore any 429 errors from GitHub. These are caused due to all the contributor links that are checked.
  - [ ] Fix any broken links, push changes, and rerun the tool.

---

## 🔜 Publish release

- [ ] Submit PRs to publish each template to the target repo.
  > _Bicep modules are published to the Bicep Registry, PowerShell in the PowerShell Gallery, and everything else in the Azure Quickstart Templates. Note that PowerShell is published separately and not included here._
  - [ ] Update your fork and local clone of the target repo (e.g., Bicep Registry or Azure Quickstart Templates).
    > _Make sure you're in the main/master branch of the target repo when publishing a new template. If in another folder, the script will assume you're updating that branch and not create a new one._
  - [ ] Copy template files to the target repo and start a PR:
    ```powershell
    cd <root>/src/scripts
    ./Publish-Toolkit "finops-hub|governance-workbook|optimization-workbook" -Commit
    ```
  - [ ] Open the PR URL from the console and complete the PR template requirements.
    > _If a name hasn't been set, use `New FinOps toolkit template – <template-name>`._
  - [ ] Review the code that's changed in the PR, verify that the changelog covers everything, and update as needed.
  - [ ] If you need to change anything, re-run the publish command without committing:
    ```powershell
    cd <root>/src/scripts
    ./Publish-Toolkit "finops-hub|governance-workbook|optimization-workbook" -Build
    ```
  - [ ] Switch to the target repo folder and verify your changes were applied correctly.
  - [ ] Commit and push your changes.
  - [ ] Return to the PR URL and publish the PR.
  - [ ] Check back after 1 hour to see if there any failed checks.
    - [ ] If there are errors, click the Details link to understand what needs to be fixed.
    - [ ] Fix any issues in the FinOps toolkit codebase (not in the target repo).
    - [ ] Repeat steps 5-9 until all issues have been resolved.
  - [ ] Check back after 2-3 days to see if your PR is completed.
    > _Bicep Registry and Azure Quickstart Template repos are manually reviewed and closed 2-3x per week. If you don't see an update, contact the ARM team._
- [ ] Merge to main:
    ```powershell
    cd <root>/src/scripts
    ./Merge-DevBranch main
    ```
- [ ] Update the [milestone](https://github.com/microsoft/finops-toolkit/milestones).
  - [ ] Review all issues in the milestone, move anything that needs to be pushed, and close any completed items.
  - [ ] Close the milestone when all issues have been closed or moved.
- [ ] Verify [documentation](https://aka.ms/finops/toolkit) updated correctly.
  > _The documentation site may take 5 minutes to update after the merge is committed. If not updated, look at [GitHub actions](https://github.com/microsoft/finops-toolkit/actions/workflows/pages/pages-build-deployment) to see if there are any failures._
- [ ] Tag and publish a [new release](https://github.com/microsoft/finops-toolkit/releases/new):
  - [ ] Create a tag on publish using the "vX.X" format.
  - [ ] Set the **Target** to `main`.
  - [ ] Set the **Previous tag** to the previous release tag.
  - [ ] Set the name to `Mmm yyyy (v#.#)`.
  - [ ] Copy the body from the previous release to use as a template.
  - [ ] Change the "New in" header to use the new version number.
  - [ ] Summarize changes from the changelog in the **New in** and **Updated** sections.
    - Simplify to only include one line per tool.
    - Each tool should be linked to its doc page.
    - Don't link features to their respective pages (e.g., PowerShell commands).
    - Don't list every small change. Use "various bug fixes and improvements" to keep it simple.
  - [ ] Update the list of direct and indirect contributors.
    - Use the "Generate release notes" feature to get a list of all code contributors.
    - Carefully review the list to ensure everyone is covered since feature branch PRs get merged, which can hide contributors.
    - If they made a code change, add them to the contributor list.
    - If they filed an issue, reviewed a PR, or participated in on- or offline discussions, add them to the list of supporters.
  - [ ] Update the discussion and changelog links in the footer. Comment out the AQT link if not ready.
  - [ ] Upload all files from the release folder:
    - ZIP files for templates like hubs and workbooks.
    - Power BI PBIX and PBIT files.
    - Open data CSV and JSON files.
    - ZIP file for sample data files.
    - **DO NOT** copy Bicep, PowerShell, PBIP, or image files.
- [ ] Update the related discussion with the same text as the release.
- [ ] Update all issues to `Status: Released`.

---

## 🔜 Post-release clean-up

- [ ] Update the `Toolkit / Should return all known releases` PowerShell integration test based on the latest version.
  > _See `src/powershell/Tests/Integration/Toolkit.Tests.ps1` > `Get-FinOpsToolkitVersion` > `Should return all known releases`_
  - [ ] Add the latest public version to the `$expected` variable.
  - [ ] Update the file checks to include/exclude any new/removed files.
- [ ] Update remaining branches that were not merged with dev
  - [ ] TODO: Add branches
  - [ ] features/mslearn
  - [ ] features/services
  - [ ] features/ux
  - [ ] features/private
  - [ ] features/savings
- [ ] Confirm the following branches are needed or should be deleted:
  - [ ] features/workbookv2
  - [ ] features/powershell
  - [ ] features/hourly

<br>
