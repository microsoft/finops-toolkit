# ☁️ Configure daily/monthly exports using managed exports

![Version 0.0.1](https://img.shields.io/badge/version-0.0.1-darkgreen)
&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/title/microsoft/cloud-hubs/1?label=roadmap)](https://github.com/microsoft/cloud-hubs/issues/1)

On this page:

- [Managed export requirements](#managed-export-requirements)
- [Managed export configuration](#managed-export-configuration)
- [Export scope examples](#export-scope-examples)
- [Configure Cost Management exports manually](#configure-cost-management-exports-manually)

---

## Managed export requirements

- Managed exports require granting permissions against the export scope to the managed identity used by Data Factory.  If this is not desireable/feasable use Cost Management exports instead
- Managed exports support EA Enrollment, EA Department and Subscription level imports.
- **MCA Billing Accounts and Billing Profiles are not supported by managed exports.  Rather use [cost management exports](./cm-exports.md).**
- Minimum required permissions for the export scope:
  - _**EA Enrollment:** EA Reader_
  - _**EA Department:** Department Reader_
  - _**Subscription:** Cost Management Contributor_
  
## Managed export configuration

> 💡 _Note: MCA billing scopes are not supported for managed exports at this time.  Use Cost Management Exports instead._

1. Grant required permissions to the managed identity of the Data Factory.
2. Add the export scope(s) to the exportScopes section of the settings.json file in the config container.  
3. Wait for the msexports_setup pipeline to configure managed exports for the specified scopes.
4. Execute the msexports_backfill pipeline to fill the dataset per the retention settings in settings.json.

## Export scope examples

````json
   "exportScopes": [
      {
         "scope": "/subscriptions/00000000-0000-0000-0000-000000000000"
      },
      {
         "scope": "/providers/Microsoft.Billing/billingAccounts/12345678"
      },
      {
         "scope": "/providers/Microsoft.Billing/billingAccounts/12345678/departments/1234"
      }
    ]
````

<br>

## Configure Cost Management exports manually

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

2. Run your export.
   - Exports can take up to a day to show up after first created.
   - Use the **Run now** command at the top of the Cost Management Exports page.
   - Your data should be available within 15 minutes or so, depending on how big your account is.