---
layout: default
grand_parent: PowerShell
parent: Toolkit
title: Get-FinOpsToolkitVersion
nav_order: 1
description: 'Gets available versions from published FinOps toolkit releases.'
permalink: /powershell/toolkit/Get-FinOpsToolkitVersion
---

<span class="fs-9 d-block mb-4">Get-FinOpsToolkitVersion</span>
Gets available versions from published FinOps toolkit releases.
{: .fs-6 .fw-300 }

[Syntax](#-syntax){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Examples](#-examples){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🧮 Syntax](#-syntax)
- [📥 Parameters](#-parameters)
- [🌟 Examples](#-examples)

</details>

---

The Get-FinOpsToolkitVersions command calls GitHub to retrieve all toolkit releases, then filters the list based on the specified options.

<br>

## 🧮 Syntax

```powershell
Get-FinOpsToolkitVersion `
    [-Latest] `
    [-Preview] `
    [<CommonParameters>]
```

<br>

## 📥 Parameters

| Name    | Description                                                                                |
| ------- | ------------------------------------------------------------------------------------------ |
| Latest  | Optional. Indicates that only the most recent release should be returned. Default = false. |
| Preview | Optional. Indicates that preview releases should also be included. Default = false.        |

<br>

## 🌟 Examples

### Get stable release versions

```powershell
Get-FinOpsToolkitVersion
```

Returns all stable (non-preview) release versions.

### Get latest stable release only

```powershell
Get-FinOpsToolkitVersion -Latest
```

Returns only the latest stable (non-preview) release version.

### Get all versions

```powershell
Get-FinOpsToolkitVersion -Preview
```

Returns all release versions, including preview releases.

<br>
