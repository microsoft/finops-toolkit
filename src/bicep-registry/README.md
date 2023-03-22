# Bicep registry modules

This folder contains modules that are published to the official [Bicep Registry](https://github.com/Azure/bicep-registry-modules). Modules are maintained here using a simple templating language to facilitate generating modules for multiple scopes without duplicating code.

- [Scheduled action](./scheduled-action)

<br>

On this page:

- [Creating a new module](#creating-a-new-module)
- [Building bicep registry modules](#building-bicep-registry-modules)
- [Testing bicep registry modules](#testing-bicep-registry-modules)
- [Publishing bicep registry modules](#publishing-bicep-registry-modules)
- [Templating language](#templating-language)

---

## Creating a new module

1. Create a folder for the module using kebab casing (e.g., `my-resource`). Module names should be:
   - Singular (e.g., `my-resource` instead of `my-resources`).
   - Named after the resource type (e.g., `virtual-machine` for `virtualMachines`).
2. Run `brm generate` to create placeholder files for the module. [Learn more](https://github.com/Azure/bicep-registry-modules/blob/main/CONTRIBUTING.md#generating-module-files).
3. Update the following files:

   - `metadata.json` – Set the name, summary, and owner (should be `cost-management-contrib`).
   - `version.json` – Set version to `1.0`.
   - `README.md` – Add a title and description only. Do not set parameters, outputs, or examples.

   > _Note: Do not update main.json._

4. Implement the module in `main.bicep` using the templating language below.
5. Implement tests in `test/main.test.bicep` also using the templating language.

<br>

## Building bicep registry modules

There are 2 ways to build bicep registry modules. To build all toolkit modules and templates, run:

```console
cd $repo/src/scripts
./Build-Toolkit
```

To build only a single module, run:

```console
cd $repo/src/scripts
./Build-Bicep ..\bicep-registry\<module>
```

The `Build-Bicep` script supports the following parameters:

| Parameter | Description                                                               |
| --------- | ------------------------------------------------------------------------- |
| `-Module` | Required. Specifies the module to build.                                  |
| `-Scope`  | Optional. Indicates one scope to generate. Default: all scopes.           |
| `-Debug`  | Optional. Writes primary file output to console. Does not generate files. |

> ℹ️ _Note: Both build scripts must be run from the `src/scripts` folder._

<br>

## Testing bicep registry modules

Before deploying a module, you first need to sign in to Azure:

```console
Connect-AzContext
Set-AzContext -Subscription "Trey Research R&D Playground"
```

> ℹ️ _**Microsoft contributors:** We recommend using the Trey Research R&D Playground subscription () for subscription deployments and the FinOps Toolkit tenant (38a09d9b-84be-4c40-8aef-99ebeed474ff) for tenant deployments. Contact @flanakin to request access._
>
> To sign in to the FinOps Toolkit tenant, run:
>
> ```console
> Connect-AzContext -Tenant 38a09d9b-84be-4c40-8aef-99ebeed474ff
> ```

Use the `Deploy-Toolkit` script to deploy a module. In its simplest form, you need only specify the name (not the path) of the module you want to deploy to run the local dev version of the module (not the generated versions):

```console
cd $repo/src/scripts
./Deploy-Toolkit scheduled-action
```

In most cases, you'll want to deploy the generated modules per scope using the test file since it includes all parameters rather than the module itself, where you would need to explicitly provide parameters. To do this, specify `-Build` to build the per-scope modules, `-Test` to use the test file, and specify the generated, scope-specific module name:

```console
cd $repo/src/scripts
./Deploy-Toolkit subscription-scheduled-action -Build -Test
```

Use `-WhatIf` to validate the module without deploying anything first.

> ℹ️ _**Note:** Resource group deployments default to a unique resource group based on your username and computer name: `ftk-<username>-<computername>`. Please delete resources after modules are validated._

The `Deploy-Toolkit` script supports the following parameters:

| Parameter        | Description                                                                                                                        |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `-Template`      | Required. Name of the template or module to deploy. Default = finops-hub.                                                          |
| `-ResourceGroup` | Optional. Name of the resource group to deploy to. Will be created if it doesn't exist. Default = `ftk-<username>-<computername>`. |
| `-Location`      | Optional. Azure location to execute the deployment from. Default = `westus`.                                                       |
| `-Parameters`    | Optional. Parameters to pass thru to the deployment. Defaults per template/module are configured in the script.                    |
| `-Build`         | Optional. Indicates whether the the `Build-Toolkit` command should be executed first. Default = `false`.                           |
| `-Test`          | Optional. Indicates whether to run the template or module test instead of the template or module itself. Default = `false`.        |
| `-Debug`         | Optional. Writes script execution troubleshooting details to console. Does not execute deployment.                                 |
| `-WhatIf`        | Optional. Validates the deployment without executing it or changing resources.                                                     |

<br>

## Publishing bicep registry modules

All modules in this folder are published to the official [Bicep Registry](https://github.com/Azure/bicep-registry-modules). If your module does not require multi-scope support, you can publish it directly to the Bicep Registry. If your module does require multi-scope support, follow the steps above for creating, building, and testing your module. Then, follow the [Bicep Registry contribution guide](https://github.com/Azure/bicep-registry-modules/blob/main/CONTRIBUTING.md) using the locally-generated and validated modules.

The Bicep Registry contribution guide will have you run `brm generate` before submitting your PR. Do not commit the changes from this command back to the FinOps toolkit repo. All other manual changes to the module itself should be made within the FinOps toolkit repo.

If you find a new requirement arises for Bicep Registry onboarding, please update this document and associated scripts. Please [file an issue](https://github.com/microsoft/cloud-hubs/issues) if you identify any bugs or have ideas to improve the process.

<br>

## Templating language

Bicep offers a clean solution to define reusable modules, but has a few limitations that make it onerous for modules that support multiple scopes. We developed a very simple templating language to work around the following limitations:

1. Modules cannot target multiple scopes.
2. Scope functions behave differently for each targeted scope.
3. No mechanism for conditional logic based on scope.

Our templating language supports "scope directives" that enable you to:

1. Leverage existing Bicep developer tooling for the primary scope.
2. Target multiple scopes.
3. Conditionally include a single line.
4. Conditionally include multiple lines.

### Scope directives

Scope directives are single-line comments that reference one or more Bicep-supported scopes (i.e., `resourceGroup`, `subscription`, `managementGroup`, `tenant`). Scopes are prefixed with `@` and are separated by spaces. Do not include additional characters after the scope directive.

The following example references only the resource group scope:

```bicep
// @resourceGroup
```

The following example references all scopes (note order is not important):

```bicep
// @resourceGroup @subscription @managementGroup @tenant
```

Refer to the sections below for how to use scope directives.

### Targeting multiple scopes

Modules are designed to work with a single scope. To target multiple scopes, include a scope directive at the top of the file followed by an empty line. Both lines are removed during the build process.

The following example tells the build script to generate modules targeted at resource groups, subscriptions, and management groups:

```bicep
// @resourceGroup @subscription @managementGroup

@description('The name of the object.')
param name string
```

### Conditional lines

Conditional lines are used to include (or exclude) a single line within a Bicep module. To use a conditional line, add a scope directive to the end of the desired line.

The following example includes 2 conditional lines to represent allowed values that are only supported for specific scopes. `value1` is allowed for resource groups and subscriptions, and `value3` is allowed for tenant deployments:

```bicep
@allowed([
  'value1' // @resourceGroup @subscription
  'value2'
  //'value3' // @tenant
])
```

Note this example is designed to use a primary scope of either resource group or subscription (based on those values being uncommented). Since `value3` is only allowed for tenant deployments, it is commented out by default. This approach ensures the module can be run as-is with existing tooling without modification.

### Conditional blocks

Conditional blocks are used to include (or exclude) multiple lines within a Bicep module. To use a conditional block, add a scope directive immediately before the code block. Conditional blocks end when either another conditional block is specified or an empty line.

The following example includes a single conditional block that is only includes `property1` and `property2` for subscriptions:

```bicep
resource myResource 'Microsoft.MyProvider/resource' = {
  name: 'myResource'
  properties: {
    // @subscription
    //// Comments must have 4 slashes
    property1: 'value1'
    property2: 'value2'

    // ...
  }
}
```

The following example includes multiple conditional blocks with at `scopeType` property that changes based on scope:

```bicep
resource myResource 'Microsoft.MyProvider/resource' = {
  name: 'myResource'
  properties: {
    // @subscription
    scopeType: 'Subscription'
    // @resourceGroup
    //   scopeType: 'ResourceGroup'
    // @managementGroup
    //   // Comments can be indented like code
    //   scopeType: 'ManagementGroup'

    // ...
  }
}
```

Similar to the conditional line example, the code block targeting the primary scope (subscription) is uncommented while the other code blocks are commented out by default. This approach ensures the module can be run as-is with existing tooling without modification or errors (e.g., having the same property defined multiple times). We recommend using extra indentation for each conditional block to make it easier to read.

<br>
