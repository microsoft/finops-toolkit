---
layout: default
parent: PowerShell
title: FOCUS
has_children: true
nav_order: 8
description: 'PowerShell commands to work with the FinOps Open Cost and Usage Specification.'
permalink: /powershell/focus
---

<span class="fs-9 d-block mb-4">FOCUS automation</span>
Work with the the FinOps Open Cost and Usage Specification (FOCUS).
{: .fs-6 .fw-300 }

[Install](../README.md#️-install-the-module){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Commands](#-commands){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [⚡ Commands](#-commands)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

<blockquote class="warning" markdown="1">
    _FOCUS commands were implemented before Microsoft Cost Management supported a native FOCUS export. Going forward, we recommend using the native export. These commands will remain available but will not be updated to support FOCUS 1.0-preview. If you have a scenario where you need a PowerShell converter, please leave feedback at [aka.ms/ftk](https://aka.ms/ftk)._
</blockquote>

The FOCUS PowerShell commands help you work with the [FinOps Open Cost and Usage Specification (FOCUS)](../../focus/README.md).

<br>

## ⚡ Commands

- [ConvertTo-FinOpsSchema](ConvertTo-FinOpsSchema.md) – Converts Cost Management cost data to the FOCUS schema.
- [Invoke-FinOpsSchemaTransform](Invoke-FinOpsSchemaTransform.md) – Loads Cost Management data from a CSV file, converts it to FOCUS schema, and saves it to a new CSV file.

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any commands or scripts you're looking for. Vote up (👍) existing ideas or create a new issue to suggest a new idea. We'll focus on ideas with the most votes.

[Vote on ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+label%3A%22Area%3A+PowerShell%22+sort%3Areactions-%2B1-desc){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Suggest an idea](https://github.com/microsoft/finops-toolkit/issues/new/choose){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" pbi="1" data="1" %}

<br>
