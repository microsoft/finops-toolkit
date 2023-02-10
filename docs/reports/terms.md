# FinOps hubs terms

This page covers a number of common terms used throughout FinOps hubs. For details about the usage column terms used, see [Terms in the Azure usage and charges file](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-understand-your-usage).

On this page:

- [A](#a)
- [C](#c)
- [D](#d)
- [E](#e)
- [M](#m)
- [N](#n)
- [Data dictionary](#data-dictionary)

---

<!-- markdownlint-disable header-increment -->

## A

#### Amortization

**Amortization** breaks reservation and savings plan purchases down and allocates costs to the resources that received the benefit. Due to this, amortized costs will not show purchase costs and will not match your invoice.

<br>

## C

#### Commitment-based discounts

"Commitment-based discounts" refers to any discounts you can obtain by pre-committing to a specific amount of usage for a predetermined amount of time, like reservations, savings plans, or committed use discounts (CUDs).

#### Commitment savings

"Commitment savings" refers to the total amount saved compared to negotiated, on-demand rates. This only includes [commitment-based discounts](#commitment-based-discounts). To include negotiated discounts, use [Discount savings](#discount-savings).

<br>

## D

#### Discount savings

"Discount savings" refers to the total amount saved compared to retail (PAYG) rates. This includes [negotiated](#negotiated-discounts) and [commitment-based discounts](#commitment-based-discounts).

<br>

## E

#### EA or Enterprise Agreement

"Enterprise Agreement" is an agreement between Microsoft and an organization for how they can purchase, use, and pay for Azure.

<br>

## M

#### MCA or Microsoft Customer Agreement

"Microsoft Customer Agreement" is an agreement between Microsoft and an individual or organization for how they can purchase, use, and pay for Microsoft Cloud services, like Azure, Microsoft 365, Dynamics 365, Power Platform, etc.

<br>

#### MOSA or Microsoft Online Services Agreement

"Microsoft Online Services Agreement" is an agreement between Microsoft and an individual or organization for how they can purchase, use and pay for Azure.

<br>

#### MPA or Microsoft Partner Agreement

"Microsoft Partner Agreement" is an agreement between Microsoft and an organization that resells Microsoft Cloud services, like Azure, Microsoft 365, Dynamics 365, Power Platform, etc. Partners can also work with intermediary resellers. The individual or organization that resellers work with sign a Microsoft Customer Agreement (MCA).

<br>

## N

#### Negotiated discounts

"Negotiated discounts" are a type of rate optimization you can obtain by negotiating with cloud providers during large deals. As an example, this usually happens with Microsoft Sales as part of signing an Enterprise Agreement (EA) or Microsoft Customer Agreement (MCA).

<br>

<!-- markdownlint-restore -->

---

## Data dictionary

The following table describes the columns available within the exported data:

| Name                   | Type    | Description                                                                                                                                                                                                                                                            |
| ---------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AccountName            | String  | Name of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                                                                                             |
| AccountOwnerId         | String  | Email address of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                                                                                    |
| AdditionalInfo         | Object  | Additional information about a service charge. Differs by service. Formatted as a JavaScript object (JSON).                                                                                                                                                            |
| AHB Status             | String  | Derived. Indicates whether the charge used or was eligible for Azure Hybrid Benefit. Extracted from AdditionalInfo.                                                                                                                                                    |
| AHB vCPUs              | Number  | Derived. Indicates the number of virtual CPUs required from on-prem licenses required to use Azure Hybrid Benefit for this resource. Extracted from AdditionalInfo.                                                                                                    |
| AvailabilityZone       | String  | Area within a resource location used for high availability. Not available for all services. Not supported for Microsoft Cloud.                                                                                                                                         |
| benefitId              | String  | Unique identifier (GUID) of the commitment-based discount (e.g., reservation, savings plan) this resource utilized.                                                                                                                                                    |
| benefitName            | String  | Name of the commitment-based discount (e.g., reservation, savings plan) this resource utilized.                                                                                                                                                                        |
| BillingAccountId       | String  | Unique identifier for the billing account.                                                                                                                                                                                                                             |
| BillingAccountName     | String  | Name of the billing account.                                                                                                                                                                                                                                           |
| BillingCurrency        | String  | See BillingCurrencyCode.                                                                                                                                                                                                                                               |
| BillingCurrencyCode    | String  | Currency code for the Cost column.                                                                                                                                                                                                                                     |
| BillingPeriodEndDate   | Date    | Last day of the invoice period. Usually the last day of the month.                                                                                                                                                                                                     |
| BillingPeriodStartDate | Date    | First day of the invoice period. Usually the first of the month.                                                                                                                                                                                                       |
| BillingProfileId       | String  | Unique identifier of the scope that invoices are generated for. EA billing account or MCA billing profile.                                                                                                                                                             |
| BillingProfileName     | String  | Name of the scope that invoices invoices are generated for. EA billing account or MCA billing profile.                                                                                                                                                                 |
| ChargeType             | String  | Represents the type of charge. Allowed values: Usage, Purchase, UnusedReservation, UnusedSavingsPlan, Taxes, Refund.                                                                                                                                                   |
| ConsumedService        | String  | Azure Resource Manager resource provider namespace.                                                                                                                                                                                                                    |
| Cost                   | Number  | See CostInBillingCurrency.                                                                                                                                                                                                                                             |
| CostAllocationRuleName | String  | Name of the Microsoft Cost Management cost allocation rule that generated this charge. Cost allocation is used to move or split shared charges.                                                                                                                        |
| CostInBillingCurrency  | Number  | Amount owed for the charge after any applied discounts. FinOps toolkit uses amortized cost, so this amount may not match your invoice.                                                                                                                                 |
| CostCenter             | String  | Custom value defined by a billing admin for internal chargeback.                                                                                                                                                                                                       |
| CPUs                   | Number  | Derived. Indicates the number of CPUs used by this resource. Extracted from AdditionalInfo. Used for Azure Hybrid Benefit reports.                                                                                                                                     |
| Date                   | Date    | Day of the charge.                                                                                                                                                                                                                                                     |
| EffectivePrice         | Number  | Amortized price per unit after commitment-based discounts.                                                                                                                                                                                                             |
| Frequency              | String  | Indicates how often the charge repeats. Allowed values: UsageBased, Recurring.                                                                                                                                                                                         |
| ImageType              | String  | Derived. Extracted from AdditionalInfo. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| InstanceName           | String  | Derived. Extracted from AdditionalInfo. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| InvoiceSection         | String  | See InvoiceSectionName.                                                                                                                                                                                                                                                |
| InvoiceSectionId       | String  | Unique identifier (GUID) of a section within an invoice used for grouping related charges. Represents an EA department. Not applicable for MOSA.                                                                                                                       |
| InvoiceSectionName     | String  | Name of a section within an invoice used for grouping related charges. Represents an EA department. Not applicable for MOSA.                                                                                                                                           |
| IsCreditEligible       | Boolean | Indicates if this charge can be deducted from credits. May be a string (`True` or `False` in legacy datasets).                                                                                                                                                         |
| MeterCategory          | String  | Represents a cloud service, like "Virtual machines" or "Storage".                                                                                                                                                                                                      |
| MeterId                | String  | Unique identifier (sometimes a GUID, but not always) for the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price.                                                                                                             |
| MeterName              | String  | Name of the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price. Not applicable for purchases.                                                                                                                                |
| MeterRegion            | String  | Geographical area associated with the price. If empty, the price for this charge is not based on region. Note this is different from ResourceLocation.                                                                                                                 |
| MeterSubCategory       | String  | Groups service charges of a particular type. Sometimes used to represent a set of SKUs (e.g., VM series) or a different type of charge (e.g., table vs. file storage). Can be empty.                                                                                   |
| OfferId                | String  | Microsoft Cloud subscription type.                                                                                                                                                                                                                                     |
| PartNumber             | String  | Identifier to help break down specific usage meters.                                                                                                                                                                                                                   |
| PayGPrice              | Number  | Retail or list price per unit without any discounts.                                                                                                                                                                                                                   |
| PlanName               | String  | Represents the pricing plan or SKU.                                                                                                                                                                                                                                    |
| PricingModel           | String  | Indicates how the charge was priced. Allowed values: OnDemand, Reservation, SavingsPlan.                                                                                                                                                                               |
| Product                | String  | See ProductName.                                                                                                                                                                                                                                                       |
| ProductName            | String  | Product that was used or purchased.                                                                                                                                                                                                                                    |
| ProductOrderId         | String  |
| ProductOrderName       | String  |
| PublisherName          | String  | Name of the organization that created the cloud service.                                                                                                                                                                                                               |
| PublisherType          | String  | Indicates whether a charge is from a cloud provider or third-party Marketplace vendor. Allowed values: Azure, AWS, Marketplace.                                                                                                                                        |
| Quantity               | Number  | Amount of a particular service that was used or purchased. The type of quantiy is defined by the UnitOfMeasure.                                                                                                                                                        |
| ReservationId          | String  | Unique identifier (GUID) of the reservation this resource utilized.                                                                                                                                                                                                    |
| ReservationName        | String  | Name of the reservation this resource utilized.                                                                                                                                                                                                                        |
| ResourceGroup          | String  | Grouping of resources that make up an application or set of resources that share the same lifecycle (e.g., created and deleted together).                                                                                                                              |
| ResourceId             | String  | Unique identifier for the resource. May be empty for purchases.                                                                                                                                                                                                        |
| ResourceName           | String  | Name of the cloud resource. May be empty for purchases.                                                                                                                                                                                                                |
| ResourceLocation       | String  | Cloud provider location the service is operated in.                                                                                                                                                                                                                    |
| ServiceFamily          | String  | Groups service charges based on the core function of the service. Can be used to track the migration of workloads across fundamentally different architectures, like IaaS and PaaS data storage. As of Feb 2023, there is a bug for EA where this is always "Compute". |
| ServiceInfo1           | String  | Additional information about a service charge. Differs by service.                                                                                                                                                                                                     |
| ServiceInfo2           | String  | Additional information about a service charge. Differs by service.                                                                                                                                                                                                     |
| SKU                    | String  | Derived. Extracted from AdditionalInfo. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| SubscriptionId         | String  | Unique identifier (GUID) of the Microsoft Cloud subscription.                                                                                                                                                                                                          |
| SubscriptionName       | String  | Name of the Microsoft Cloud subscription.                                                                                                                                                                                                                              |
| Tags                   | Object  | Custom metadata (key/value pairs) applied to the resource or product the charge applies to. Formatted as a JavaScript object (JSON). Microsoft Cloud has a bug where this is missing the outer braces.                                                                 |
| TagsDictionary         | Object  | Derived. Object version of Tags.                                                                                                                                                                                                                                       |
| Term                   | Number  | Number of months a purchase covers. Only applicable to commitments today.                                                                                                                                                                                              |
| UnitOfMeasure          | String  | Indicates what measurement type is used by the Quantity.                                                                                                                                                                                                               |
| UnitPrice              | Number  | On-demand price per unit without commitment-based discounts. This includes negotiated discounts.                                                                                                                                                                       |
| UsageType              | String  | Derived. Extracted from AdditionalInfo. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| VMName                 | String  | Derived. Extracted from AdditionalInfo. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| VMProperties           | String  | Derived. Extracted from AdditionalInfo. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| VCPUs                  | Number  | Derived. Indicates the number of virtual CPUs used by this resource. Extracted from AdditionalInfo. Used for Azure Hybrid Benefit reports.                                                                                                                             |
