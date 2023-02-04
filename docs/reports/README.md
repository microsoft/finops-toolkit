# FinOps toolkit reports

The FinOps toolkit hosts data in [Azure Data Lake Storage](https://learn.microsoft.com/azure/storage/blobs/data-lake-storage-introduction). You can use any tool to query and report on your cost data in storage. As an example, we've included the following Power BI reports to get you started. We recommend customizing them to keep what works, edit and augment reports with your own data, and remove anything that isn't needed.

> ℹ️ _The Power BI reports (PBIX files) are a starter kit. Keep in mind you won't be able to upgrade a customized report as the toolkit evolves._

- [Cost summary](./cost-summary.md)
- [Commitment discounts](./commitment-discounts.md)

See also:

- [Common terms](./terms.md)

<br>

On this page:

- [How to setup Power BI](#how-to-setup-power-bi)
- [Queries and datasets](#queries-and-datasets)

---

## How to setup Power BI

FinOps toolkit Power BI reports are not connected to your storage account by default. Use the below sections to connect to your cost data.

### Starting from scratch

The following instructions are for adding cost details to a new or existing Power BI report:

TODO: Confirm these instructions

1. Open your desired report in Power BI Desktop.
2. Select **Get data** in the toolbar.
3. Search for `lake` and select **Azure Data Lake Storage Gen2**
4. Set the URL to `https://<storage-name>.dfs.core.windows.net/ms-cm-exports` and select the **OK** button.

   - You can copy this value from the deployment outputs.

   > ℹ️ _If you receive an "Access to the resource is forbidden" error, grant the account loading data in Power BI the [Storage Blob Data Reader role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader)._

5. Select the **Combine** button.
6. Select the **OK** button.

### Starting from a toolkit report

The following instructions will help you connect the built-in Power BI reports to your storage account:

1. Download and open the desired report in Power BI Desktop.
2. Select the **Transform data** button in the toolbar.

   ![Screenshot of the Transform data button in the Power BI Desktop toolbar.](https://user-images.githubusercontent.com/399533/216573265-fa76828f-c9a2-497d-ae1e-19b55fef412c.png)

3. In the **Queries** pane on the left, update the following parameters by selecting each and updating the value as appropriate:

   - **StorageAccountName** is the name of your FinOps toolkit storage account. You can copy this from your deployment outputs.
   - **BillingProfileIdOrEnrollmentNumber** is your EA enrollment number or MCA billing profile ID. This is only included for some reports that pull data from the Cost Management Power BI connector. See [Create visuals and reports with the Azure Cost Management connector in Power BI Desktop](https://learn.microsoft.com/power-bi/connect-data/desktop-connect-azure-cost-management) for details.
   - **Scope** must be either `EnrollmentNumber` for an EA billing account or `BillingProfileId` for an MCA billing profile.

4. Select the **Close & Apply** to save your settings.

<br>

## Queries and datasets

_<sup>Recommended dataset: **CMExports**</sup>_

FinOps toolkit offers multiple versions of cost details to align to different schemas for backwards compatibility. These schemas are only provided to assist in migrating from older versions. We recommend updating visuals to use the newest dataset. If you do not need a legacy dataset, you can remove it from the Power Query Editor (Transform data) window.

> ℹ️ _FinOps toolkit will eventually adopt the [FOCUS standard](https://aka.ms/finops/focus) when available._

### CMConnector

The CMConnector dataset uses the original schema from the "Azure Cost Management" Power BI connector. This dataset is only provided for backwards compatibility.

### CMExports

Uses the raw column names from Cost Management exports. This mostly aligns to the [CMConnector](#cmconnector) schema, but with a few small differences:

- **BillingCurrency** renamed to **BillingCurrencyCode**.
- **InvoiceSection** renamed to **InvoiceSectionName**.
- **IsCreditEligible** changed from a string (`True` or `False`) to a boolean.
- **Product** renamed to **ProductName**.
- Added **CostAllocationRuleName**.
- Added **BenefitId**.
- Added **BenefitName**.
