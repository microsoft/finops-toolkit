Complete the following tasks to publish a monthly release.

<!--
Status icons:
🔜 Not started
🔄️ In progress
✅ Completed
-->

## ✅ Monthly updates

- ❌ Update open data files ([learn more](https://github.com/microsoft/finops-toolkit/tree/dev/src/open-data)).
  - ❌ Pricing units
    1. Run the extraction query.
    2. Replace the contents of the corresponding [open data](https://github.com/microsoft/finops-toolkit/tree/dev/src/open-data) files.
    3. Compare changes and revert any invalid updates.
    4. Re-gen and test PowerShell function: `<root>/src/scripts/Build-OpenData.ps1 -PowerShell -Test`
    5. Review changes and revert unrelated files or unintended changes.
    6. Document the added/updated rows in the changelog.
    7. Publish a PR for updates
  - ❌ Regions
    1. Run the extraction query.
    2. Replace the contents of the corresponding [open data](https://github.com/microsoft/finops-toolkit/tree/dev/src/open-data) files.
    3. Compare changes and revert any invalid updates.
    4. Re-gen and test PowerShell function: `<root>/src/scripts/Build-OpenData.ps1 -PowerShell -Test`
    5. Review changes and revert unrelated files or unintended changes.
    6. Document the added/updated rows in the changelog.
    7. Publish a PR for updates
  - ❌ Services
    1. Run the extraction query.
    2. Replace the contents of the corresponding [open data](https://github.com/microsoft/finops-toolkit/tree/dev/src/open-data) files.
    3. Compare changes and revert any invalid updates.
    4. Re-gen and test PowerShell function: `<root>/src/scripts/Build-OpenData.ps1 -PowerShell -Test`
    5. Review changes and revert unrelated files or unintended changes.
    6. Document the added/updated rows in the changelog.
    7. Publish a PR for updates
  - ❌ Resource types
    1. Generate ResourceTypes.json: `<root>/src/scripts/Build-OpenData.ps1 ResourceTypes -Json`
    2. Review changes and revert unrelated files or unintended changes.
       - Consider automating any of the reverted checks to streamline the process next time.
    3. Generate ResourceTypes.json: `<root>/src/scripts/Build-OpenData.ps1 ResourceTypes -Csv`
    5. Review changes and revert unrelated files or unintended changes.
    6. Document the added/updated rows in the changelog.
    7. Publish a PR for updates
  - ❌ Update FinOps hubs KQL functions: `<root>/src/scripts/Build-OpenData.ps1 -Hubs`
  - ❌ Re-gen internal PowerShell functions: `<root>/src/scripts/Build-OpenData.ps1 -PowerShell -Test`
  - ❌ Consider automating this process in [Build-OpenData](https://github.com/microsoft/finops-toolkit/tree/dev/src/scripts/Build-OpenData.ps1).
- [x] Update Bicep CLI ([docs](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#azure-cli)): `az bicep upgrade`

---

## 🔄️ Core features

- [x] Review issues and PRs assigned to the [target milestone](https://github.com/microsoft/finops-toolkit/milestones).
  - [x] Create a new milestone for the next monthly release.
  - [x] Move issues that cannot be resolved in time to a new milestone.
  - [x] Submit PRs for issues that can be resolved.
  - [x] Complete [open PRs](https://github.com/microsoft/finops-toolkit/pulls) that are ready to be resolved.
- [x] Confirm there are no pending changes in dev.
  ```powershell
  cd "<root>"
  git checkout dev
  git status
  ```
- [x] Update feature branches and confirm if they're ready for release.
  - [x] Auto-merge feature branch with `dev`: `<root>/src/scripts/Merge-DevBranch.ps1 *`
  - ❌ Manually update remaining feature branches: `<root>/src/scripts/Merge-DevBranch.ps1 features/<name>`
- [x] Build and deploy templates: `<root>/src/scripts/Build-Toolkit.ps1`.
- [x] Confirm all tests pass: `<root>/src/scripts/Test-PowerShell.ps1 -Unit -Integration`.
- [x] Confirm if all features are code complete and not missing any functionality required for release.
  > _Once in `dev`, the feature is considered part of the next release and can be pushed out at any time. Any broken features will be reverted._
- [x] Confirm new or updated functionality is documented in the [changelog](https://github.com/microsoft/finops-toolkit/blob/dev/docs/changelog.md).
  > _See [Changelog guidance](#-changelog-guidance) for details about changelog requirements._
- [x] Confirm new or updated functionality must be documented in the [documentation](https://github.com/microsoft/finops-toolkit/blob/dev/docs).
- [x] Summarize the monthly changes in the "what's new" section of the marketing pages for each tool.
- [x] Update the FinOps hubs compatibility guide and upgrade guide.
- [x] Do a global search and replace for "FTKx.x" for the previous version to replace it with the new version number.
- [x] If adding a new tool:
  - [x] Update the [marketing site landing page](https://github.com/microsoft/finops-toolkit/tree/dev/docs/README.md).
  - [x] Add a new page the [marketing site](https://github.com/microsoft/finops-toolkit/tree/dev/docs).
  - [x] Add an overview page in [MS Learn documentation](https://github.com/microsoft/finops-toolkit/tree/dev/docs-mslearn/toolkit).
  - [x] Update the [MS Learn menu to add new page(s)](https://github.com/microsoft/finops-toolkit/tree/dev/docs-mslearn/TOC.yml).
  - [x] Add the new tool's tech lead to the [Advisor council doc](https://github.com/microsoft/finops-toolkit/tree/dev/docs-wiki/Advisory-council.md).
- [x] Merge any feature branches that are ready to `dev`.
  - Create a PR to merge the feature branch into `dev`.
  - Follow the normal PR process to merge the PR.

---

## 🔜 Finalize release

- [x] Review the [changelog](../docs/_resources/changelog.md) to ensure it encapsulates all changes.
  - Move all released changes to an official numbered version section.
  - If there are committed changes in a feature branch that you want to mention, add them to an "Unreleased" section.
- [x] Update the version: `<root>/src/scripts/Update-Version [-Major|Minor|Patch]`
- [x] Build all toolkit templates and resolve any issues: `<root>/src/scripts/Build-Toolkit`
  > _This step is optional, but can catch issues earlier. You can also add the `-Build` parameter to the publish command in the next step._
- [x] Ensure all tests pass: `<root>/src/scripts/Test-PowerShell -Unit -Integration`
- [x] Package all release files 
  - [x] Run `Package-Toolkit.ps1 -Build -CopyFiles -OpenPBI` script.
  - [x] Save and close each Power BI project:
    - Select the `<root>/release/pbix` folder.
    - Change the file extension to PBIX.
    - When prompted, set the sensitivity to "Public".
    - Manually remove unused queries based on what's documented in Build-PowerBI.ps1 ~line 120.
    - Verify all pages, switch to the Get started page, and save again.
  - [x] Run `Package-Toolkit -ZipPBI` script.
- [x] Check the docs for broken links:
  - Create a personal fork of the main repo.
  - If you already have one, update it to the latest.
  - Enable GitHub pages in your fork to use the `dev` branch `docs` folder.
  - Verify the `pages build and deployment` action completes successfully.
  - Open a dead link checker (e.g., [deadlinkchecker.com](https://www.deadlinkchecker.com/website-dead-link-checker.asp)) and check `https://{your-username}.github.io/finops-toolkit`.
    - Ignore **link/href** errors for new pages that have not been released in the official `main` branch.
    - Ignore any **Download** errors for the new release or any new files that haven't been released in the official `main` branch.
    - Ignore the **Full changelog** error for the new release, which hasn't been released in the official `main` branch.
    - Ignore the 403 error for learn.finops.org.
    - Ignore any 429 errors from GitHub. These are caused due to all the contributor links that are checked.
  - Fix any broken links, push changes, and rerun the tool.

---

## 🔜 Publish release

- [ ] Publish the PowerShell module by running the [Publish PowerShell action](https://github.com/microsoft/finops-toolkit/actions/workflows/publish.yml).
- [ ] Submit PR to publish docs to the Microsoft Docs repo.
  - [ ] Confirm the source repo is on the intended release commit before publishing. Record the commit SHA and verify there are no unexpected post-release changes under `docs-mslearn`.
    ```powershell
    cd "<root>"
    git status
    git rev-parse --short HEAD
    git log --oneline <expected-release-ref>..HEAD -- docs-mslearn
    ```
    > [!IMPORTANT]
    > Do not publish from ambient `dev` unless `dev` is the intended release commit. If a release tag or `main` commit exists for the release, publish from that exact ref.
  - [ ] Update your fork and local clone (main branch) of the Microsoft Docs repo. Verify the local `main` branch is clean and aligned with both your fork and `MicrosoftDocs/partner-center-pr`.
    ```powershell
    cd "<root>/../partner-center-pr"
    git status
    git branch -vv
    git remote -v
    git rev-list --left-right --count main...origin/main
    git rev-list --left-right --count main...upstream/main
    ```
  - [ ] Preview the docs publish scope without modifying the Microsoft Docs repo. Review file names before running the publish script. Use the same copy semantics as `Publish-Toolkit.ps1` so hidden dotfiles are not included in the preview.
    ```powershell
    cd "<root>"
    $preview = Join-Path ([System.IO.Path]::GetTempPath()) "finops-docs-publish-preview"
    Remove-Item $preview -Recurse -Force -ErrorAction SilentlyContinue
    New-Item $preview -ItemType Directory | Out-Null
    Get-ChildItem docs-mslearn -Exclude .buildignore | Copy-Item -Destination $preview -Recurse
    git diff --no-index --name-status -- ../partner-center-pr/finops/finops $preview
    Remove-Item $preview -Recurse -Force
    ```
    > [!IMPORTANT]
    > `Publish-Toolkit.ps1 "docs"` without `-Commit` still replaces the target repo content in the working tree. Use `git diff --no-index` for a non-destructive preview.
  - [ ] Publish a PR:
    - Start PR: `<root>/src/scripts/Publish-Toolkit.ps1 "docs" -Commit`
    - Complete PR template requirements and set the name to `FinOps toolkit v#.# doc updates`.
    - Review the code that's changed in the PR, verify that the changelog covers everything, and update as needed. Confirm the PR does not include unexpected repo/config files, generated noise, or docs changes from a later release.
    - If you make changes, re-publish without committing: `<root>/src/scripts/Publish-Toolkit.ps1 "docs" -Build`
    - Switch to the target repo folder and verify your changes were applied correctly.
    - Commit and push your changes.
    - Return to the PR URL and publish the PR.
- [ ] Submit PRs to publish bicep modules in the Bicep Registry.
  - [ ] Update your fork and local clone of the Bicep Registry.
    > _Make sure you're in the main branch of the target repo when publishing a new template. If in another folder, the script will assume you're updating that branch and not create a new one._
  - [ ] Publish the scheduled actions bicep modules:
    - Start PR: `<root>/src/scripts/Publish-Toolkit.ps1 "scheduledactions" -Commit`
    - Complete PR template requirements and set the name to `FinOps toolkit v#.# – scheduledactions`.
    - Review the code that's changed in the PR, verify that the changelog covers everything, and update as needed.
    - If you make changes, re-publish without committing: `<root>/src/scripts/Publish-Toolkit.ps1 "scheduledactions" -Build`
    - Switch to the target repo folder and verify your changes were applied correctly.
    - Commit and push your changes.
    - Return to the PR URL and publish the PR.
- [ ] Submit PRs to publish templates to the Azure Quickstart Templates repo.
  - [ ] Update your fork and local clone of the Azure Quickstart Templates.
    > _Make sure you're in the master branch of the target repo when publishing a new template. If in another folder, the script will assume you're updating that branch and not create a new one._
  - [ ] Publish a FinOps hub PR:
    - Start PR: `<root>/src/scripts/Publish-Toolkit.ps1 "finops-hub" -Commit`
    - Complete PR template requirements and set the name to `FinOps toolkit v#.# – FinOps hub`.
    - Review the code that's changed in the PR, verify that the changelog covers everything, and update as needed.
    - If you make changes, re-publish without committing: `<root>/src/scripts/Publish-Toolkit.ps1 "finops-hub" -Build`
    - Switch to the target repo folder and verify your changes were applied correctly.
    - Commit and push your changes.
    - Return to the PR URL and publish the PR.
  - [ ] Publish a governance workbook PR:
    - Start PR: `<root>/src/scripts/Publish-Toolkit.ps1 "governance-workbook" -Commit`
    - Complete PR template requirements and set the name to `FinOps toolkit v#.# – Governance workbook`.
    - Review the code that's changed in the PR, verify that the changelog covers everything, and update as needed.
    - If you make changes, re-publish without committing: `<root>/src/scripts/Publish-Toolkit.ps1 "governance-workbook" -Build`
    - Switch to the target repo folder and verify your changes were applied correctly.
    - Commit and push your changes.
    - Return to the PR URL and publish the PR.
  - [ ] Publish a optimization workbook PR:
    - Start PR: `<root>/src/scripts/Publish-Toolkit.ps1 "optimization-workbook" -Commit`
    - Complete PR template requirements and set the name to `FinOps toolkit v#.# – Optimization workbook`.
    - Review the code that's changed in the PR, verify that the changelog covers everything, and update as needed.
    - If you make changes, re-publish without committing: `<root>/src/scripts/Publish-Toolkit.ps1 "optimization-workbook" -Build`
    - Switch to the target repo folder and verify your changes were applied correctly.
    - Commit and push your changes.
    - Return to the PR URL and publish the PR.
- [ ] Check back after 1 hour to see if there any failed checks across all PRs ([AQT](https://github.com/Azure/azure-quickstart-templates/pulls?q=is%3Apr+is%3Aopen+finops)).
  - If there are errors, click the Details link to understand what needs to be fixed.
  - Fix any issues in the FinOps toolkit codebase (not in the target repo).
  - Repeat publishing steps until all issues have been resolved.
- [ ] Check back after 2-3 days to see if all your PRs were merged ([AQT](https://github.com/Azure/azure-quickstart-templates/pulls?q=is%3Apr+is%3Aopen+finops)).
  > _Bicep Registry and Azure Quickstart Template repos are manually reviewed and closed 2-3x per week. If you don't see an update, contact the ARM team. The Docs repo is partially typically reviewed within a few hours but they may request blocking changes._
- [ ] Merge to main: `<root>/src/scripts/Merge-DevBranch.ps1 main`
- [x] Update the [milestone](https://github.com/microsoft/finops-toolkit/milestones).
  - Review all issues in the milestone, move anything that needs to be pushed, and close any completed items.
  - Close the milestone when all issues have been closed or moved.
- [x] Verify [documentation](https://aka.ms/finops/toolkit) updated correctly.
  > _The documentation site may take 5 minutes to update after the merge is committed. If not updated, look at [GitHub actions](https://github.com/microsoft/finops-toolkit/actions/workflows/pages/pages-build-deployment) to see if there are any failures._
- [x] Tag and publish a [new release](https://github.com/microsoft/finops-toolkit/releases/new):
  - [ ] Create a tag on publish using the "vX.X" format.
  - [ ] Set the **Target** to `main`.
  - [ ] Set the **Previous tag** to the previous release tag.
  - [ ] Set the name to `Mmm yyyy (v#.#)`.
  - [ ] Copy the body from the [previous release](https://github.com/microsoft/finops-toolkit/releases) to use as a template.
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

## 🔜 Announcements

- [x] Publish release announcement on the [FinOps blog](https://aka.ms/finops/blog)
- [ ] Share on LinkedIn
- [ ] Share on Twitter/X
- [ ] Share on Azure Updates (TBD)
- [ ] Share on Engage (Azure Connection Program)
- [ ] Share on F2 Slack

---

## 🔜 Post-release clean-up

- [x] Update the `Toolkit / Should return all known releases` PowerShell integration test based on the latest version.
  > _See `src/powershell/Tests/Integration/Toolkit.Tests.ps1` > `Get-FinOpsToolkitVersion` > `Should return all known releases`_
  - Add the latest public version to the `$expected` variable.
  - Update the file checks to include/exclude any new/removed files.
- [x] Update the minor version and add the "dev" label: `<root>/src/scripts/Update-Version.ps1 -Minor -Label dev`
- [x] Create a placeholder in the changelog for the new release.
  ```markdown
  ## vX.Y

  _Released Mmm yyyy_

  > [!div class="nextstepaction"]
  > [Download](https://github.com/microsoft/finops-toolkit/releases/tag/vX.Y)
  > [!div class="nextstepaction"]
  > [Full changelog](https://github.com/microsoft/finops-toolkit/compare/vX.Y...vX.Y)

  <br>
  ```
- [ ] Update remaining branches that were not merged with dev
  - [ ] TODO: Add branches
  - [ ] features/anomaly
  - [ ] features/finley
  - [ ] features/recs
  - [ ] features/ux
  - [ ] features/xcloud
- [ ] Copy any additional code from the following branches and delete them:
  - [ ] features/hack24
  - [ ] features/hourly
- [ ] Delete the following branches:
  - [ ] features/alerts

<br>
