# 🏗️ Architecture

| Name                                                              | Description                      |
| ----------------------------------------------------------------- | -------------------------------- |
| [docs](../docs)                                                   | Public-facing toolkit docs.      |
| ├─ [bicep-registry](../docs/bicep-registry)                       | Bicep registry module docs.      |
| ├─ [deploy](../docs/deploy)                                       | How to deploy the toolkit.       |
| ├─ [finops-hub](../docs/finops-hub)                               | FinOps hub docs.                 |
| │ &nbsp;&nbsp; ├─ [modules](../docs/finops-hub/modules)           | FinOps hub Bicep modules.        |
| │ &nbsp;&nbsp; └─ [reports](../docs/finops-hub/reports)           | FinOps hub Power BI reports.     |
| └─ [optimization-workbook](../docs/optimization-workbook)         | Cost optimization workbook docs. |
| [src](../src)                                                     | Source code and dev docs.        |
| ├─ [bicep-registry](../src/bicep-registry)                        | Bicep registry modules.          |
| └─ [templates](../src/templates)                                  | ARM deployment templates.        |
| &nbsp; &nbsp; &nbsp; └─ [finops-hub](../src/templates/finops-hub) | FinOps hub template.             |

Files and folders should use kebab casing (e.g., `this-is-my-folder`). The only exception is for RP namespaces in module paths.

<br>
