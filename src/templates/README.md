# 📦 FinOps toolkit templates

- [finops-hub](./finops-hub)

On this page:

- [✨ Creating templates](#-creating-templates)
- [📦 Building templates](#-building-templates)
- [🧪 Testing templates](#-testing-templates)

---

## ✨ Creating templates

Templates follow the [Azure Quickstart Templates guidelines](https://github.com/Azure/azure-quickstart-templates/blob/master/1-CONTRIBUTION-GUIDE/README.md#contribution-guide):

1. Every template should be in its own folder.
   - Try to keep name lengths under 30 characters when possible.
   - Prefer consistent naming across related templates.
2. All files and folders should use kebab casing (lowercase with dashes between words), except README.md.
3. All templates must include the following:

   - `README.md`
     1. Start from the latest [sample README](https://github.com/Azure/azure-quickstart-templates/blob/master/1-CONTRIBUTION-GUIDE/sample-README.md).
     2. Include the Bicep badge.
     3. Include a Deploy to Azure/AzureGov and Visualize buttons.
        - Sample URL: `https://portal.azure.com/#create/Microsoft.Template/uri/<url-encoded-azuredeploy-path>/createUIDefinitionUri/<url-encoded-createUiDef-path>`
     4. Include a description of what the template will deploy.
     5. Try to avoid having prerequisites. If needed, document them and include a prereq template in the `prereqs` folder and prefix template files with `prereq.`.
     6. Include a description of how to use the resources (or a link to help docs in this repo).
     7. Include any additional notes or considerations for people deploying and managing the template.
     8. Include a list of tags at the bottom of the file. Tags are enclosed in back-ticks.
   - `metadata.json`

     1. Be sure to indicate when features are not available in Azure Gov.
     2. Must adhere to the following structure:

        ```json
        {
          "$schema": "https://aka.ms/azure-quickstart-templates-metadata-schema#",
          "type": "QuickStart",
          "itemDisplayName": "60 char limit",
          "description": "1000 char limit",
          "summary": "200 char limit",
          "githubUsername": "...",
          "dateUpdated": "yyyy-MM-dd"
        }
        ```

   - `main.bicep`
     1. Sort the root elements in this order: targetScope, parameters, variables, resources and modules references, outputs.
     2. Parameter names should be camel-cased.
     3. Every parameter should have a `@description` or `@metadata` decorator first.
     4. Specify a default value when possible.
     5. Place a blank line between each parameter.
     6. Do not include `azuredeploy.json`. This will be built automatically when merged.
     7. Do not include `azuredeploy.parameters.json`. This will be created by the `Build-Toolkit` script.
        - PR validation requires all parameters to have a `defaultValue` if not covered in Bicep (unless they can be an empty string).
        - Our build script assumes parameters are the same in Azure Gov. If they're not, add a custom `azuredeploy.parameters.us.json` file.
        - If you need to add a default parameter value, update the `Build-Toolkit` script to add it automatically.
        - If adding a default value automatically isn't feasible, add support for manually-created parameter files (don't auto-generate).
   - `createUiDefinition.json`
     - [CreateUiDef docs](https://learn.microsoft.com/azure/azure-resource-manager/managed-applications/create-uidefinition-overview)
     - [Test in portal](https://portal.azure.com/?feature.customPortal=false&#blade/Microsoft_Azure_CreateUIDef/SandboxBlade)
   - Optional: `.buildignore`
     - Add the relative path to any files you want to exclude (for example, README files for dev docs, test folders).

4. Submit a PR to Azure Quickstart Templates repo.

   - For the [Azure Quickstart Templates repository](https://github.com/Azure/azure-quickstart-templates).
   - Clone your fork locally.
   - Run the [`Publish-Toolkit`](../scripts/README.md#-publish-toolkit) script.

     ```powershell
     cd <repo-root>/src/scripts
     ./scripts/Publish-Toolkit "<template-name>" ../../../path/to/aqt -Build -Commit
     ```

   - Click the link in the console to create the PR in your browser.
   - Wait 5-10 minutes for the PR validation to complete.
   - If it fails, click the **Details** link to see the failure details.
   - If it's successful and you see labels like `readme violations`, `best practices violations`, or `BPA`, click the **Details** link to see what errors occurred.
   - Fix the errors and re-run the Publish-Toolkit script without the `-Commit` flag.

     ```powershell
     cd <repo-root>/src/scripts
     ./scripts/Publish-Toolkit "<template-name>" ../../../path/to/aqt -Build
     ```

   - Manually commit and push your changes to your Azure Quickstart Templates repo.
   - Wait for the PR validation to complete and repeat as needed.
   - If you get a failure that doesn't have enough details, try running the [Template Analyzer](https://github.com/Azure/template-analyzer) locally.
   - Optionally, you can also run [arm-ttk](https://github.com/Azure/arm-ttk) locally, but this shouldn't be needed.

## 📦 Building templates

There are 2 ways to build templates. To build all toolkit modules and templates, run:

```console
cd $repo/src/scripts
./Build-Toolkit
```

To build only a single template, run:

```console
cd $repo/src/scripts
./Build-Toolkit <template-name>
```

See [`Build-Template`](../scripts/README.md#📦-build-toolkit) for optional parameters.

> ℹ️ _Note: Both build scripts must be run from the `src/scripts` folder._

<br>

## 🧪 Testing templates

Before deploying a template, you first need to sign in to Azure:

```console
Connect-AzContext
Set-AzContext -Subscription "Trey Research R&D Playground"
```

> ℹ️ _**Microsoft contributors:** We recommend using the Trey Research R&D Playground subscription (64e355d7-997c-491d-b0c1-8414dccfcf42) for subscription deployments. Contact @flanakin to request access._

Use the `Deploy-Toolkit` script to deploy a template. In its simplest form, you need only specify the name (not the path) of the module you want to deploy to run the local dev version of the module (not the generated versions):

```console
cd $repo/src/scripts
./Deploy-Toolkit finops-hub
```

You can optionally build templates by specifying the `-Build` parameter:

```console
cd $repo/src/scripts
./Deploy-Toolkit finops-hub -Build
```

Use `-WhatIf` to validate the template without deploying anything first.

> ℹ️ _**Note:** Templates are deployed to a unique resource group based on your username and computer name: `ftk-<username>-<computername>`. Please delete resources after templates are validated._

To learn more, see [`Deploy-Toolkit`](../scripts/README.md#-build-toolkit).

<br>
