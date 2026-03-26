# FinOps Hubs — Sovereign Cloud Guide

How to build and deploy FinOps Hubs to sovereign Azure clouds (US Government, China) and other sovereign environments.

> **Key insight:** Bicep's `environment()` function compiles to `[environment()]` — an ARM runtime expression that resolves in the *target* cloud. Templates built on any workstation deploy correctly to any cloud. No cross-compilation is needed.

---

## Supported clouds

| Cloud | `environment().name` | Storage suffix | Portal | Status |
|-------|---------------------|---------------|--------|--------|
| Public | `AzureCloud` | `core.windows.net` | `portal.azure.com` | ✅ Fully supported |
| US Government (IL5) | `AzureUSGovernment` | `core.usgovcloudapi.net` | `portal.azure.us` | ✅ Fully supported |
| China (21Vianet) | `AzureChinaCloud` | `core.chinacloudapi.cn` | `portal.azure.cn` | ✅ Fully supported |
| Other sovereign clouds | *(verify with your environment)* | *(verify with your environment)* | *(verify with your environment)* | ⚠️ Supported with parameter overrides |

> **Note:** Some sovereign cloud environment names, DNS suffixes, and portal URLs are not published in public Microsoft documentation. Verify all endpoints against your target environment before deploying.

---

## Deployment

### Phase 1 — Build (requires Bicep CLI; internet optional)

Run once on any workstation with the Bicep CLI installed:

```powershell
# Public (default)
./src/scripts/Build-Toolkit -Template finops-hub

# US Government
./src/scripts/Build-Toolkit -Template finops-hub -PortalUrl "https://portal.azure.us"

# China
./src/scripts/Build-Toolkit -Template finops-hub -PortalUrl "https://portal.azure.cn"

# Other sovereign clouds
./src/scripts/Build-Toolkit -Template finops-hub -PortalUrl "https://<your-portal-url>"
```

The `-PortalUrl` parameter controls the 27 feedback links in `dashboard.json`. Build output lands in `/release/finops-hub/`.

### Phase 2 — Prepare open data (sovereign environments without internet access)

FinOps Hubs uses open-data CSVs for pricing units, regions, resource types, and services. By default these are fetched from GitHub at ADX query time. In sovereign environments without internet access, pre-load them into a storage account container:

```
src/open-data/
├── CommitmentDiscountEligibility.csv   (5.1 MB)
├── PricingUnits.csv                     (12 KB)
├── Regions.csv                          (18 KB)
├── ResourceTypes.csv                   (718 KB)
└── Services.csv                         (54 KB)
```

Upload to a container accessible by the ADX cluster (e.g. `https://<storage>.blob.<suffix>/open-data/`).

### Phase 3 — Deploy (no internet required)

**Option A — Deploy-Toolkit (recommended):**
```powershell
./src/scripts/Deploy-Toolkit -Template finops-hub `
  -ResourceGroup my-finops-rg `
  -Parameters @{
    hubName           = 'my-hub'
    openDataBaseUrl   = 'https://mystg.blob.<your-storage-suffix>/open-data'
    enablePublicAccess = $false
  }
```

**Option B — Azure CLI:**
```bash
az deployment group create -g my-finops-rg \
  --template-file release/finops-hub/main.bicep \
  --parameters hubName=my-hub \
    openDataBaseUrl='https://mystg.blob.<your-storage-suffix>/open-data' \
     enablePublicAccess=false
```

> **Prerequisite:** The Bicep CLI must be pre-installed on the deployment workstation. Azure CLI normally downloads Bicep on first use, but this requires internet access. For sovereign environments without internet access, manually install the Bicep binary beforehand. See [Install Bicep tools](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install).

When `openDataBaseUrl` points to the hub's own storage account, the ADF GitHub linked service and dataset are automatically skipped.

### Phase 4 — Dashboard

Import `dashboard.json` into Azure Data Explorer. The `clusterUri` field is empty — configure it to your cluster URI after import.

### What to transport for offline deployment

```
release/finops-hub/              # Compiled templates + modules
src/open-data/*.csv              # 5 CSV files (~6 MB)
src/scripts/Deploy-Toolkit.ps1   # Optional convenience script
```

---

## Key parameters

| Parameter | Default | Sovereign cloud override |
|-----------|---------|-------------------------|
| `hubName` | *(required)* | — |
| `openDataBaseUrl` | GitHub raw content URL | Storage account URL in your sovereign environment |
| `enablePublicAccess` | `true` | `false` for restricted environments |
| `location` | Resource group location | Target region |

---

## DNS suffix handling

Most DNS suffixes are derived from `environment()` at deployment time. Two services require `replace()` workarounds because ARM does not expose their suffixes directly.

### Correct — uses `environment()` directly

The following all resolve correctly in any cloud with no overrides:

- Storage blob/table/queue endpoints (`environment().suffixes.storage`)
- Key Vault endpoint (`environment().suffixes.keyvaultDns`)
- Resource Manager endpoint (`environment().resourceManager`)
- All ARM resource IDs and API versions

### Workaround — Kusto (ADX) DNS suffix

```bicep
var dataExplorerDnsSuffixLookup = {
  AzureCloud: 'kusto.windows.net'
  AzureUSGovernment: 'kusto.usgovcloudapi.net'
  AzureChinaCloud: 'kusto.windows.cn'
}
var dataExplorerDnsSuffix = dataExplorerDnsSuffixLookup[?environment().name] ?? replace(environment().suffixes.storage, 'core', 'kusto')
```

No `environment().suffixes.dataExplorer` property exists in ARM. [Bicep #12482](https://github.com/Azure/bicep/issues/12482) tracks the broader gap in `environment().suffixes` coverage across many Azure services.

Use a lookup map because the Kusto suffix does **not** follow the same naming pattern as storage across all clouds — China is the notable exception. Unknown environments fall back to the `replace('core', 'kusto')` heuristic.

| Cloud | Suffix | Source |
|-------|--------|--------|
| Public | `kusto.windows.net` | [Private Link DNS zones](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns) |
| US Government | `kusto.usgovcloudapi.net` | Naming convention (not in public docs) |
| China | `kusto.windows.cn` | [Private Link DNS zones](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns) |

Used in: private DNS zone name, cluster connection URI, ADF managed private endpoint FQDN.

### Workaround — Key Vault private DNS zone

```bicep
name: 'privatelink${replace(environment().suffixes.keyvaultDns, 'vault', 'vaultcore')}'
```

The `vault` → `vaultcore` pattern for private DNS zones is documented by Microsoft and verified across all standard clouds.

---

## Known cosmetic issues

These do not affect deployment or runtime behavior:

| Item | Location | Impact |
|------|----------|--------|
| Private DNS zone config labels hardcode `westus`, `windows.net` | `Analytics/app.bicep:512–530` | ARM resource labels only; not DNS names |
| UI tooltip shows `core.windows.net` as example | `createUiDefinition.json:169` | Display only; regex validation is cloud-agnostic |

---

## Safe hardcoded URLs (no action needed)

| URL | Why safe |
|-----|----------|
| `schema.management.azure.com/schemas/...` | ARM `$schema` — format identifier, not fetched at runtime |
| `dataexplorer.azure.com/static/d/schema/...` | ADX dashboard `$schema` — document type identifier |
| `aka.ms/*` links | Microsoft-managed redirects in help text |
| `microsoft.github.io/finops-toolkit/...` | Bicep `metadata:` annotation — informational only |
