# Using the local ADX dashboard

This dashboard (`../dashboard.json`) is the upstream FinOps hub dashboard localized to the
ftklocal Kusto emulator. The only change from the upstream file is:

| Field | Upstream value | Local value |
|---|---|---|
| `dataSources[0].clusterUri` | `https://<cloud-cluster>.<region>.kusto.windows.net/` | `http://localhost:8082` |
| `dataSources[0].database` | `Hub` | `Hub` (unchanged) |

All tiles and KQL queries are unmodified. The `Hub` database on the emulator exposes the same
view functions as a deployed hub: `Costs_v1_2`, `Prices_v1_2`, `Transactions_v1_2`,
`CommitmentDiscountUsage_v1_2`, and their aliases (`Costs`, `Prices`, …).

---

## Prerequisites

- ftklocal stack running: `docker compose up` from `src/templates/finops-hub-local/`
- Kusto emulator listening on `http://localhost:8082`
- Hub DB populated (run the ftklocal ingestion scripts or load sample data)

---

## Proven path: query via the CLI

The emulator's KQL REST API is plain HTTP with no authentication — you can query it directly
from the terminal today without a browser. Use `ftk query` (or `ftk run`) against the `Hub`
database:

```bash
# Smoke-test: confirm view functions are populated
ftk query --db Hub "Costs_v1_2 | take 10"

# Run any KQL query interactively
ftk run --db Hub
```

This is the correct first validation step on Mac. It does not depend on any browser
mixed-content policy and works regardless of HTTPS.

Once the agent skill is built (see the skill roadmap), the same Hub view functions will be
available as structured tool calls through the skill surface — no manual KQL required.

---

## Best-effort path: ADX web UI dashboard import

> ⚠️ **Mixed-content limitation — this path is NOT proven on Mac.**
>
> `dataexplorer.azure.com` is served over HTTPS. Browsers (Chrome, Edge, Safari) apply strict
> mixed-content rules: an HTTPS page may not open active connections to a plain `http://`
> origin. Attempting to add `http://localhost:8082` as a cluster from the hosted web UI will
> likely be silently blocked or refused. **Do not assume this works until you verify it in
> your browser.**

If you want to try the dashboard import anyway, follow the steps below. If the cluster
connection fails, see the [ngrok workaround](#workaround-expose-the-emulator-over-https-with-ngrok).

### 1. Attempt to connect the ADX web UI

1. Open **https://dataexplorer.azure.com** in your browser.
2. Click **+ Add cluster** (left sidebar).
3. Enter the connection URI: `http://localhost:8082`
4. Authentication: select **Anonymous** (the emulator runs no-auth HTTP).
5. Click **Add**.

If the cluster appears in the sidebar with `Hub` and `Ingestion` databases, the connection
succeeded and you can proceed. If the connection hangs or errors, use the ngrok workaround
below.

### 2. Import the dashboard

1. In the ADX web UI, click **Dashboards** (left nav).
2. Click the **⋮ menu → Import dashboard from file**.
3. Select `src/templates/finops-hub-local/dashboard.json`.
4. After import, open **Dashboard settings → Data sources** and confirm:
   - Cluster URI: `http://localhost:8082`
   - Database: `Hub`
5. If the data source shows a different cluster URI, edit it to `http://localhost:8082` /
   `Hub` and save.

### 3. Validate tiles

Open any tile (e.g., "Cost summary") and click **Refresh**. If tiles return empty results,
confirm the Hub DB has data by running `Costs_v1_2 | take 10` in the **Query** tab.

---

## Workaround: expose the emulator over HTTPS with ngrok

If the browser blocks the HTTP connection, tunnel the emulator behind HTTPS using
[ngrok](https://ngrok.com):

```bash
# Install ngrok if needed: brew install ngrok/ngrok/ngrok
ngrok http 8082
```

ngrok prints an HTTPS forwarding URL such as `https://xxxx-xxxx.ngrok-free.app`. Use that
URL as the cluster URI in the ADX web UI instead of `http://localhost:8082`. Update the
dashboard data source to match.

> Note: ngrok free-tier URLs are ephemeral and change each session. You will need to update
> the data source in the dashboard each time.

---

## What was proved vs what you must validate

| Claim | Status |
|---|---|
| `dashboard.json` is valid JSON | ✅ Verified (Python `json.load` round-trip) |
| `dataSources[0].clusterUri` → `http://localhost:8082` | ✅ Verified in file |
| `dataSources[0].database` = `Hub` | ✅ Verified in file |
| Hub DB has `Costs_v1_2`, `Prices_v1_2`, etc. | ✅ Verified via `.show functions` on running emulator |
| No upstream cluster names, billing IDs, or absolute paths in dashboard | ✅ Verified |
| `ftk query` / `ftk run` against Hub DB | ✅ Works (HTTP REST, no browser) |
| Browser can add `http://localhost:8082` from `https://dataexplorer.azure.com` | ⚠️ **Not validated** — mixed-content blocked in most browsers |
| Dashboard tiles render data after import | ⚠️ **Not validated** — requires browser import + populated Hub data |

---

## Ingestion vs Hub databases

The emulator runs two databases:

- **`Ingestion`** — raw, transform, and final staging tables used during ingestion. Not
  intended as a query surface.
- **`Hub`** — view functions (`Costs_v1_2`, etc.) that join and normalize the ingested data.
  This is the correct database for the dashboard.

The dashboard's data source is already set to `Hub`.
