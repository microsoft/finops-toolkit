---
title: Enterprise Agreement
parent: Billing models
nav_order: 2
---

# Enterprise Agreement billing model

## Contract and hierarchy

- The [Enterprise Agreement (EA)](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-ea-roles) uses a hierarchical structure—enrollment > departments > accounts > subscriptions—managed in the Azure Cost Management portal.
- [Enterprise Administrators](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-ea-roles) control enrollment-level settings, assign Department Administrators and Account Owners, and can provision new subscriptions under any [active account](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/direct-ea-administration).

## Billing administration tasks

- [EA administrators](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/direct-ea-administration) manage their enrollment directly in the Azure portal: they select the billing scope, activate the enrollment, adjust policies (for example, dev/test enablement, AO/DA view charges), and configure authentication requirements for account owners.
- [Departments](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-ea-roles) allow cost segmentation and quota/budget controls, while accounts own the subscriptions and surface usage/cost reports for their scope.

## Subscription provisioning and tenant placement

- Enterprise Administrators or Account Owners can [create EA subscriptions](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-enterprise-subscription) either for themselves or on behalf of another user, choosing the subscription directory (tenant) during creation and specifying additional subscription owners, including service principals via App IDs.
- [Cross-tenant provisioning](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-enterprise-subscription) is supported: the owner in the target tenant receives an acceptance request before the subscription is finalized.

## Automation and service principals

- EA exposes a dedicated [**SubscriptionCreator** role](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals) for service principals so automation can create subscriptions at the account scope.
- [Automating EA actions](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals) requires registering a Microsoft Entra application, capturing the service principal object ID, and assigning the desired EA role (for example, SubscriptionCreator or EnrollmentReader) via the EA REST API or PowerShell before calling subscription APIs.

## Policy and governance

- [Enrollment policies](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/direct-ea-administration#view-and-manage-enrollment-policies) let administrators control who can create subscriptions (authorization levels: Microsoft Account only, Work/School only, cross-tenant) and whether dev/test offers are available to account owners.
- [EA billing roles](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-ea-roles) must be assigned to individual identities (not groups) to ensure compliance and traceability; each user should have a monitored email for notifications so requests don't go unnoticed.

