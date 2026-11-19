# Deployment profile sources

`native/` defines the Azure Cost Management MCP connector and the native schedules and read-only Python tools. `hubs/` defines the Kusto connector and the Hub-backed schedules and read-only Python tools. `shared/` contains the Teams binding, built-in tool settings, and skill entry files used by one or both profiles.

`bin/build-package.py` combines these inputs with the canonical FinOps query catalog under `src/queries/catalog/` and the shared output style under `src/templates/agent-plugin/output-styles/`. Neither profile depends on a sibling SRE Agent template. Keep the two sets of Python definitions distinct where their tested behavior differs.
