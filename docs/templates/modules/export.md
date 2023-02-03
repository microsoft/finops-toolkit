# export.bicep

![Status: Not started](https://img.shields.io/badge/status-not%20started-red) &nbsp;<sup>→</sup>&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)

This module deploys a **Cost Management export** instance for any scope.

Note this export can be used for any purpose and does not have to be exclusively for FinOps hubs, but hubs do require some specific settings. See [Required settings for FinOps hubs](#required-settings-for-finops-hubs) for details.

On this page:

- [Parameters](#parameters)
- [Resources](#resources)
- [Outputs](#outputs)

---

## Parameters

- **exportName** (string) – Name of the export instance.
- **amortize** (boolean) – Optional. Indicates whether the export should amortize reservation purchases. Default: `false`.
- **frequency** (string) – Optional. Indicates how often data should be exported. Allowed: Daily, Weekly, Monthly, Annually. Default: `Daily`.
- **startDate** (string) – Optional. Day to run the first export. Default: Current day.
- **endDate** (string) – Optional. Day to run the last export. Default: 1 year from the current day.
- **period** (string) – Optional. Time frame to export data for. Allowed: BillingMonthToDate, MonthToDate, TheLastBillingMonth, TheLastMonth, WeekToDate. Default: `MonthToDate`.
- **storageAccountId** (string) – Resource ID for the storage account to export files to.
- **storageAccountContainer** (string) – Name of the container to export files to.
- **storageAccountPath** (string) – Path within the container to export files to.
- **runNow** (bool) – Optional. Indicates whether to run the export immediately. Default: true.

### Required settings for FinOps hubs

Note the following parameter values must be set for FinOps hubs to work as designed. Changing these will require additional changes to ensure reporting is accurate.

- **amortize** must be `true`
- **storageAccountContainer** must be `ms-cm-exports`

<br>

## Resources

- Export
  - (See [Parameters](#parameters))

<br>

## Outputs

- **exportId** (string) – Resource ID of the export that was created.
- **exportDestinationUrl** (string) – URL to the folder where exported files will be sent.

<br>
