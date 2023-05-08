# Workbook modules

This folder contains Azure Monitor workbooks that will be published to Azure Quickstart Templates.

- [Optimization](./optimization)

<br>

On this page:

- [Creating a new workbook](#creating-a-new-workbook)
- [Building workbook templates](#building-workbook-templates)
- [Testing workbook templates](#testing-workbook-templates)

---

## Creating a new workbook

Workbooks in the FinOps toolkit reuse common scaffolding in the `.scaffold` folder to generate the files needed when publishing. Use the following steps to create a new workbook:

1. Create a folder for the workbook using kebab casing (e.g., `my-workbook`). Workbook names should be singular (e.g., `my-workbook` instead of `my-workbooks`).
2. Create a `scaffold.json` file:

   1. Start with the following sample:

      ```json
      {
        "name": "",
        "displayName": "",
        "description": ""
      }
      ```

   2. Set `name` to a default resource name.
   3. Set `displayName` to a human-readable name that will be shown in the portal.
   4. Set `description` to a short description.

<br>

## Building workbook templates

There are 2 ways to build workbook templates. To build all toolkit modules and templates, run:

```console
cd $repo/src/scripts
./Build-Toolkit
```

To build only a single workbook template, run:

```console
cd $repo/src/scripts
./Build-Workbook <workbook-name>
```

The `Build-Workbook` script supports the following parameters:

| Parameter   | Description                                                               |
| ----------- | ------------------------------------------------------------------------- |
| `-Workbook` | Required. Specifies the name of the workbook to build.                    |
| `-Debug`    | Optional. Writes primary file output to console. Does not generate files. |

> ℹ️ _Note: Both build scripts must be run from the `src/scripts` folder._

<br>

## Testing workbook templates

Before deploying a workbook template, you first need to sign in to Azure:

```console
Connect-AzContext
Set-AzContext -Subscription "Trey Research R&D Playground"
```

> ℹ️ _**Microsoft contributors:** We recommend using the Trey Research R&D Playground subscription (64e355d7-997c-491d-b0c1-8414dccfcf42) for subscription deployments and the FinOps Toolkit tenant (38a09d9b-84be-4c40-8aef-99ebeed474ff) for tenant deployments. Contact @flanakin to request access._
>
> To sign in to the FinOps Toolkit tenant, run:
>
> ```console
> Connect-AzContext -Tenant 38a09d9b-84be-4c40-8aef-99ebeed474ff
> ```

Use the `Deploy-Toolkit` script to deploy a workbook template. In its simplest form, you need only specify the name (not the path) of the module you want to deploy to run the local dev version of the module (not the generated versions):

```console
cd $repo/src/scripts
./Deploy-Toolkit optimization
```

Workbook templates must be built before they can be deployed. You can optionally build workbook templates by specifying the `-Build` parameter:

```console
cd $repo/src/scripts
./Deploy-Toolkit optimization -Build
```

Use `-WhatIf` to validate the template without deploying anything first.

> ℹ️ _**Note:** Workbooks are deployed to a unique resource group based on your username and computer name: `ftk-<username>-<computername>`. Please delete resources after templates are validated._

To learn more, see [Build-Toolkit](../scripts/README.md#build-toolkit).

<br>
