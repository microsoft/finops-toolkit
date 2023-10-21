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

1. Review the changelog to ensure it encapsulates all changes.
   - Move all released changes to an official numbered version section.
   - If there are committed changes in a feature branch that you want to mention, add them to an "Unreleased" section.
2. Update the version.

   ```powershell
   cd <root>/src/scripts
   ./Invoke-Task Version [-Major|Minor|Patch]
   ```

3. Build all toolkit templates and resolve any issues.

   > _This step is optional, but can catch issues earlier. You can also add the `-Build` parameter to the publish command in the next step._

   ```powershell
   cd <root>/src/scripts
   ./Build-Toolkit
   ```

4. Publish each template to the target repo.

   > _Bicep modules are published to the Bicep Registry, PowerShell in the PowerShell Gallery, and everything else in the Azure Quickstart Templates. Note that PowerShell is published separately and not included here._

   1. Update your fork and local clone of the target repo (e.g., Bicep Registry or Azure Quickstart Templates).
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

   2. Merge to main:

      ```powershell
      cd <root>/src/scripts
      ./Merge-DevBranch main
      ```

   3. Verify [documentation](https://aka.ms/finops/toolkit) updated correctly

      > _The documentation site may take 5 minutes to update after the merge is committed. If not updated, look at GitHub actions to see if there are any failures._

   4. Tag the release.
   5. Publish the release.
   6. Update the discussion.
   7. Update all issues to `Status: Released`.

<br>

I hope this helps you understand the different pricing models. 😊

## 📜 Changelog guidance

Our changelog is written for our customers, not developers. It should be easy to read and understand and should not include any technical details. It should be written in a way that a customer can read it and understand what's new in the release without requiring any additional context or internal details about how solutions were designed or built.

We follow a simplified version of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Specifically:

- Every major, customer-impacting change should be called out in the changelog.
- Unreleased features are in an "Unreleased" section, which is at the top of the changelog.
  - This is typically only available in `dev` and is generally not released to the public documentation.
  - Before we release, we rename "Unreleased" to the desired version number.
- Each version should be in its own section, formatted as `vX.X` (e.g., `v0.1`) and prepended with an emoji to indicate the type of release:
  - 🚀 for major releases (e.g., 2.0).
  - 🚚 for minor releases (e.g., 1.1).
  - 🛠️ for patch releases (e.g., 1.0.1).
  - 🪛 for update releases (e.g., 1.0.0-preview.2).
- Group changes by tool and type of change.
  - Each tool has its own section with its corresponding emoji and bolded text (e.g., `🏦 **FinOps hubs**`).
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
