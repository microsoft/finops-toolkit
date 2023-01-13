# FinOps hubs modules

FinOps hubs are comprised of [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep) modules. Bicep is a domain-specific language that uses declarative syntax to define and deploy Azure resources. For a guided learning experience, start with the [Fundamentals of Bicep](https://learn.microsoft.com/training/paths/fundamentals-bicep/).

Modules:

- [export](./export.md)
- [hub](./hub.md)

---

Tip: Use the Bicep decompiler to get a starting point from an existing JSON template. Validate to ensure it is correct.

```
bicep decompile azuredeploy.json --outfile decompile.bicep
```
