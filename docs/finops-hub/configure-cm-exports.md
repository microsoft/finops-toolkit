# 🛠️ Configure Cost Management exports

Use Cost Management exports for MCA scopes or scenarios where you cannot grant permissions to Azure Data Factory.

1. [Create a new cost export](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-export-acm-data?tabs=azure-portal) using the following settings:
   - **Metric** = `Amortized cost`
   - **Export type** = `Daily export of month-to-date costs`
     > 💡 _**Tip:** Configuring a daily export starts in the current month. If you want to backfill historical data, create a one-time export and set the start/end dates to the desired date range.  For best performance create one for calendar month of historical data you want to backfill._
   - **File Partitioning** = `On`
   - **Storage account** = (Use subscription/resource from step 1)
   - **Container** = `msexports`
   - **Directory** = (Use the resource ID of the scope you're exporting without the first "/")

     > - _**Billing account:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}_
     > - _**Billing profile:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}_
     > - _**EA Department:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}/departments/{departmentId}_

2. Create another export using the process in step 1, but this time set **Metric** = `Actual cost`
3. Create another export using the process in step 1, but this time set **Export type** = `Monthly export of last month's costs`
4. Create another export using the process in step 1, but this time set **Metric** = `Actual cost` and **Export type** = `Monthly export of last month's costs`

5. Run your exports to initialize the dataset.
   - Exports can take up to a day to show up after first created.
   - Use the **Run now** command at the top of the Cost Management Exports page.
   - Your data should be available within 15 minutes or so, depending on how big your account is.