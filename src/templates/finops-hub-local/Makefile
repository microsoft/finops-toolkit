# ftklocal — Makefile
#
# Targets:
#   make up                  Bring Kustainer up and block until healthcheck passes.
#   make down                Stop and remove the container (keeps the data volume).
#   make nuke                Down + remove kustainer-data/ (destructive; full reset).
#   make logs                Tail Kustainer logs.
#   make kql QUERY='...'     Run a one-shot KQL query (default DB: Hub; override e.g. KQL_DB=Ingestion).
#
# DB topology:
#   Ingestion  raw tables (Costs_raw, Prices_raw), transform functions, final tables,
#              open-data lookups, and Ingest_Manifest.
#              Used by: ingest, ingest-status, checks 1–8 + 11, parity (base DB).
#   Hub        view functions (Costs_v1_2, Prices_v1_2, Costs, Prices, etc.) that
#              cross-reference database('Ingestion').*.
#              Used by: ftk query/run/schema, parity checks 9–10, kql (default).
#
# Notes:
#   - The Kustainer HTTP endpoint is on host port $(HOST_PORT) (default 8082).
#     Port 8080 is intentionally avoided — that belongs to maenifold.
#   - `kql` talks directly to Kustainer's REST API. Kustainer is NOT an MCP
#     server, so a plain curl is the right tool here.

SHELL := /bin/bash

# Load .env if present so HOST_PORT / MEM_LIMIT / EXPORT_DIR are visible to
# both `docker compose` and the recipes below.
ifneq (,$(wildcard ./.env))
include .env
export
endif

HOST_PORT  ?= 8082
# KQL_DB: default database for ad-hoc `make kql` queries.
# Defaults to Hub so view functions (Costs_v1_2, etc.) work without an override.
# Override for raw-table inspection: make kql KQL_DB=Ingestion QUERY='Costs_raw | count'
KQL_DB     ?= Hub
# PARITY_DB: base database passed to run-parity-checks.ps1 --db.
# Checks 1-8/11 run against PARITY_DB (Ingestion); the script internally forces
# checks 9/10 to Hub regardless of this value.
PARITY_DB  ?= Ingestion
COMPOSE    ?= docker compose

.PHONY: up down nuke logs kql ftk ftk-list wait-healthy load-ftk-kql ingest ingest-status chunked-prices-backfill parity help

help:
	@echo "Targets:"
	@echo "  up                        Bring Kustainer up and block until healthy."
	@echo "  down                      Stop the container (keeps data volume)."
	@echo "  nuke                      Destructive full reset (drops kustainer-data/)."
	@echo "  logs                      Tail Kustainer logs."
	@echo "  kql QUERY='...'           One-shot KQL against Hub (override: KQL_DB=Ingestion)."
	@echo "  load-ftk-kql              Load FTK analytics KQL + open-data lookups."
	@echo "  ingest                    Bulk-ingest ALL parquet under export/."
	@echo "  ingest SCOPE=<scope>      Ingest only one scope."
	@echo "  ingest SCOPE=<scope> PERIOD=20260501-20260531"
	@echo "                            Filter scope + period."
	@echo "  ingest-status             Show Ingest_Manifest summary."
	@echo "  parity                    Run T-1.4 parity check suite."
	@echo "  chunked-prices-backfill   Recovery path when Prices_transform OOMs."
up:
	$(COMPOSE) up -d
	@$(MAKE) --no-print-directory wait-healthy

wait-healthy:
	@echo "Waiting for kustainer to become healthy (up to 90s)..."
	@for i in $$(seq 1 90); do \
	  status=$$(docker inspect -f '{{.State.Health.Status}}' kustainer 2>/dev/null || echo "missing"); \
	  if [ "$$status" = "healthy" ]; then \
	    echo "kustainer is healthy."; \
	    exit 0; \
	  fi; \
	  if [ "$$status" = "missing" ]; then \
	    echo "kustainer container not found yet..."; \
	  fi; \
	  sleep 1; \
	done; \
	echo "ERROR: kustainer did not become healthy in 90s. Last status: $$status" >&2; \
	docker inspect -f '{{json .State.Health}}' kustainer 2>/dev/null | head -c 2000 >&2; \
	exit 1

down:
	$(COMPOSE) down

nuke:
	$(COMPOSE) down -v
	rm -rf kustainer-data

logs:
	$(COMPOSE) logs -f kustainer

# Run a one-shot KQL query against $(KQL_DB) (default: Hub). Override on the command line:
#   make kql QUERY='.show tables'
#   make kql QUERY='Costs_v1_2 | count'           (Hub — default)
#   make kql KQL_DB=Ingestion QUERY='Costs_raw | count'
kql:
	@if [ -z "$(QUERY)" ]; then \
	  echo "usage: make kql QUERY='<kql>'" >&2; exit 2; \
	fi
	@QUERY="$(QUERY)" DB="$(KQL_DB)" pwsh -NoProfile -Command '@{ db = $$env:DB; csl = $$env:QUERY } | ConvertTo-Json -Compress' | \
	  curl -sS --fail-with-body --max-time 60 \
	    -H 'Content-Type: application/json' \
	    -d @- \
	    "http://localhost:$(HOST_PORT)/v1/rest/$$(echo '$(QUERY)' | grep -q '^\.' && echo mgmt || echo query)"
	@echo

# ftk CLI passthrough: `make ftk ARGS='run savings-summary-report'`.
# For everyday use call `pwsh scripts/ftk.ps1 ...` directly.
ftk:
	@pwsh scripts/ftk.ps1 $(ARGS)

# List the FinOps Toolkit catalog queries discoverable locally.
ftk-list:
	@pwsh scripts/ftk.ps1 list

# Load the FTK analytics KQL into the two-DB topology (Ingestion + Hub).
# Reads src/templates/finops-hub/.build.config combineKql bundles and
# concatenates the listed .kql files in dependency order. Idempotent.
load-ftk-kql:
	@pwsh scripts/load-ftk-kql.ps1

# Bulk-ingest parquet under ./export/ into Costs_raw / Prices_raw. Picks the
# latest run-uuid per (scope, type, period) by manifest.runInfo.submittedTime,
# enforces OverwritePreviousReport semantics (drops superseded extents by
# tag), and is idempotent via the Ingest_Manifest table.
#   make ingest
#   make ingest SCOPE=<scope>
#   make ingest SCOPE=<scope> PERIOD=20260501-20260531
INGEST_FILTERS :=
ifneq ($(SCOPE),)
INGEST_FILTERS += --scope $(SCOPE)
endif
ifneq ($(PERIOD),)
INGEST_FILTERS += --period $(PERIOD)
endif
ingest:
	@pwsh scripts/ingest.ps1 $(INGEST_FILTERS)

# Quick summary of Ingest_Manifest: files + rows per (scope, export_type).
# Targets Ingestion DB explicitly (Ingest_Manifest lives there, not in Hub).
ingest-status:
	@$(MAKE) --no-print-directory kql KQL_DB=Ingestion \
	  QUERY="Ingest_Manifest | summarize files=count(), rows=sum(rows_ingested) by scope, export_type | order by scope asc, export_type asc"

# Run the T-1.4 parity check suite. Reads tests/parity-checks.kql, executes
# each numbered check against Kustainer's query endpoint, evaluates the EVAL
# rule, and prints a pass/fail report. Exit code 0 only if all checks pass.
parity:
	@pwsh scripts/run-parity-checks.ps1 --endpoint http://localhost:$(HOST_PORT) --db $(PARITY_DB)

# Recovery path for the Prices_transform_v1_2() backfill when the single-pass
# .set-or-append OOMs. Processes Prices_raw one source extent at a time
# (bounded memory). Use after `make ingest` if Prices_final_v1_2 ends up
# partially populated or empty. Wall-clock ~15 min on Apple Silicon.
chunked-prices-backfill:
	@pwsh scripts/chunked-prices-backfill.ps1

# (Customer-specific savings-plan analysis targets removed — see T-3.5.)
