---
title: Initialize-FinOpsHubLocal command
description: Set up a local FinOps hub in a running Kusto emulator using the Initialize-FinOpsHubLocal command in the FinOpsToolkit module.
author: MSBrett
ms.author: brettwil
ms.date: 08/13/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps user, I want to understand how to use the Initialize-FinOpsHubLocal command in the FinOpsToolkit module.
---

# Initialize-FinOpsHubLocal command

The **Initialize-FinOpsHubLocal** command configures a local FinOps hub in a running Kusto emulator. It creates the Ingestion and Hub databases, then downloads and applies the released FinOps hub setup scripts and open data load script so the local hub uses the same KQL, transforms, and open data as a deployed hub.

This command does not install Docker or manage the emulator container. Start the emulator first, then run this command against its endpoint. It does not ingest cost data; stage and ingest your own exports after setup.

Database storage paths assume the emulator's default data root (/kustodata), matching the container setup in the "Run FinOps hubs locally" guide. If your emulator mounts data elsewhere, create the Ingestion and Hub databases manually before running this command.

<br>

## Syntax

```powershell
Initialize-FinOpsHubLocal `
    [[-ClusterUri] <string>] `
    [[-ReleaseUri] <string>] `
    [[-RawRetentionInDays] <int>] `
    [[-OpenDataPath] <string>] `
    [-SkipOpenData] `
    [[-Destination] <string>] `
    [[-TimeoutSec] <int>] `
    [-WhatIf] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name                  | Description                                                                                                                                                                                                                   |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑ClusterUri`         | Optional. Base URI of the running Kusto emulator. Default = http://localhost:8082.                                                                                                                                            |
| `‑ReleaseUri`         | Optional. Base URI to download the setup scripts and open data load script from. Default = the latest FinOps toolkit GitHub release. Point this at a local file server or a specific release to run offline or pin a version. |
| `‑RawRetentionInDays` | Optional. Number of days to keep raw data in the Ingestion database. Default = 90.                                                                                                                                            |
| `‑OpenDataPath`       | Optional. Path, as seen by the emulator, to the folder that holds the open data CSV files. Default = /data/export/open-data.                                                                                                  |
| `‑SkipOpenData`       | Optional. Skips loading the open data reference tables. Default = false.                                                                                                                                                      |
| `‑Destination`        | Optional. Local folder used to download the setup scripts. Default = temp folder.                                                                                                                                             |
| `‑TimeoutSec`         | Optional. Maximum number of seconds to wait for each emulator request or asset download. Default = 30. Use 0 to wait indefinitely (for example, on slow hardware).                                                            |
| `‑WhatIf`             | Optional. Shows what would happen if the command runs without actually running it.                                                                                                                                            |

<br>

## Examples

### Example 1

```powershell
Initialize-FinOpsHubLocal
```

Sets up a local FinOps hub in the emulator at http://localhost:8082 using the latest release.

### Example 2

```powershell
Initialize-FinOpsHubLocal -ClusterUri 'http://localhost:8082' -RawRetentionInDays 30 -SkipOpenData
```

Sets up the databases and schema with 30-day raw retention and skips loading open data.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/Hubs.InitializeHubLocal)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related solutions:

- [Run FinOps hubs locally](../../hubs/run-hubs-locally.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
