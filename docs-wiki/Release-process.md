<!-- markdownlint-disable MD041 -->

The following outlines the release process after all work is completed and merging a feature brach to `dev` for the next release or when merging `dev` to `main` for a public release.

On this page:

- [🌿 Promoting a feature branch](#-promoting-a-feature-branch)
- [🚀 Publishing an official release](#-publishing-an-official-release)
- [📜 Changelog guidance](#-changelog-guidance)

---

## 🌿 Promoting a feature branch

When a feature branch is code-complete, it can be merged into `dev`. Before proceeding, ensure the following requirements have been met:

1. All tests pass.
   > _The PR will be blocked if they don't._
2. Any new features are code complete and not missing any functionality required for release.
   > _Once in `dev`, the feature is considered part of the next release and can be pushed out at any time. Any broken features will be reverted._
3. All new or updated functionality must be documented in the [changelog](https://github.com/microsoft/finops-toolkit/blob/dev/docs/changelog.md).
   > _See [Changelog guidance](#-changelog-guidance) for details about changelog requirements._
4. All new or updated functionality must be documented in the [documentation](https://github.com/microsoft/finops-toolkit/blob/dev/docs).
5. Update the [list of available tools](https://github.com/microsoft/finops-toolkit/tree/dev/docs#-available-tools) on the documentation home page.

Once the above requirements have been met, the feature branch can be merged into `dev` using the following steps:

1. From a command prompt, run `cd <root>/src/scripts; ./Merge-DevBranch features/<name>` to sync the branch with `dev`.
2. Commit the changes and push to the feature branch.
3. Create a PR to merge the feature branch into `dev`.
4. Follow the normal PR process to merge the PR.

<br>

## 🚀 Publishing an official release

1. Review the [changelog](../docs/_resources/changelog.md) to ensure it encapsulates all changes.
   - Move all released changes to an official numbered version section.
   - If there are committed changes in a feature branch that you want to mention, add them to an "Unreleased" section.
2. Update the version.

   ```powershell
   <root>/src/scripts/Update-Version [-Major|Minor|Patch]
   ```

3. Build all toolkit templates and resolve any issues.

   > _This step is optional, but can catch issues earlier. You can also add the `-Build` parameter to the publish command in the next step._

   ```powershell
   <root>/src/scripts/Build-Toolkit
   ```

4. Publish each template to the target repo.

   > _Bicep modules are published to the Bicep Registry, PowerShell in the PowerShell Gallery, and everything else in the Azure Quickstart Templates. Note that PowerShell is published separately and not included here._

   1. Update your fork and local clone of the target repo (for example, Bicep Registry or Azure Quickstart Templates).
      > _Make sure you're in the main/master branch of the target repo when publishing a new template. If in another folder, the script will assume you're updating that branch and not create a new one._
   2. Copy template files to the target repo and start a PR:

      ```powershell
      cd <root>/src/scripts
      ./Publish-Toolkit "finops-hub|governance-workbook|optimization-workbook" -Commit
      ```

   3. Open the PR URL from the console and complete the PR template requirements.
      > _If a name hasn't been set, use `New FinOps toolkit template – <template-name>`._
   4. Review the code that's changed in the PR, verify that the changelog covers everything, and update as needed.
   5. If you need to change anything, re-run the publish command without committing:

      ```powershell
      cd <root>/src/scripts
      ./Publish-Toolkit "finops-hub|governance-workbook|optimization-workbook" -Build
      ```

   6. Switch to the target repo folder and verify your changes were applied correctly.
   7. Commit and push your changes.
   8. Return to the PR URL and publish the PR.
   9. Check back after 1 hour to see if there any failed checks.
      1. If there are errors, click the Details link to understand what needs to be fixed.
      2. Fix any issues in the FinOps toolkit codebase (not in the target repo).
      3. Repeat steps 5-9 until all issues have been resolved.
   10. Check back after 2-3 days to see if your PR is completed.
       > _Bicep Registry and Azure Quickstart Template repos are manually reviewed and closed 2-3x per week. If you don't see an update, contact the ARM team._

5. Finalize the release.

   1. Update the [milestone](https://github.com/microsoft/finops-toolkit/milestones).

      1. Review all issues in the milestone, move anything that needs to be pushed, and close any completed items.
      2. Close the milestone when all issues have been closed or moved.

   2. Ensure all tests pass:

      ```powershell
      <root>/src/scripts/Test-PowerShell
      ```

   3. Check the docs for broken links:
      1. Create a personal fork of the main repo.
      2. If you already have one, update it to the latest.
      3. Enable GitHub pages in your fork to use the `dev` branch `docs` folder.
      4. Verify the `pages build and deployment` action completes successfully.
      5. Open a dead link checker (for example, [deadlinkchecker.com](https://www.deadlinkchecker.com/website-dead-link-checker.asp)) and check `https://{your-username}.github.io/finops-toolkit`.
         - Ignore **link/href** errors for new pages that have not been released in the official `main` branch.
         - Ignore any **Download** errors for the new release or any new files that haven't been released in the official `main` branch.
         - Ignore the **Full changelog** error for the new release, which hasn't been released in the official `main` branch.
         - Ignore the 403 error for learn.finops.org.
         - Ignore any 429 errors from GitHub. These are caused due to all the contributor links that are checked.
      6. Fix any broken links, push changes, and rerun the tool.

   4. Merge to main:

      ```powershell
      cd <root>/src/scripts
      ./Merge-DevBranch main
      ```

   5. Verify [documentation](https://aka.ms/finops/toolkit) updated correctly.

      > _The documentation site may take 5 minutes to update after the merge is committed. If not updated, look at [GitHub actions](https://github.com/microsoft/finops-toolkit/actions/workflows/pages/pages-build-deployment) to see if there are any failures._

   6. Run `Package-Toolkit -Build -PowerBI` script.
      - For each Power BI report:
        1. Save the file as a PBIX file to the release folder.
        2. Change the sensitivity to **Public**. If the option is disabled, close the file and reopen it.
           > ⚠️ _Power BI does not remember the sensitivity setting for Power BI projects so this needs to be done for each release. If not done, the report will not open for anyone outside of Microsoft._
        3. Update the version on the **Get started** tab.
        4. For the Cost summary and Data ingestion reports, remove the following from the Transform data (query editor):
           1. Delete both **Recommendations\*** queries.
           2. Delete the **InstanceSizeFlexibility** query.
           3. Open the **▶️ START HERE** query in the advanced editor and remove connector settings and generated rows in the table from the separator line to the end.
        5. For the Cost summary and Rate optimization reports, remove the following from the Transform data (query editor):
           1. Delete all **Hub\*** queries.
        6. Save PBIX again in the release folder.
           > ⚠️ _**DO NOT** save the above changes back to the Power BI project files!_
        7. Copy the first paragraph from the **Get started** page and export a template (PBIT file) in the release folder. Use the copied text for the description and add "Learn more at https://aka.ms/ftk/{report-name}" as a separate paragraph in the description.
   7. Tag and publish a [new release](https://github.com/microsoft/finops-toolkit/releases/new):
      1. Create a tag on publish using the "vX.X" format.
      2. Set the **Target** to `main`.
      3. Set the **Previous tag** to the previous release tag.
      4. Set the name to `Toolkit vX.X`.
      5. Copy the body from the previous release to use as a template.
      6. Change the "New in" header to use the new version number.
      7. Summarize changes from the changelog in the **New in** and **Updated** sections.
         - Simplify to only include one line per tool.
         - Each tool should be linked to its doc page.
         - Don't link features to their respective pages (for example, PowerShell commands).
         - Don't list every small change. Use "various bug fixes and improvements" to keep it simple.
      8. If the Azure Quickstart Templates repo is not updated, add a note. Otherwise, comment the note out for use in the next release.
         > 💡 _Don't forget to comment this out after the AQT repo is updated!_
      9. Update the list of direct and indirect contributors.
         - Use the "Generate release notes" feature to get a list of all code contributors.
         - Carefully review the list to ensure everyone is covered since feature branch PRs get merged, which can hide contributors.
         - If they made a code change, add them to the contributor list.
         - If they filed an issue, reviewed a PR, or participated in on- or offline discussions, add them to the list of supporters.
      10. Update the discussion and changelog links in the footer. Comment out the AQT link if not ready.
      11. Upload all files from the release folder:
          - ZIP files for templates like hubs and workbooks.
          - Power BI PBIX and PBIT files.
          - Open data CSV and JSON files.
          - ZIP file for sample data files.
          - **DO NOT** copy Bicep, PowerShell, PBIP, or image files.
   8. Update the related discussion.
   9. Update all issues to `Status: Released`.
   10. Update the `Toolkit / Should return all known releases` PowerShell integration test based on the latest version.

       > _See `src/powershell/Tests/Integration/Toolkit.Tests.ps1` > `Get-FinOpsToolkitVersion` > `Should return all known releases`_

       1. Add the latest public version to the `$expected` variable.
       2. Update the file checks to include/exclude any new/removed files.

<br>

## 📜 Changelog guidance

Our changelog is written for our customers, not developers. It should be easy to read and understand and should not include any technical details. It should be written in a way that a customer can read it and understand what's new in the release without requiring any additional context or internal details about how solutions were designed or built.

We follow a simplified version of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Specifically:

- Every major, customer-impacting change should be called out in the changelog.
- Unreleased features are in an "Unreleased" section, which is at the top of the changelog.
  - This is typically only available in `dev` and is generally not released to the public documentation.
  - Before we release, we rename "Unreleased" to the desired version number.
- Each version should be in its own section, formatted as `vX.X` (for example, `v0.1`) and prepended with an emoji to indicate the type of release:
  - 🚀 for major releases (for example, 2.0).
  - 🚚 for minor releases (for example, 1.1).
  - 🛠️ for patch releases (for example, 1.0.1).
  - 🪛 for update releases (for example, 1.0.0-preview.2).
- Group changes by tool and type of change.
  - Each tool has its own section with its corresponding emoji and bolded text (for example, `🏦 **FinOps hubs**`).
  - Types of changes are in a numbered list with their emoji and text in the following order:
    - `➕ Added` for new features.
    - `✏️ Changed` for changes in existing functionality.
    - `✖️ Deprecated` for soon-to-be removed features.
    - `🗑️ Removed` for now removed features.
    - `🛠️ Fixed` for any bug fixes.
    - `🔒 Security` in case of vulnerabilities.
  - Under each type of change, add a numbered list of all changes of that type to that tool.
    - Keep updates short and to the point. Limit to one line.
    - Link to the documentation, when applicable.
    - Link to issues, when available.
- Below the all tool changes, add a link to the release downloads.

<br>
