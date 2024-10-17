---
title: Conformance summary
description: General information about the FOCUS dataset including the data generator, schema version, and columns included in the dataset.
author: bandersmsft
ms.author: banders
ms.date: 07/15/2024
ms.topic: reference
ms.service: finops
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# FOCUS conformance summary

This document summarizes the known conformance gaps for the latest FOCUS 1.0 dataset in Microsoft Cost Management compared to the FOCUS 1.0 specification. To learn more about FOCUS, refer to the [FOCUS overview](./what-is-focus.md).

<br>

## Overall conformance

The Microsoft Cost Management FOCUS 1.0 dataset has a conformance score of **95%**.

The remaining conformance gaps are summarized below. The list is categorized by their impact to primary FinOps scenarios. For additional details on these or other FOCUS requirements, please refer to the [full conformance report](./conformance-full-report.md). The IDs provided in the tables below are for reference purposes only. IDs are not defined as part of FOCUS.

<br>

## Missing data

| Issue                                                                                                                                                                                   | Workaround                                    | Columns / Requirements                                                 |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- | ---------------------------------------------------------------------- |
| ContractedUnitPrice and ContractedCost are not supported and will be 0 for EA Marketplace charges, EA reservation usage when cost allocation is enabled, and all MCA reservation usage. | Join with price sheet dataset.                | ContractedCost, ContractedUnitPrice<br>DH2.4.2, NH1-3, CnC1.2, CnUP3.1 |
| ListCost is not supported and will be 0 for EA or MCA Marketplace charges, EA or MCA reservation usage.                                                                                 | Join with price sheet dataset.                | ListCost, ListUnitPrice<br>DH2.4.2, NH1-3, LC1.2, LUP3.1               |
| SkuId is null when a charge does not have a corresponding price in the price sheet, like savings plan unused charges and Marketplace charges.                                           | No action needed.                             | SkuId<br>SkI3.1                                                        |
| ChargeDescription is null for savings plan unused charges and charges that are not directly associated with a product SKU.                                                              | Replace with computed alternative as desired. | ChargeDescription<br>CD3                                               |
| PublisherName is null for reservation usage, reservation purchases, and savings plan unused charges.                                                                                    | Replace null with "Microsoft".                | PublisherName<br>PbN2.2                                                |
| AvailabilityZone is not available in cost datasets and the column will not be present.                                                                                                  | Join with resource details.                   | AvailabilityZone<br>AZ1                                                |

<br>

## Incorrect data

| Issue                                                                                                       | Workaround                                           | Columns / Requirements                                                                                                                                      |
| ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PricingQuantity and ContractedCost use the wrong scale and are incorrect for Enterprise Agreement accounts. | Multiply by x_PricingBlockSize.                      | ContractedCost, PricingQuantity<br>PQ5, CnC3, CnC5, LC3                                                                                                     |
| BillingPeriodEnd has a known bug where the time is "23:59:59.999" when it should be "00:00:00".             | Remove the time element or update it to be midnight. | BillingPeriodEnd<br>BPE2.2                                                                                                                                  |
| Date columns all follow the ISO 8601 standard, but do not include seconds (e.g., “2024-01-01T00:00Z”). | Replace “T00:00Z” with “T00:00:00Z”. Do not add “:00” without confirming seconds are not present. This will be resolved in “1.0r2”. | BillingPeriodStart, BillingPeriodEnd, ChargePeriodStart, ChargePeriodEnd, x_BillingExchangeRateDate, x_ServicePeriodEnd, x_ServicePeriodStart<br>DTF5 |
| Some columns can be "-2" or “Unassigned” when there is no value.                                            | Replace "-2" and “Unassigned” with null.             | SkuPriceId, SubAccountName, x_AccountId, x_AccountName, x_AccountOwnerId, x_InvoiceSectionId, x_InvoiceSectionName, x_PricingUnitDescription<br>NH1-3, SAN3 |

<br>

## Inconsistent data

| Issue                                                                                                               | Workaround                                                                                                                  | Columns / Requirements                          |
| ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| SkuPriceId does not identify a single price and does not have an equivalent in the price sheet.                     | Join with the price sheet using x_SkuMeterId, x_SkuOrderId, x_SkuOffer, and CommitmentDiscountType.                         | SkuPriceId<br>SkPI4                             |
| CommitmentDiscountId does not match ResourceId exactly because ResourceId is lowercased to meet FOCUS requirements. | Convert CommitmentDiscountId to lowercase if comparing to ResourceId.                                                       | CommitmentDiscountId, ResourceId<br>DH3.12, SH2 |
| ResourceName may not be in the original case.                                                                       | Lowercase to ensure consistent casing when grouping and file a support request on the service responsible for the resource. | ResourceName<br>SH2                             |

<br>

## Other nonfunctional gaps

| Issue                                                             | Workaround                                                                                                            | Columns / Requirements                     |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| ChargeDescription max length is not documented.                   | Evaluated maximum length as of October 2024 is 355 characters.                                                        | ChargeDescription<br>CD4                   |
| BillingAccountType and SubAccountType should be prefixed with x_. | Do nothing. These columns are pending closure and inclusion in a future FOCUS version. There is an open pull request. | BillingAccountType, SubAccountType<br>CNO2 |
| BillingAccountName is not guaranteed to be unique.                | Update billing account/profile name to be unique.                                                                     | BillingAccountName<br>BAN3                 |
| Provider-specified tags are not prefixed.                         | No action needed.                                                                                                     | Tags<br>T10                                |

<br>

## Related content

Related resources:

- [FOCUS conformance full report](./conformance-full-report.md)
- [Microsoft Cost Management FOCUS dataset](/azure/cost-management-billing/dataset-schema/cost-usage-details-focus.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs)

Related solutions:

- [FinOps toolkit Power BI reports](https://aka.ms/ftk/pbi)
- [FinOps hubs](https://aka.ms/finops/hubs)
- [FinOps toolkit PowerShell module](https://aka.ms/ftk/ps)

<br>
