# 👩‍💻 Development process

The following outlines the dev process from creating to releasing features.

On this page:

- [📃 Issue lifecycle](#-issue-lifecycle)
- [📋 Triaging issues](#-triaging-issues)

---

## 📃 Issue lifecycle

1. Author creates new issue
   > Assign to PM<br>
   > ➕ `Needs: Triage 🔍`<br>
2. PM reviews issue and...
   - Asks author for details with `#needs-info` in a comment
     > Assign to author<br>
     > ➖ `Needs: Triage 🔍`<br>
     > ➕ `Needs: Information`<br>
     1. If no updates after 14d...
        > ➕ `Needs: Attention 👋`<br>
     2. If no updates after 28d...
        > Close issue<br>
        > ➕ `Resolution: No activity`<br>
     3. If updated within 35d...
        > Reopen issue<br>
        > ➖ `Needs: Information`<br>
        > ➖ `Needs: Attention 👋`<br>
        > ➖ `Resolution: No activity`<br>
        > ➕ `Needs: Triage 🔍`<br>
   - Closes issue as a duplicate with `#duplicate` in a comment
     > ➖ `Needs: Triage 🔍`<br>
     > ➕ `Resolution: Duplicate`<br>
     - If no updates after 7d...
       > Close issue<br>
3. PM asks author for details with `#needs-info` in a comment
   > Assign to author<br>
   > ➖ `Needs: Triage 🔍`<br>
   > ➕ `Needs: Information`<br>
   - If no updates after 14d...
     > ➕ `Needs: Attention 👋`<br>
   - If no updates after 28d...
     > Close issue<br>
     > ➕ `Resolution: No activity`<br>
   - If updated within 35d...
     > Reopen issue<br>
     > ➖ `Needs: Information`<br>
     > ➖ `Needs: Attention 👋`<br>
     > ➖ `Resolution: No activity`<br>
     > ➕ `Needs: Triage 🔍`<br>
4. Author adds details in comment
   > Assign to PM<br>
   > ➖ `Needs: Information`<br>
   > ➕ `Needs: Triage 🔍`<br>
5. PM approves with `#approved` in a comment
   > Remove assignee<br>
   > ➖ `Needs: Triage 🔍`<br>
6. PM assigned ➕ `Status: ✍️ Spec in progress`
7. PM creates "Spec review:" PR
   > ➖ `Status: ✍️ Spec in progress`<br>
   > ➕ `Status: 🔭 Spec review`<br>
8. "Spec review:" PR closes
   > ➖ `Status: 🔭 Spec review`<br>
   > ➕ `Status: ▶️ Ready`<br>
9. Dev assigned
   > ➖ `Status: ▶️ Ready`<br>
   > ➕ `Status: 🔄️ In progress`<br>
10. Dev creates PR
    > ➖ `Status: 🔄️ In progress`<br>
    > ➕ `Status: 🔬 Code review`<br>
11. PR closes linked issue
    > ➖ `Status: 🔬 Code review`<br>
    > ➕ `Status: 📦 Pending release`<br>
12. Issue included in a release
    > ➖ `Status: 📦 Pending release`<br>
    > ➕ `Status: ✅ Released`<br>

<br>

## 📋 Triaging issues

The goal of triaging is to ensure issues in the backlog are valid and have the necessary details for someone to start working on them. The following rules apply for triaging all issues:

- Each issue should only have one `Type: *` label. Do not assign a t ype for simple change requests.
- Add applicable `Area: *` labels by leaving `#ARM`, `#ADF`, and/or `#PBI` comments.
- Do not assign issues to anyone unless they are actively working on the issue.
- Only assign milestones when proposing work for a near-term release.
  - Use the **vNext** milestone for stretch work.
- If you do not have enough details to triage the issue, leave a `#needs-info` comment and message for the author.
- Add the `Good first issue` label if it's a good task for someone new to the project.
  - Good first issues should only contain one small change that can be contributed independently.
  - If you feel an issue needs more details for a newcomer to pick it up, add the `Needs: Information` label and assign it to a dev to provide details.
- After triaging, add an `#approved` comment and thank the author.
- Don't be afraid to say no, or close issues. Just explain why and be polite.
- Don't be afraid to be wrong. Just be flexible when new information appears.
- Explicitly @mention relevant users when you think the issue needs their attention.

<br>
