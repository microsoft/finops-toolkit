# 🏗️ Architecture

| Name                                               | Description                      |
| -------------------------------------------------- | -------------------------------- |
| [docs](../docs)                                    | Public-facing toolkit docs.      |
| ├─ [deploy](../docs/deploy)                        | How to deploy the toolkit.       |
| ├─ [reports](../docs/reports)                      | About Power BI reports.          |
| └─ [templates](../docs/templates)                  | About ARM deployment templates.  |
| &nbsp; &nbsp; &nbsp; └─ [modules](../docs/modules) | About Bicep modules.             |
| [src](../src)                                      | Source code and internal docs.   |
| ├─ [bicep-registry](../src/bicep-registry)         | Bicep registry module templates. |
| ├─ [modules](../src/modules)                       | Bicep modules.                   |
| └─ [templates](../src/templates)                   | ARM deployment templates.        |

Files and folders should use kebab casing (e.g., `this-is-my-folder`). The only exception is for RP namespaces in module paths.

<br>
