---
title: MCA subscription creation (billing scope)
parent: Subscription operations
nav_order: 1
---

# Microsoft Customer Agreement subscription creation (billing scope)

Use this guide when you're automating Microsoft Customer Agreement (MCA) subscription creation and need reminders about which billing identifiers and scopes feed the subscription alias APIs. In MCA, the control surface for creating a subscription lives at the billing account, billing profile, and invoice section scopes—not at the subscription scope itself. [Source](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest)

## Scope boundaries

- Billing scopes: Billing account, billing profile, and invoice section determine where charges roll up and which identities can create subscriptions. [Source](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement) [Source](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest)
- Subscription scope: The `Microsoft.Subscription/aliases` request returns a subscription ID, after which subscription-scoped automation applies landing zone policies, networking, and budgets. [Source](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest)

## Roles and prerequisites

- [Billing account, billing profile, invoice section, and Azure subscription creator roles](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest) can programmatically mint MCA subscriptions; the same roles can be delegated to service principals for automation.
- Automation should capture [billing account, billing profile, and invoice section identifiers](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest) before provisioning so the subscription alias points to the correct billing scope.

## Standard provisioning flow

1. [Enumerate accessible billing accounts](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest) via `Microsoft.Billing/billingAccounts` and confirm the `agreementType` is `MicrosoftCustomerAgreement`.
2. [Retrieve billing profiles and invoice sections](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest) within the target account to determine the billing scope path used during alias creation.
3. [Submit a `Microsoft.Subscription/aliases` request](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest) with the destination tenant, owner object ID, workload classification, and billing scope. Azure returns the subscription ID after the alias is ready.

## Associated billing tenant scenario

- When the destination tenant is associated to the billing account, [register an application in that tenant, grant it the required billing role, and then call the alias API directly from the destination tenant's service principal](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-customer-agreement-associated-billing-tenants).
- This [streamlined method transfers creation permissions to the destination tenant](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-customer-agreement-associated-billing-tenants), which is useful for SaaS platforms or regulated environments that still need centralized billing.

## Two-phase cross-tenant scenario

- For tighter governance, use the [dual-application pattern: register apps in both source (billing) and destination tenants, assign billing roles in the source, and have the destination app accept the subscription during alias creation](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement-across-tenants).
- The [two-phase flow lets the source tenant retain approval authority](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement-across-tenants) while allowing workloads to exist in isolated Entra tenants tied back to the same MCA billing account.
