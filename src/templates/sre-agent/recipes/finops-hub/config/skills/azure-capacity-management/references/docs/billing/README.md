---
title: Billing models
nav_order: 3
has_children: true
---

# Billing models

Use this section to navigate between Microsoft Customer Agreement (modern) and Enterprise Agreement (legacy) billing guidance:

- [`modern/`](modern/README.md)—MCA billing hierarchy, automation, and reservation scope guidance. [Source](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement)
- [`legacy/`](legacy/README.md)—Enterprise Agreement subscription creation and quota considerations. [Source](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-enterprise-agreement?tabs=rest)

Azure enterprise customers typically operate under either the historic Enterprise Agreement (EA) or the modern Microsoft Customer Agreement (MCA). Both contracts deliver the same enterprise-grade commitment, but the MCA streamlines administration and automation workflows according to [MCA billing guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement).

This repo treats EA and MCA customers identically for capacity planning guidance. EA customers can continue to use existing constructs, while MCA customers gain the same enterprise controls plus easier automation and tenant alignment. For an estate-level view that connects these billing models to subscription vending, quota operations, capacity reservations, and automation, see [capacity and billing operations](../operations/capacity-and-quotas/README.md).
