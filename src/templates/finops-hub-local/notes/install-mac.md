# Install and run ftklocal on macOS

macOS is a supported secondary platform. On **Apple Silicon** the Kustainer image
(`linux/amd64`) runs under emulation, so ingest and transform are slower than on Windows
or Intel; the measured numbers in [performance.md](performance.md) were taken on Apple
Silicon and represent that emulated path. On **Intel Macs** the image runs natively.

Everything runs from a normal terminal with PowerShell 7 (`pwsh`). The `make` targets are
available on macOS as a convenience, but the `docker compose` + `pwsh` commands below work
identically and are the cross-platform reference.

---

## Prerequisites

| Requirement                         | Notes                                                                                                                                                                      |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Docker Desktop ≥ 4.0**            | Compose v2 is required (`docker compose`, not legacy `docker-compose`).                                                                                                    |
| **Apple Silicon: enable Rosetta**   | Docker Desktop → Settings → General → "Use Rosetta for x86_64/amd64 emulation on Apple Silicon". The Kustainer image is `linux/amd64` only. Intel Macs need nothing extra. |
| **PowerShell 7+** (`pwsh`)          | `brew install --cask powershell`. All tooling is PowerShell; there are no Python dependencies.                                                                             |
| **Git**                             | To clone the repository (`brew install git`, or use the Xcode command-line tools).                                                                                         |
| **~16 GiB RAM available to Docker** | Docker Desktop → Settings → Resources → Memory. The full Prices transform needs it; Costs-only datasets work at 8 GiB. See [Limits](performance.md).                       |
| **Host port 8082 free**             | Configurable via `HOST_PORT` in `.env`.                                                                                                                                    |
| **FOCUS cost exports as Parquet**   | Staged under `export/`. See [staging-contract.md](staging-contract.md).                                                                                                    |

---

## Install

```bash
# 1. Clone the toolkit and move into the template
git clone https://github.com/microsoft/finops-toolkit.git
cd finops-toolkit/src/templates/finops-hub-local

# 2. Create your local config from the template
cp .env.example .env
```

Edit `.env` to point `EXPORT_DIR` at the folder holding your FOCUS Parquet exports:

```ini
# .env
EXPORT_DIR=./export            # or an absolute path, e.g. ~/cost-exports
HOST_PORT=8082
MEM_LIMIT=16g
```

---

## Run

Two equivalent paths — `make` (macOS/Linux convenience) or the cross-platform commands.

### Using make

```bash
make up                 # start the emulator; blocks until healthy
make load-ftk-kql       # create Ingestion + Hub DBs, load FTK KQL + open data
make ingest             # bulk-ingest the Parquet exports under export/
pwsh scripts/ftk.ps1 query "Costs() | summarize TotalCost = sum(EffectiveCost) by ServiceName | top 10 by TotalCost"
```

### Cross-platform (no make)

```bash
docker compose up -d --wait        # start + block until the healthcheck passes
pwsh scripts/load-ftk-kql.ps1
pwsh scripts/ingest.ps1
pwsh scripts/ftk.ps1 query "Costs() | summarize TotalCost = sum(EffectiveCost) by ServiceName | top 10 by TotalCost"
```

Useful follow-ups:

```bash
pwsh scripts/ftk.ps1 list                # list the reusable query catalog
pwsh scripts/ftk.ps1 run <query-name>    # run a named catalog query
make ingest-status                       # summary of what was ingested
make parity                              # validate transform parity
```

---

## Stop, reset, and update

```bash
docker compose down                 # stop, keep data   (or: make down)
make nuke                           # full destructive reset (down -v + remove kustainer-data/)
git pull && docker compose up -d --wait && pwsh scripts/load-ftk-kql.ps1   # update
```

---

## Troubleshooting (macOS-specific)

| Symptom                                       | Fix                                                                                                                                                |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Very slow ingest / transform on Apple Silicon | Expected — `linux/amd64` runs under emulation. Confirm Rosetta is enabled (above). See [performance.md](performance.md) for the measured envelope. |
| Container exits under the Prices transform    | Raise Docker Desktop's memory (Settings → Resources) to ≥ 16 GiB. The ingest already chunks large tables.                                          |
| `pwsh: command not found`                     | `brew install --cask powershell`.                                                                                                                  |
| Rare SIGSEGV crashes under heavy load         | A known Rosetta emulation issue; the container restarts automatically. See the main [README](../README.md) troubleshooting section.                |
| Port 8082 already in use                      | Set a different `HOST_PORT` in `.env`, then bring the stack back up.                                                                               |

For the ADX web-UI dashboard, see [dashboard.md](dashboard.md). Use Edge or Chrome; Safari
is stricter about local connections.
