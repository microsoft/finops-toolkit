# Install and run ftklocal on Windows

This is the primary supported platform. The Kustainer image is `linux/amd64`, which runs
**natively** on Windows x64 (via the WSL 2 backend) with no emulation — so ingest and
transform are faster here than on Apple Silicon. The numbers in
[performance.md](performance.md) were measured under Apple-Silicon emulation and are a
conservative floor for Windows.

Everything below runs from a normal **PowerShell 7** prompt. You do **not** need `make`,
WSL shell access, or any Unix tooling — `docker compose` and the `.ps1` scripts are the
whole surface.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| **Docker Desktop ≥ 4.0** with the **WSL 2 backend** | Settings → General → "Use the WSL 2 based engine". Compose v2 ships with it (`docker compose`, not legacy `docker-compose`). |
| **PowerShell 7+** (`pwsh`) | **Windows PowerShell 5.1 will not work** — the scripts use 7-only syntax. Install with `winget install Microsoft.PowerShell`, then use the `pwsh` command (not `powershell`). |
| **Git** | `winget install Git.Git`, to clone the repository. |
| **~16 GiB RAM available to Docker** | The full Prices transform needs it. Costs-only datasets work at 8 GiB. See [memory tuning](#tune-wsl-2-memory) below — on Windows the limit is governed by both the container `MEM_LIMIT` **and** WSL 2's own memory cap. |
| **Host port 8082 free** | Configurable via `HOST_PORT` in `.env`. |
| **FOCUS cost exports as Parquet** | Staged under `export/`. See [staging-contract.md](staging-contract.md). |

> **Why PowerShell 7, not the built-in PowerShell?** Windows ships *Windows PowerShell 5.1*
> (`powershell.exe`). ftklocal's scripts use null-coalescing (`??`) and ternary operators
> that only exist in *PowerShell 7+* (`pwsh.exe`). Running them under 5.1 fails with parser
> errors. Always invoke them with `pwsh`.

---

## Tune WSL 2 memory

Docker Desktop on Windows runs containers inside a WSL 2 virtual machine. Two limits apply:

1. The container limit — `MEM_LIMIT` in `.env` (default `16g`).
2. The WSL 2 VM limit — by default WSL 2 may cap memory below what the container needs.

If the container is killed under load, raise the WSL 2 cap. Create or edit
`%UserProfile%\.wslconfig`:

```ini
[wsl2]
memory=20GB
```

Then, from PowerShell, restart WSL and Docker Desktop:

```powershell
wsl --shutdown
# then relaunch Docker Desktop
```

Give the VM a couple of GiB more than `MEM_LIMIT` so the engine has headroom. See
[performance.md](performance.md) for the measured working-set curve.

---

## Install

```powershell
# 1. Clone the toolkit and move into the template
git clone https://github.com/microsoft/finops-toolkit.git
cd finops-toolkit\src\templates\finops-hub-local

# 2. Create your local config from the template
Copy-Item .env.example .env
```

Edit `.env` to point `EXPORT_DIR` at the folder holding your FOCUS Parquet exports. On
Windows, use a forward-slash path or an absolute drive path — both work with Docker
Desktop's bind mounts:

```ini
# .env  (examples — pick one)
EXPORT_DIR=./export
EXPORT_DIR=D:/cost-exports
HOST_PORT=8082
MEM_LIMIT=16g
```

> Keep forward slashes in `EXPORT_DIR`. A backslash path like `D:\exports` can be
> mis-parsed by Compose variable expansion; `D:/exports` (or `C:/finops/exports`) is safe.

---

## Run

```powershell
# 3. Start the emulator and block until it reports healthy
docker compose up -d --wait

# 4. Create the Ingestion + Hub databases, load the FTK KQL and open data (idempotent)
pwsh scripts\load-ftk-kql.ps1

# 5. Bulk-ingest every Parquet export under export\ (idempotent; chunks large tables)
pwsh scripts\ingest.ps1

# 6. Query your FOCUS data (Hub database, view functions)
pwsh scripts\ftk.ps1 query "Costs() | summarize TotalCost = sum(EffectiveCost) by ServiceName | top 10 by TotalCost"
```

`docker compose up -d --wait` uses the container's built-in healthcheck and returns only
once the engine answers queries — it is the cross-platform equivalent of `make up`.

Useful follow-ups:

```powershell
pwsh scripts\ftk.ps1 list                       # list the reusable query catalog
pwsh scripts\ftk.ps1 run <query-name>           # run a named catalog query
pwsh scripts\ingest.ps1 -DryRun                 # preview what would be ingested
pwsh scripts\run-parity-checks.ps1              # validate transform parity
```

---

## Stop, reset, and update

```powershell
# Stop the emulator, keep the data
docker compose down

# Full reset (destructive): remove the container and all ingested data
docker compose down -v
Remove-Item -Recurse -Force .\kustainer-data    # if a bind-mounted data dir remains

# Update to a newer toolkit version
git pull
docker compose up -d --wait
pwsh scripts\load-ftk-kql.ps1                    # re-applies schema (idempotent)
```

---

## Troubleshooting (Windows-specific)

| Symptom | Fix |
|---------|-----|
| `pwsh : The term 'pwsh' is not recognized` | PowerShell 7 isn't installed or isn't on `PATH`. `winget install Microsoft.PowerShell`, then open a new terminal. |
| Parser errors like `Unexpected token '??'` | You're running under Windows PowerShell 5.1. Use `pwsh`, not `powershell`. |
| `running scripts is disabled on this system` | Invoking as `pwsh scripts\x.ps1 <args>` normally bypasses this. If you dot-source instead, set `Set-ExecutionPolicy -Scope Process RemoteSigned` for the session. |
| `docker compose` not found | Update Docker Desktop (Compose v2 is bundled). Don't use the legacy `docker-compose`. |
| Container exits / killed under the Prices transform | WSL 2 memory cap too low — see [Tune WSL 2 memory](#tune-wsl-2-memory). The ingest already chunks large tables; raising the VM cap removes the ceiling. |
| Port 8082 already in use | Set a different `HOST_PORT` in `.env`, then `docker compose up -d --wait`. |
| `Ingestion`/`Hub` DB missing after start | Run `pwsh scripts\load-ftk-kql.ps1`. If it persists, full-reset (above) and reload. |
| Tiles/queries return 0 rows | You haven't ingested yet — run `pwsh scripts\ingest.ps1`. |

For the ADX web-UI dashboard on Windows, see [dashboard.md](dashboard.md) — Edge and Chrome
are the supported browsers and will prompt once for **Local Network Access** (click
**Allow**).
