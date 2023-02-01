# FinOps toolkit modules

All FinOps toolkit module source is available at the root of this directory. For summary details, see [public docs](../../docs/templates/modules).

<br>

On this page:

- [About dependencies](#about-dependencies)
- [About Bicep](#about-bicep)

---

## About dependencies

FinOps toolkit modules utilize publicly shared modules from the [Common Azure Resource Module Library (CARML)](https://github.com/Azure/ResourceModules). Each dependency is stored in this directory in folders per resource provider with nested resource types.

> _**NOTE:** Each the readme file in each folder is not updated and may have broken links. They are kept for reference only._

- [Microsoft.Storage/storageAccounts](./Microsoft.Storage/storageAccounts)

### Adding and updating modules

1. Download the latest [CARML release](https://github.com/Azure/ResourceModules/releases).
2. Extract the ZIP file and copy the folders for each resource type you need.
3. Remove any unnecessary folders like `.bicep` and `.test`.
4. Add the following under the first header for each README.md file:

   ```markdown
   <sup>Copied from [<resource-type>](https://github.com/Azure/ResourceModules/tree/main/modules/<resource-type>) - **CARML v<version>** (<copy-date:Mmm d, yyyy>)</sup>
   ```

5. Add the following at the top of each deploy.bicep file:

   ```bicep
   // Source: https://github.com/Azure/ResourceModules/blob/main/modules/<resource-type>/deploy.bicep
   // Date: <copy-date:yyyy-MM-dd>
   // Version: <version>
   ```

6. Review the deploy.bicep file and remove all unneeded settings and nested resource types.

<br>

## About Bicep

FinOps toolkit templates are comprised of [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep) modules. Bicep is a domain-specific language that uses declarative syntax to define and deploy Azure resources. For a guided learning experience, start with the [Fundamentals of Bicep](https://learn.microsoft.com/training/paths/fundamentals-bicep/).
