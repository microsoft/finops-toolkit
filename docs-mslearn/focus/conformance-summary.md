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

## Scenarios cannot be completed as intended

| Column              | ID                                                                                                                                                                     | Gap             | Description                                                                                                                                                                                                     |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ContractedCost      | [NH1-3](./conformance-full-report.md#null-handling), [CnC1.2](./conformance-full-report.md#contracted-cost), [DH2.4.2](./conformance-full-report.md#discount-handling) | Missing data    | `ContractedCost` is not supported and will be 0 for EA Marketplace charges, EA reservation usage when cost allocation is enabled, MCA reservation usage.<br><br>Workaround: Join with price sheet dataset.      |
| ContractedUnitPrice | [NH1-3](./conformance-full-report.md#null-handling), [CnUP3.1](./conformance-full-report.md#contracted-unit-price)                                                     | Missing data    | `ContractedUnitPrice` is not supported and will be 0 for EA Marketplace charges, EA reservation usage when cost allocation is enabled, MCA reservation usage.<br><br>Workaround: Join with price sheet dataset. |
| ListCost            | [NH1-3](./conformance-full-report.md#null-handling), [LC1.2](./conformance-full-report.md#list-cost)                                                                   | Missing data    | `ListCost` is not supported and will be 0 for EA or MCA Marketplace charges, EA or MCA reservation usage.<br><br>Workaround: Join with price sheet dataset.                                                     |
| ListUnitPrice       | [NH1-3](./conformance-full-report.md#null-handling), [LUP3.1](./conformance-full-report.md#list-unit-price)                                                            | Missing data    | `ListUnitPrice` is not supported and will be 0 for EA or MCA Marketplace charges, EA or MCA reservation usage.<br><br>Workaround: Join with price sheet dataset.                                                |
| SkuPriceId          | [SkPI4](./conformance-full-report.md#sku-price-id)                                                                                                                     | Broken scenario | `SkuPriceId` does not identify a single price and does not have an equivalent in the price sheet.                                                                                                               |

<br>

## Scenarios require additional logic

| Column               | ID                                                                                                                                                        | Gap              | Description                                                                                                                                                                                    |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BillingPeriodEnd     | [BPE2.2](./conformance-full-report.md#billing-period-end)                                                                                                 | Incorrect data   | `BillingPeriodEnd` has a known bug where the time is "23:59:59.999" when it should be "00:00:00".<br><br>Workaround: Remove the time element or update it to be midnight.                      |
| ContractedCost       | [CnC5](./conformance-full-report.md#contracted-cost)                                                                                                      | Incorrect data   | `ContractedCost` uses the wrong scale and is incorrect for Enterprise Agreement accounts.<br><br>Workaround: Multiply the `ContractedCost` by `x_PricingBlockSize`.                            |
| PricingQuantity      | [PQ5](./conformance-full-report.md#pricing-quantity), [CnC3](./conformance-full-report.md#contracted-cost), [LC3](./conformance-full-report.md#list-cost) | Incorrect data   | `PricingQuantity` uses the wrong scale and is incorrect for Enterprise Agreement accounts.<br><br>Workaround: Multiply the `PricingQuantity` by `x_PricingBlockSize`.                          |
| SkuPriceId           | [NH1-3](./conformance-full-report.md#null-handling)                                                                                                       | Should be null   | `SkuPriceId` can be "-2" when there is no value.<br><br>Workaround: Replace "-2" with null.                                                                                                    |
| SubAccountName       | [NH1-3](./conformance-full-report.md#null-handling), [SAN3](./conformance-full-report.md#sub-account-name)                                                | Should be null   | `SubAccountName` can be "Unassigned" when there is no value.<br><br>Workaround: Replace "Unassigned" with null.                                                                                |
| PublisherName        | [PbN2.2](./conformance-full-report.md#publisher-name)                                                                                                     | Missing data     | `PublisherName` is null for reservation usage, reservation purchases, and savings plan unused charges.<br><br>Workaround: Replace null with "Microsoft".                                       |
| ResourceName         | [SH2](./conformance-full-report.md#string-handling)                                                                                                       | Incorrect casing | `ResourceName` may not be in the original case.<br><br>Workaround: Lowercase to ensure consistent casing when grouping and file a support request on the service responsible for the resource. |
| CommitmentDiscountId | [DH3.12](./conformance-full-report.md#discount-handling)                                                                                                  | Incorrect casing | `CommitmentDiscountId` does not match `ResourceId` exactly because `ResourceId` is lowercased.<br><br>Workaround: Convert `CommitmentDiscountId` to lowercase if comparing to `ResourceId`.    |

<br>

## No impact to documented scenarios

| Column             | ID                                                              | Gap                     | Description                                                                                                                                                                          |
| ------------------ | --------------------------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| BillingAccountName | [BAN3](./conformance-full-report.md#billing-account-name)       | Nonfunctional alignment | `BillingAccountName` is not guaranteed to be unique.<br><br>Workaround: Update billing account/profile name to be unique.                                                            |
| Tags               | [T10](./conformance-full-report.md#tags)                        | Nonfunctional alignment | Provider-specified tags are not prefixed.<br><br>Workaround: No action needed.                                                                                                       |
| ResourceId         | [SH2](./conformance-full-report.md#string-handling)             | Incorrect casing        | `ResourceId` is lowercased to meet FOCUS requirements.<br><br>Workaround: No action needed.                                                                                          |
| SkuId              | [SkI3.1](./conformance-full-report.md#sku-id)                   | Missing data            | `SkuId` is null when a charge does not have a corresponding price in the price sheet, like savings plan unused charges and Marketplace charges.<br><br>Workaround: No action needed. |
| BillingAccountType | [CNO2](./conformance-full-report.md#column-naming-and-ordering) | Invalid column name     | `BillingAccountType` should be prefixed with `x_`.<br><br>Workaround: Do nothing. This column is pending inclusion.                                                                  |
| SubAccountType     | [CNO2](./conformance-full-report.md#column-naming-and-ordering) | Invalid column name     | `SubAccountType` should be prefixed with `x_`.<br><br>Workaround: Do nothing. This column is pending inclusion.                                                                      |

<br>

## FOCUS suggestions

The following are not blocking specification conformance, but are not fully supported.

| Column                   | ID                                                     | Gap                   | Description                                                                                                                  |
| ------------------------ | ------------------------------------------------------ | --------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| AvailabilityZone         | [AZ1](./conformance-full-report.md#availability-zone)  | Missing data          | `AvailabilityZone` is not specified.                                                                                         |
| ChargeDescription        | [CD4](./conformance-full-report.md#charge-description) | Missing documentation | `ChargeDescription` max length is not documented.                                                                            |
| ChargeDescription        | [CD3](./conformance-full-report.md#charge-description) | Missing data          | `ChargeDescription` is null for savings plan unused charges and charges that are not directly associated with a product SKU. |
| x_AccountId              | [NH1-3](./conformance-full-report.md#null-handling)    | Should be null        | `x_AccountId` can be "-2" when there is no value.<br><br>Workaround: Replace "-2" with null.                                 |
| x_AccountName            | [NH1-3](./conformance-full-report.md#null-handling)    | Should be null        | `x_AccountName` can be "Unassigned" when there is no value.<br><br>Workaround: Replace "Unassigned" with null.               |
| x_AccountOwnerId         | [NH1-3](./conformance-full-report.md#null-handling)    | Should be null        | `x_AccountOwnerId` can be "Unassigned" when there is no value.<br><br>Workaround: Replace "Unassigned" with null.            |
| x_InvoiceSectionId       | [NH1-3](./conformance-full-report.md#null-handling)    | Should be null        | `x_InvoiceSectionId` can be "-2" when there is no value.<br><br>Workaround: Replace "-2" with null.                          |
| x_InvoiceSectionName     | [NH1-3](./conformance-full-report.md#null-handling)    | Should be null        | `x_InvoiceSectionName` can be "Unassigned" when there is no value.<br><br>Workaround: Replace "Unassigned" with null.        |
| x_PricingUnitDescription | [NH1-3](./conformance-full-report.md#null-handling)    | Should be null        | `x_PricingUnitDescription` can be "Unassigned" when there is no value.<br><br>Workaround: Replace "Unassigned" with null.    |

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
