# ☁️ Configure daily/monthly exports using cost management exports

![Version 0.0.1](https://img.shields.io/badge/version-0.0.1-darkgreen)
&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/title/microsoft/cloud-hubs/1?label=roadmap)](https://github.com/microsoft/cloud-hubs/issues/1)



## Configure daily/monthly exports using Cost Management exports

Use Cost Management exports for MCA scopes or scenarios where you cannot grant permissions to Azure Data Factory.

1. [Create a new cost export](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-export-acm-data?tabs=azure-portal) using the following settings:
   - **Metric** = `Amortized cost`
   - **Export type** = `Daily export of month-to-date costs`
     > 💡 _**Tip:** Configuring a daily export starts in the current month. If you want to backfill historical data, create a one-time export and set the start/end dates to the desired date range.  For best performance create one for calendar month of historical data you want to backfill._
   - **File Partitioning** = `On`
   - **Storage account** = (Use subscription/resource from step 1)
   - **Container** = `msexports`
   - **Directory** = (Use the resource ID of the scope you're exporting without the first "/")

     > - _**EA Enrollment:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}_
     > - _**EA Department:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}/departments/{departmentId}_
     > - _**MCA Billing Account:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}_
     > - _**MCA Billing Profile:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}_
     > - _**Subscription:** subscriptions/{subscriptionId}_

2. Run your export.
   - Exports can take up to a day to show up after first created.
   - Use the **Run now** command at the top of the Cost Management Exports page.
   - Your data should be available within 15 minutes or so, depending on how big your account is.
