---
title: Common terms
description: This article describes common terms and definitions used throughout the FinOps toolkit.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand common terms used in the FinOps toolkit.
---

<!-- markdownlint-disable-next-line MD025 -->
# Common terms

This article describes common terms and definitions used throughout the FinOps toolkit.

<!-- markdownlint-disable heading-increment -->

## A

#### Amortization

**Amortization** breaks reservation and savings plan purchases down and allocates costs to the resources that received the benefit. Due to this, amortized costs will not show purchase costs and will not match your invoice.

<br>

## C

#### CSP or Cloud Solution Provider

"Cloud Solution Provider" (CSP) is a program that allows third-party Microsoft partners to sell Microsoft Cloud products and services to their end customers. In this, end customers receive bills directly from their partner and not Microsoft. Within the FinOps toolkit, CSP has the same level of support as [Microsoft Customer Agreement (MCA)](#mca-or-microsoft-customer-agreement) accounts unless there is a limitation in Microsoft Cost Management or the underlying commerce platform.

See also: [Microsoft Partner Agreement](#mpa-or-microsoft-partner-agreement)

<br>

#### Commitment-based discounts

See [Commitment discounts](#commitment-discounts).

#### Commitment discounts

"Commitment discounts" refers to any discounts you can obtain by pre-committing to a specific amount of usage for a predetermined amount of time, like reservations, savings plans, or committed use discounts (CUDs).

#### Commitment savings

"Commitment savings" refers to the total amount saved compared to negotiated, on-demand rates defined on the contract. This only includes [commitment discounts](#commitment-discounts). To include negotiated discounts, use [Discount savings](#discount-savings).

<br>

## D

#### Discount savings

"Discount savings" refers to the total amount saved compared to list (retail or PAYG) rates. This includes [negotiated](#negotiated-discounts) and [commitment discounts](#commitment-discounts).

<br>

## E

#### EA or Enterprise Agreement

"Enterprise Agreement" is an agreement between Microsoft and an organization for how they can purchase, use, and pay for Azure.

<br>

## L

#### List cost

"List cost" is the cost of a product or service if it were billed at its [list price](#list-price).

#### List price

"List price" (aka "market price") is the publicly available price for a product or service. This is the price you would pay if you purchased the product or service without any discounts.

<br>

## M

#### MCA or Microsoft Customer Agreement

"Microsoft Customer Agreement" is an agreement between Microsoft and an individual or organization for how they can purchase, use, and pay for Microsoft Cloud services, like Azure, Microsoft 365, Dynamics 365, Power Platform, etc. Generally, the term "Microsoft Customer Agreement" includes [Cloud Solution Provider (CSP)](#csp-or-cloud-solution-provider) partners and customers.

See also: [Microsoft Partner Agreement](#mpa-or-microsoft-partner-agreement)

<br>

#### MOSA or Microsoft Online Services Agreement

"Microsoft Online Services Agreement" is an agreement between Microsoft and an individual or organization for how they can purchase, use and pay for Azure. MOSA subscriptions are typically obtained directly from the Azure website.

<br>

#### MPA or Microsoft Partner Agreement

"Microsoft Partner Agreement" is an agreement between Microsoft and a [Cloud Solution Provider (CSP)](#csp-or-cloud-solution-provider) partner organization that resells Microsoft Cloud services, like Azure, Microsoft 365, Dynamics 365, Power Platform, etc. Partners can also work with intermediary resellers. The individual or organization that resellers work with sign a [Microsoft Customer Agreement (MCA)](#mca-or-microsoft-customer-agreement).

<br>

## N

#### Negotiated discounts

"Negotiated discounts" are a type of rate optimization you can obtain by negotiating with cloud providers during large deals. As an example, this usually happens with Microsoft Sales as part of signing an Enterprise Agreement (EA) or [Microsoft Customer Agreement (MCA)](#mca-or-microsoft-customer-agreement).

<!-- markdownlint-restore -->

<br>

## Related content

Related resources:

- [FinOps toolkit data dictionary](./data-dictionary.md)
- [Cost Management data dictionary](https://learn.microsoft.com/azure/cost-management-billing/automate/understand-usage-details-fields)

Related FinOps capabilities:

- [Data ingestion](../../framework/understand/ingestion.md)
- [Reporting and analytics](../../framework/understand/reporting.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Policy](/azure/governance/policy/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](https://aka.ms/finops/workbooks)
- [Optimization engine](../optimization-engine/README.md)
- [FinOps toolkit open data](../open-data.md)

<br>
