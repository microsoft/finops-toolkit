# Using the local ADX dashboard

This dashboard (`../dashboard.json`) is the upstream FinOps hub dashboard localized to the
ftklocal Kusto emulator. The only change from the upstream file is:

| Field                       | Upstream value                                        | Local value             |
| --------------------------- | ----------------------------------------------------- | ----------------------- |
| `dataSources[0].clusterUri` | `https://<cloud-cluster>.<region>.kusto.windows.net/` | `http://localhost:8082` |
| `dataSources[0].database`   | `Hub`                                                 | `Hub` (unchanged)       |

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

## ADX web UI dashboard import

> ℹ️ **`localhost` is not blocked as mixed content, but Edge/Chrome will ask permission once.**
>
> `dataexplorer.azure.com` is served over HTTPS, and `http://localhost` (and `127.0.0.1`) is a
> **potentially trustworthy origin** under the W3C Secure Contexts spec, so Chromium-based
> browsers (**Microsoft Edge, Google Chrome**) do _not_ apply mixed-content blocking to it.
> However, current Edge (143+) and Chrome (142+) enforce **Local Network Access (LNA)**: the
> first time the page reaches `http://localhost:8082` the browser shows a **"Local Network
> Access" permission prompt** — click **Allow** and the connection proceeds for the session.
> Use Edge or Chrome for this path. Safari is stricter; if it refuses the connection, use the
> [ngrok workaround](#if-the-browser-blocks-the-connection).
>
> The emulator also returns the CORS headers the web UI requires (measured — see
> [UAT findings](#uat-findings-measured) below), so once you allow local-network access the
> cross-origin queries from `dataexplorer.azure.com` to the emulator are permitted.

### UAT findings (measured)

Measured against the running emulator (`http://localhost:8082`, Hub DB populated with the
sample dataset):

| Check                                                                                   | Result                                                                                                                                                                                                                                                                                                                                                                                         |
| --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CORS preflight (`OPTIONS`, `Origin: https://dataexplorer.azure.com`)                    | ✅ `204` with `Access-Control-Allow-Origin: https://dataexplorer.azure.com`, `Access-Control-Allow-Methods: POST`, `Access-Control-Allow-Headers: content-type,x-ms-client-version,authorization`                                                                                                                                                                                              |
| Actual query (`POST /v1/rest/query`, same `Origin`)                                     | ✅ `200` with `Access-Control-Allow-Origin: https://dataexplorer.azure.com`                                                                                                                                                                                                                                                                                                                    |
| Real tile queries return renderable data via the CORS path                              | ✅ Monthly trend (15 months), top services (bar), Prices (table) all return rows                                                                                                                                                                                                                                                                                                               |
| `dashboard.json` import schema                                                          | ✅ Official ADX dashboard schema **v60**, single `manual-kusto` data source → `http://localhost:8082` / `Hub`                                                                                                                                                                                                                                                                                  |
| `dashboard.json` referential integrity                                                  | ✅ 135 tiles / 87 queries / 6 base queries / 12 pages, **0 dangling references** → imports cleanly                                                                                                                                                                                                                                                                                             |
| Private Network Access (PNA) preflight (`Access-Control-Request-Private-Network: true`) | ⚠️ Emulator does **not** return `Access-Control-Allow-Private-Network: true`. Current Edge 143+/Chrome 142+ enforce **Local Network Access (LNA)** and show a one-time **permission prompt** for the public→localhost call — click **Allow** to proceed. Locked-down/enterprise-policy builds that suppress or deny the prompt need the [LNA fallback](#if-the-browser-blocks-the-connection). |

The protocol path is proven server-side: standard CORS is allowed, `localhost` is exempt from
mixed-content blocking in Edge/Chrome, and the dashboard file imports cleanly. The two
remaining browser-side steps are (a) the interactive Azure (AAD) sign-in and (b) clicking
**Allow** on the one-time Local Network Access prompt — both handled in the steps below.

### 1. Connect the ADX web UI to the emulator

1. Open **https://dataexplorer.azure.com** in **Microsoft Edge or Google Chrome** (not Safari).
2. Sign in with your Azure account (the web UI itself requires AAD; the emulator cluster does not).
3. Click **+ Add cluster** (left sidebar).
4. Enter the connection URI: `http://localhost:8082`
5. Authentication: select **Anonymous** (the emulator runs no-auth HTTP).
6. Click **Add**. If Edge/Chrome shows a **"Local Network Access"** permission prompt
   (a site wants to access your local network), click **Allow**.

If the cluster appears in the sidebar with `Hub` and `Ingestion` databases, the connection
succeeded and you can proceed. If the connection is refused, see
[if the browser blocks the connection](#if-the-browser-blocks-the-connection)
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

## If the browser blocks the connection

Two browser-side mechanisms can refuse the `https://dataexplorer.azure.com → http://localhost:8082`
call. They are independent — try the lighter fix first.

### Option A — Local Network Access (LNA) prompt, Chromium

Current Edge (143+) and Chrome (142+) gate public→`localhost` requests behind a **Local
Network Access permission prompt**. In the normal case you simply click **Allow** when the
prompt appears (see step 1) and the connection works — no server header or flag needed.

If your environment **suppresses or auto-denies** the prompt (enterprise policy, or a build
where you previously clicked _Block_), relax the check for local UAT by launching the browser
with LNA/PNA enforcement disabled:

```bash
# Edge (quit Edge first), local UAT only:
open -na "Microsoft Edge" --args --disable-features=LocalNetworkAccessChecks,PrivateNetworkAccessRespectPreflightResults

# Chrome equivalent:
open -na "Google Chrome" --args --disable-features=LocalNetworkAccessChecks,PrivateNetworkAccessRespectPreflightResults
```

You can also re-allow the site via the page-info (lock/info icon) → site permissions, or reset
its Local Network Access permission. Re-enable normal enforcement after testing.

### Option B — expose the emulator over HTTPS with ngrok

If you'd rather not change browser flags (or you're on Safari), tunnel the emulator behind
HTTPS using [ngrok](https://ngrok.com):

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

| Claim                                                                         | Status                                                                                                                                                                                                                                            |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dashboard.json` is valid JSON                                                | ✅ Verified (Python `json.load` round-trip)                                                                                                                                                                                                       |
| `dataSources[0].clusterUri` → `http://localhost:8082`                         | ✅ Verified in file                                                                                                                                                                                                                               |
| `dataSources[0].database` = `Hub`                                             | ✅ Verified in file                                                                                                                                                                                                                               |
| Hub DB has `Costs_v1_2`, `Prices_v1_2`, etc.                                  | ✅ Verified via `.show functions` on running emulator                                                                                                                                                                                             |
| No upstream cluster names, billing IDs, or absolute paths in dashboard        | ✅ Verified                                                                                                                                                                                                                                       |
| `ftk query` / `ftk run` against Hub DB                                        | ✅ Works (HTTP REST, no browser)                                                                                                                                                                                                                  |
| Browser can add `http://localhost:8082` from `https://dataexplorer.azure.com` | ✅ **CORS allowed** (emulator returns `Access-Control-Allow-Origin: https://dataexplorer.azure.com`); `localhost` is exempt from mixed-content blocking. Edge 143+/Chrome 142+ show a one-time **Local Network Access** prompt — click **Allow**. |
| Dashboard tiles render data after import                                      | ⚠️ **Visual render pending** — protocol path proven (tile queries return data via CORS); requires the interactive browser import + AAD sign-in + the LNA **Allow** click to confirm on screen                                                     |

---

## Ingestion vs Hub databases

The emulator runs two databases:

- **`Ingestion`** — raw, transform, and final staging tables used during ingestion. Not
  intended as a query surface.
- **`Hub`** — view functions (`Costs_v1_2`, etc.) that join and normalize the ingested data.
  This is the correct database for the dashboard.

The dashboard's data source is already set to `Hub`.
