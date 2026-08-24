# Microsoft.Billing/Invoices

Downloads Microsoft invoice files into the FinOps hub data lake so you can reconcile invoices against your cost data and keep an auditable archive.

## What gets deployed

| Resource | Name | Description |
| -------- | ---- | ----------- |
| Linked service | `invoices_download` | Generic HTTP linked service used to download invoice files. |
| Dataset | `invoices_download` | Binary source for the short-lived SAS URL returned by the Billing API. |
| Dataset | `invoices_file` | Binary sink in the ingestion container. |
| Pipeline | `invoices_DownloadInvoices` | Resolves the billing accounts to process and runs the download pipeline for each one. |
| Pipeline | `invoices_DownloadBillingAccountInvoices` | Downloads all invoices for a single billing account. |
| Pipeline | `invoices_DownloadInvoiceFile` | Requests a download URL for a single invoice and saves the file. Polls the Billing API while the request is still running. |
| Trigger | `invoices_MonthlySchedule` | Runs once a month to download invoices from the previous month. |

Invoice files are saved in the **ingestion** container using the following hierarchy:

```text
ingestion/
└── invoices/
    └── {YYYY-MM}/
        └── {billingProfileId}/
            └── {purchaseOrderNumber}/
                └── {invoiceNumber}.pdf
```

The billing profile ID is used instead of the display name to avoid spaces and special characters in path names. Invoices without a purchase order number are saved in a `no-po` folder.

## Requirements

| # | Requirement | Notes |
| - | ----------- | ----- |
| 1 | Microsoft Customer Agreement (MCA) or Microsoft Partner Agreement (MPA) billing account | Legacy Enterprise Agreement (EA) billing accounts do not support invoice downloads. The pipeline returns an empty list and completes successfully. |
| 2 | Billing account ID | Find it in **Cost Management + Billing** > **Properties**. |
| 3 | `Billing Reader` role for the hub managed identity | Must be granted after deployment. See below. |

## Configuration

Enable the feature with the **Invoices** step in the deployment wizard, or set the following template parameters:

| Parameter | Description |
| --------- | ----------- |
| `enableInvoiceDownload` | Set to `true` to deploy the app. Default: `false`. |
| `invoiceBillingAccounts` | Billing account IDs to download invoices for, separated by a new line, comma, or semicolon. Leave empty to use the billing account scopes monitored by the hub. |
| `invoiceScheduleDay` | Day of the month to download invoices from the previous month. Default: `10`. |

Billing accounts are stored in the `invoices.billingAccounts` array in `settings.json` in the **config** container. You can update that array directly, but the value is overwritten on the next deployment.

## Grant the Billing Reader role

Billing account scopes exist outside of any Azure subscription and are not part of Azure RBAC, so the role assignment cannot be created during deployment and `az role assignment create` doesn't work. Grant it after the hub is deployed:

```powershell
Add-FinOpsHubBillingReader -BillingAccountId '<billing-account-id>'
```

Or grant it in the Azure portal under **Cost Management + Billing** > your billing account > **Access control (IAM)**, assigning the **Billing account reader** role to the Data Factory managed identity.

## Validate the deployment

1. Open the hub Data Factory and run the `invoices_DownloadInvoices` pipeline in debug mode.
2. Confirm each activity succeeds:
   - `Load Settings` returns the hub settings.
   - `List Invoices` returns a populated `value` array.
   - `Request Download URL` returns a download URL for each invoice, or a 202 status followed by `Until Download URL Is Ready` completing.
   - `Save Invoice File` reports more than 0 bytes written.
3. Confirm the files exist in the `invoices` folder of the ingestion container.

## Troubleshooting

| Symptom | Cause | Resolution |
| ------- | ----- | ---------- |
| `List Invoices` returns 401 or 403 | The managed identity is missing the `Billing Reader` role, or it was granted at the wrong scope. | Run `Add-FinOpsHubBillingReader` and confirm the scope is the billing account, not the resource group. |
| `List Invoices` returns an empty array | There are no invoices for the period, or the billing account is a legacy EA account. | Run the pipeline with `periodOffsetMonths` set to `-2`. Confirm the account type in **Cost Management + Billing** > **Properties**. |
| `Download Invoices Per Billing Account` iterates 0 times | No billing accounts are configured and no billing account scopes are monitored. | Set `invoiceBillingAccounts`, or add a billing account scope to the hub. |
| `Request Download URL` returns 404 | The invoice ID is malformed. | Check the `List Invoices` output and confirm each `id` starts with `/providers/Microsoft.Billing/`. |
| `Missing Download URL` fails the pipeline | The Billing API accepted the request but never returned a download URL within 30 minutes. | Confirm the invoice is available for download in the portal. Increase the `Until Download URL Is Ready` timeout if the account consistently takes longer. |
| `Save Invoice File` fails with an expired URL | Too much time elapsed between requesting the URL and copying the file. | Download URLs expire in about an hour. Reduce the `batchCount` on the `Download Invoices` loop. |
| `Save Invoice File` fails with a permission error | The managed identity is missing `Storage Blob Data Contributor` on the hub storage account. | Redeploy the hub. This role is granted automatically. |

## Cost

Only Data Factory activity runs and a small amount of storage are added. For a typical account with about 30 invoices a month, expect roughly 1 USD per month.
