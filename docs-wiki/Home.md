<!-- markdownlint-disable MD041 -->

**Welcome aboard!** 👋 If this is your first time to our repo, here are a few tips:

> 💡 **Join us!** We host a weekly contributor sync on Wednesdays at 8 AM Pacific / 4 PM UTC. [Add to calendar][contributor-sync] to stay connected with the team.

- Every folder has a README that explains its purpose.
- If you want to know how to deploy a FinOps toolkit solution, start with the [documentation](https://aka.ms/finops/toolkit).
- If you want to know how you can contribute, check out the [contribution guide](../tree/dev/CONTRIBUTING.md).
- If you want to get started with the code, start in the [wiki](../wiki). &nbsp; **← YOU ARE HERE**
- Read about our [[Architecture]] for context on technologies and structure.
- Review our [[Coding guidelines]] before you write/review code.
- Review the guidance below for how to contribute code.
- When you're ready to dig into code, you'll check the [src](../tree/dev/src) folder.

<br>

On this page:

- [🛫 Get started](#-get-started)
- [📋 Prerequisites](#-prerequisites)
- [🗃️ Fork and clone](#️-fork-and-clone)
- [🌿 Select a branch](#-select-a-branch)
- [🚀 Deploy](#-deploy)
- [🔬 Test and verify](#-test-and-verify)
- [👀 Pull requests](#-pull-requests)

---

## 🛫 Get started

There are many ways to contribute to the FinOps toolkit project, like reporting issues, suggesting features, and submitting or reviewing pull requests. For an overview, refer to the [contribution guide](../tree/dev/CONTRIBUTING.md). This page covers how to contribute to the code.

After cloning and building the repo, check out the [issues list](../issues):

- [`Help wanted ✨`](../issues) are areas we'd like explicit help on.
- [`Good first issue 🏆`](../issues) are great candidates for those getting started.

If an issue is assigned, please contact the assignee before starting to work on the issue.

<br>

## 📋 Prerequisites

- If you don't have a GitHub account, [create one](https://github.com/join)
  - Microsoft employees: Please [link your GitHub account](https://repos.opensource.microsoft.com/link) (new or existing) to your MS account and [join the Microsoft org](https://repos.opensource.microsoft.com/orgs/microsoft).
- Install [Git](https://git-scm.com/)
- Install [Visual Studio Code](https://code.visualstudio.com/)
- Install recommended extensions (you should see a prompt in the bottom-right corner)
- Install [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) or confirm you have v7.1.3 or later:

  ```powershell
  $PSVersionTable.PSVersion
  ```

- Enable running local scripts (for automation)

  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

- Install dependencies, like Azure PowerShell and Bicep

  ```powershell
  Set-Location "<finops-toolkit-root>/src/scripts"
  # Pro-tip: Add -WhatIf to see what the script does without changing anything
  ./Init-Repo
  ```

### Git setup

Set your global commit name and email address by running:

```console
git config --global user.name "Your Name"
git config --global user.email "youremail@yourdomain.com"
```

> <sup>ℹ️ _Microsoft employees: please set this to your Microsoft email_</sup>

<br>

## 🗃️ Fork and clone

Fork the repository from the web and then clone your fork locally:

```console
git clone https://github.com/<your-github-account>/finops-toolkit.git
cd finops-toolkit
```

<br>

## 🌿 Select a branch

> ℹ️ _Creating branches is only applicable for Microsoft contributors. We recommend external contributors use the same guidance within their fork but this is optional._

If working on an existing feature, switch to the feature branch:

```console
git checkout features/<feature-name>
```

If you have a single-commit change that has no dependencies and is ready to go live in the next release, create your own branch and submit a PR from there:

```console
git checkout -b <your-github-account>/<feature-name>
git branch --set-upstream-to=origin/dev
```

If creating a new feature, create a new feature branch:

```powershell
Set-Location "<finops-toolkit-root>/src/scripts"
./New-FeatureBranch "<feature-name>"
```

For more details, refer to the [[Branching strategy]].

<br>

## 🚀 Deploy

```powershell
# Sign in and optionally specify a tenant ID, if needed
Connect-AzAccount [-Tenant <tenant-id>]

# Set the default subscription (or specify subscription below)
Set-AzContext -Subscription "<subscription-id>"

# Switch to the src/scripts directory
Set-Location "<finops-toolkit-root>/src/scripts"

# Deploy the desired template. Optional parameters:
#   -ResourceGroup <name>       # Default: ftk-<alias>-<machine>
#   -Location <azure-location>  # Default: westus
#   -Template <template-name    # Default: finops-hubs
#   -WhatIf                     # Use to validate template
./Deploy-Toolkit "<template-or-module-name>"
```

<br>

## 🔬 Test and verify

Every PR is expected to include some sort of verification:

- 💪 **Unit tests** are preferred.
- 👍 **Manual verification** is acceptable but should ideally be in addition to unit tests.
- 🫰 **PS -WhatIf / az validate** should always happen but should not be the only means with which you verify your change.

<br>

## 👀 Pull requests

Please do the following before submitting a pull request:

1. Sign a [Contributor License Agreement (CLA)](Contributor-License-Agreement.md) (one-time requirement).
2. Review the [branching strategy](Branching-strategy.md) and ensure you submit PRs against the correct branch.
3. Ensure you have the latest changes from the upstream (official) repository:

   ```console
   git checkout <branch-name>
   git pull https://github.com/microsoft/finops-toolkit.git <branch-name>
   ```

   Resolve any merge conflicts, commit them, and then push them to your fork.

4. Only address 1 issue per pull request and [link the issue in the pull request](https://github.com/blog/957-introducing-issue-mentions).
5. Be sure to follow our [coding guidelines](./Coding-guidelines.md) and keep code changes as small as possible.
6. Validate changes by running locally and running [[unit tests]].
7. Enable the checkbox to [allow maintainer edits](https://docs.github.com/github/collaborating-with-issues-and-pull-requests/allowing-changes-to-a-pull-request-branch-created-from-a-fork) so the branch can be updated for a merge.
8. Do all of the above before publishing your PR. You are welcome to create a draft PR to share and discuss ideas, but only publish when all code is committed, tested, and ready for review.
9. If you are working with others (especially internal teams), have 2 of your peers review your PRs. This will ensure a quicker turnaround as it is more likely that issues will be addressed before we review the PR.
10. INTERNAL ONLY: When your PR is ready to be reviewed, add the `Needs: Review` label. We only review PRs with this label. We strive to review these PRs at least once per business day (Pacific time, excluding US holidays). We will remove the label after reviewed.
11. As you update your PR and apply changes, mark each conversation as [resolved](https://docs.github.com/github/collaborating-with-issues-and-pull-requests/commenting-on-a-pull-request#resolving-conversations). After all comments are addressed, add the **Needs: Review** label again to signify that it is ready to review.
12. If you run into any merge issues, checkout this [Git tutorial](https://github.com/skills/resolve-merge-conflicts) to help you resolve merge conflicts and other issues.

As a reminder, smaller PRs are closed quicker. If your PR has less than 20 lines of code changed, apply the **Micro PR** label (internal only). We will prioritize these to ensure they are closed quickly.

<!--For more details on how we use labels, see [[Labels]].-->

<br>

# 🙏 Thank you! <!-- markdownlint-disable-line single-h1 -->

Congratulations on your first PR! Hopefully it won't be your last!

Once your PR is merged, changes are usually deployed the following week in the Azure portal. Note that changes behind a feature flag must be manually enabled or enabled for rollout within the host portal. In general, all new features are rolled out via experimentation within the Azure portal, so they may not be available immediately.

[contributor-sync]: https://aka.ms/ftk/contrib-sync
