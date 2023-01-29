![Status: Not started](https://img.shields.io/badge/status-not%20started-red) &nbsp;<sup>→</sup>&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)

# export.bicep

This module deploys a **Cost Management export** instance for any scope.

On this page:

- [Resources](#resources)
- [Parameters](#parameters)
- [Outputs](#outputs)
- [Future considerations](#future-considerations)

---

## Resources

- Export

## Parameters

- **exportName** (string) – Name of the export.
- **amortize** (boolean) – Indicates whether the export should include amortized data. Default: `false`.
- **storageAccountId** (string) – Storage account resource ID to use for this export.
- **storageAccountContainer** (string) – Name of the container to use for exported data. Default: `ms-cm-exports` (required for FinOps hubs).
- **storageAccountPath** (string) – Folder path within the container to use for exported data. Default: (scope ID without the first "/").

## Outputs

- **exportId** (string) – Resource ID of the export that was created.

---

## Future considerations

- Expand export module to cover all settings
