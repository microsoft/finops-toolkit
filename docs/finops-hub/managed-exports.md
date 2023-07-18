# ☁️ Configure daily/monthly exports using managed exports

![Version 0.0.1](https://img.shields.io/badge/version-0.0.1-darkgreen)
&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/title/microsoft/cloud-hubs/1?label=roadmap)](https://github.com/microsoft/cloud-hubs/issues/1)

On this page:

- [Managed export requirements](#managed-export-requirements)
- [Managed export configuration](#managed-export-configuration)
- [Export scope examples](#export-scope-examples)

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
