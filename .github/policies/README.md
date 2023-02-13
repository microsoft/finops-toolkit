# FabricBot policies cheat sheet

The below sections cover a cheat sheet parsed out of draft documentation and source code. For more details, see [FabricBot docs](https://eng.ms/docs/more/github-inside-microsoft/policies/fabricbot?tabs=event-actions).

On this page:

- [eventResponderTasks](#eventrespondertasks)
- [scheduledSearches](#scheduledsearches)

---

## eventResponderTasks

<!-- spell-checker:disable -->

```yaml
# `if` = Condition that must be satisfied
- if:
    # `payloadType` = Event that triggers the action
    - payloadType: 'Issue_Comment, Issues, Pull_Request, Pull_Request_Review_Comment'
    - and:
        - or:
            - not:
                # About the event
                - activitySenderHasAssociation:
                    association: 'NONE, COLLABORATOR, CONTRIBUTOR, FIRST_TIMER, FIRST_TIME_CONTRIBUTOR, MANNEQUIN, MEMBER, OWNER'
                - activitySenderHasPermission:
                    permission: 'none, read, write, admin'
                - commentContains:
                    pattern: '{text}'
                    isRegex: true # Optional
                - isAction:
                    action: '{action}'
                    # Pull_Request = Opened, Reopened, Synchronize, Closed, Labeled, Assigned
                    # Pull_Request_Review = Submitted, Dismissed
                    # Pull_Request_Review_Comment = Created, Updated
                    # Issue_Comment = Created, Deleted, Updated, Reopened, Edited
                    # Issues = Opened, Assigned, Labeled, Reopened, Closed, Edited, Deleted, Unassigned, Unlabeled, Locked, Unlocked
                    # Workflow_Run = Completed, Requested
                - isActivitySender:
                    user: 'TODO'
                    issueAuthor: true # Optional
                - labelAdded:
                    label: '{label}'
                - labelRemoved:
                    label: '{label}'

                # About issues only
                - isInProject
                    project: 'TODO'
                - issueBodyContains:
                    pattern: '{text}'
                    isRegex: true # Optional

                # About PRs only
                - filesMatchPattern:
                    pattern: '{regex}'
                    excludeFiles: 'TODO'
                - includesModifiedFile:
                    file: 'TODO'
                - includesModifiedFiles:
                    files: 'TODO'
                    excludeFiles: 'TODO'
                - pullRequestBodyContains:
                    pattern: '{text}'
                    isRegex: true # Optional
                - targetsBranch:
                    branch: '{branch}'

                # About issues or PRs
                - hasLabel:
                    label: '{label}'
                - isAssignedToSomeone
                - isAssignedToUser:
                    user: 'TODO'
                - isInMilestone:
                    milestone: 'TODO'
                - isLabeled
                - isLocked
                - isOpen
                - titleContains:
                    pattern: '{text}'
                    isRegex: true # Optional
  # `then` = Action to perform
  then:
    # Optional conditional logic to the actions
    - if:
        # See conditions above
      then:
        - addLabel:
            label: '{label}'
        - addReply:
            reply: '{text}'
        - approvePullRequest:
            comment: '{text}'
        - assignIcmUsers:
            teamId: 'TODO'
            primary: 'TODO'
            secondary: 'TODO'
        - assignTo:
            user: 'TODO'
            users: ['TODO', 'TODO']
            prAuthor: true # Optional
        - assignToGitHubUserGroup:
            groupId: '{id}'
        - cleanEmailReply
        - closeIssue
        - createPullRequest:
            head: 'TODO'
            base: 'TODO'
            title: 'TODO'
            body: 'TODO'
        - enableAutoMerge
        - inPrLabel:
            label: '{label}'
        - labelSync:
            pattern: '{regex}'
        - lockIssue
        - mentionUsers:
            mentionees: ['TODO', 'TODO']
            replyTemplate: 'TODO'
            assignMentionees: ['TODO', 'TODO']
        - removeLabel:
            label: '{label}'
        - reopenIssue
        - requestReview:
            reviewer: '{user}'
            teamReviewer: 'TODO'
        - unlockIssue
```

<!-- spell-checker:enable -->

For details on allowed regex, see the [.NET Regex class](https://learn.microsoft.com/dotnet/api/system.text.regularexpressions.regex?view=netstandard-2.1)

<br>

## scheduledSearches

<!-- spell-checker:disable -->

```yaml
- frequencies:
    - hourly:
        hour: 12 # Indicates how often to recur (e.g., every 12 hours)
    - daily:
        time: 12:00 # Indicates what time (UTC?) to perform the action
        hours: 1 # Optional
        minutes: 0 # Optional
    - weekday:
        day: 'Monday, Tuesday, ..., Sunday'
        time: 12:00 # Optional
        hours: [0, 1, 2] # Optional
        timezoneOffset: -7 # Optional
  filters:
    - assignedTo:
        user: 'TODO'
    - created:
        before: '{iso-date-time}'
        after: '{iso-date-time}'
    - haslabel:
        label: '{label}'
    - haslabelSet:
        labels: ['<label>', '<label>']
    - hasNoLabel
    - isAuthoredBy
        user: 'TODO'
    - isClosed
    - isDraftPullRequest
    - isIssue
    - isLocked
    - isNotDraftPullRequest
    - isOpen
    - isPartOfMilestone:
        milestone: 'TODO'
    - isPullRequest
    - isUnlocked
    - noActivitySince:
        days: 90
    - notAssigned
    - notInAnyMilestone
    - notLabeledWith:
        label: '{label}'
  actions:
    # Same actions as eventResponderTasks
```

<!-- spell-checker:enable -->
