# ftklocal performance and limits

Measured on **MEM_LIMIT=16g**, **amd64 on Rosetta** (Apple Silicon / Docker Desktop), using
the Kustainer Linux image (`mcr.microsoft.com/azuredataexplorer/kustainer-linux:latest`,
build `1.0.9656.17219`).

Dataset: 15 cost export parts (1,350,561 rows) + 16 price sheet parts (12,735,587 rows),
plus the four open-data lookup tables shipped with the FTK schema (3,293 rows).
Total physical rows at full load: **28,175,589** across Costs_raw, Costs_final_v1_2,
Prices_raw, Prices_final_v1_2, and open-data tables.

---

## Measurement method

All memory figures are read from **cgroup v2** files inside the container:

- `memory.max` — hard limit (confirms MEM_LIMIT setting)
- `memory.current` — total container memory (anonymous + page cache)
- `memory.stat → anon` — **non-reclaimable anonymous working set** (the number that
  matters for headroom: kernel page cache is reclaimable under pressure, but `anon` is not)
- `memory.peak` — **cumulative** high-water mark since container creation; the kernel
  rejected `echo 0 > /sys/fs/cgroup/memory.peak` (read-only filesystem in this
  environment), so memory.peak is cumulative across all stages
- `memory.events → oom / oom_kill` — OOM event counters; these reset when the container
  restarts

Intermediate stages (3a–3c) are read from a 3-second-interval poll loop (`mem_poll.log`)
started before the ingest and stopped afterwards. Stages 1, 2, 3d, and 4 are point-in-time
reads via `docker exec kustainer`. The OOM peak (stage 5) is from a separate 2-second poll
started just before the OOM attempt.

---

## Measurement table

| Stage                                             | Total rows in engine | anon (GiB) | anon % of 16 g | memory.peak (GiB) | OOM events |
| ------------------------------------------------- | -------------------- | ---------- | -------------- | ----------------- | ---------- |
| 1. Empty engine (just started, no data)           | 0                    | 0.49       | 3.1 %          | 0.51              | —          |
| 2. Schema + open-data loaded (`load-ftk-kql`)     | 3,293                | 0.66       | 4.1 %          | 0.68              | —          |
| 3a. After Costs_raw ingested (15 parts)           | 1,353,854            | 1.51 ¹     | 9.5 %          | 2.13 ¹            | —          |
| 3b. After all raw ingested, no finals yet         | 14,089,441           | 1.99 ¹     | 12.4 %         | 3.98 ¹            | —          |
| 3c. After Costs_final_v1_2 backfill (single-pass) | 15,440,002           | 3.88 ¹     | 24.2 %         | 6.89 ¹            | —          |
| 3d. After full ingest — **hot** working set       | 28,175,589           | **13.99**  | **87.4 %**     | **15.03**         | 0          |
| 4. After representative query workload            | 28,175,589           | 13.95      | 87.2 %         | 15.03             | 0          |
| 5. Single-pass OOM attempt (Prices, 12.7 M rows)  | 28,175,589           | 14.74 ¹    | 92.1 %         | **15.12 ¹**       | **crash**  |
| 6. Cold loaded — post-restart, data on disk ²     | 28,175,589           | **1.12**   | **7.0 %**      | 1.58 ²            | 0          |

**Notes:**

- Stages 1, 2, 3d, 4 are exact point-in-time measurements. Stages 3a–3c and 5 are read
  from the 2–3 s poll loop and should be treated as approximate (±0.1 GiB).
- memory.peak is cumulative (not per-stage); the value in each row is the cumulative
  high-water mark up to that stage. Stage 6's memory.peak is a **post-restart** reading
  (cgroup reset on container restart, so it reflects only the cold-start HWM, not the
  earlier ingest peak).
- After the OOM crash the container restarted automatically (`restart: unless-stopped`).
  The cgroup counters (oom / oom_kill) reset on restart; they read 0 in both the pre-OOM
  measurement and after recovery. The crash is confirmed by the Kustainer log entry
  (`Killed`, SIGKILL) and the abrupt memory.current drop observed in the poll log.
- ² Stage 6 was read after the OOM-triggered restart. The full dataset (1,350,561 Costs +
  12,735,587 Prices rows) is intact on disk and returns correct counts; extents are not
  yet materialized in memory (lazy-load). This is also the expected state after a planned
  `make down && make up` cycle.

---

## Row-count → memory curve

The table above shows how the non-reclaimable working set grows as data is loaded:

```
Stage                              Total rows    anon GiB
---------------------------------------------------------
Empty engine                               0       0.49
Schema + open data                     3,293       0.66
After Costs_raw ingest             1,353,854       1.51
After all raw (no finals)         14,089,441       1.99
After Costs_final backfill        15,440,002       3.88
After full ingest — hot           28,175,589      13.99
Cold loaded (post-restart)        28,175,589       1.12
```

Key observations:

1. **Raw ingestion is memory-cheap.** Loading 14 M raw rows (Costs + Prices parquet)
   raises anon only from 0.66 GiB to ~2.0 GiB. The engine writes extents to disk; the
   ingest buffers are transient.

2. **The transform backfill is memory-expensive.** Single-pass Costs_final (1.35 M rows,
   53.2 s) peaks at 6.89 GiB (43 % of 16 g) but settles at 3.88 GiB. The difference
   (~3 GiB) is intermediate query-execution scratch space that is released after the
   `.set-or-append` completes.

3. **Prices_final dominates the hot working set.** Loading 12.7 M transformed Prices rows
   raises anon from 3.88 GiB to 13.99 GiB — a 10 GiB jump. Immediately after the
   ingest+transform pipeline the engine holds ≈87.4 % of MEM_LIMIT in non-reclaimable
   memory. This is a **hot** state: extents materialized by the transform. After a restart
   the same data idles at **1.12 GiB (7 %)** — extents remain on disk until queried.

4. **Queries are nearly free in memory.** Five representative queries (Costs by service,
   monthly trend, Prices count, Prices by service family) changed anon by < 0.1 GiB and
   did not raise memory.peak above the ingest high-water mark.

---

## Ingest wall-clock

| Phase                                                            | Duration               |
| ---------------------------------------------------------------- | ---------------------- |
| Raw file ingest (31 parquet parts, 991 MB)                       | 419.6 s (7.0 min)      |
| Costs_final_v1_2 single-pass backfill (1.35 M rows)              | 53.2 s                 |
| Prices_final_v1_2 chunked backfill (12.7 M rows, 21 extents × 1) | ~340 s (~5.7 min)      |
| **Full `ingest.ps1` wall-clock (raw + backfill)**                | **841.6 s (14.0 min)** |

The raw file ingest time is dominated by the 16 price sheet parts (247 s total, ~15 s each
for the large monthly files). The 15 cost parts take only 76.5 s.

---

## Chunked-backfill peak and single-pass OOM

### Why auto-chunking exists

The 2,000,000-row threshold in `BACKFILL_CHUNK_ROW_THRESHOLD` separates two regimes:

| Mode                                         | Prices (12.7 M rows)        | Peak anon              | memory.peak   | Outcome      |
| -------------------------------------------- | --------------------------- | ---------------------- | ------------- | ------------ |
| **Chunked (default, ≤ 1 extent/batch)**      | 21 chunks × ~600 K avg rows | **14.71 GiB**          | **15.03 GiB** | ✅ completes |
| **Single-pass** (threshold raised to bypass) | all 12.7 M rows at once     | **14.74 GiB at crash** | **15.12 GiB** | ❌ OOM crash |

### Chunked-backfill peak detail

The 2-second poll loop captured anon climbing from 3.88 GiB (start of Prices chunked) to
14.71 GiB during the later large-extent chunks (~1 M rows each). The cumulative
memory.peak reached 15.03 GiB (93.9 % of 16 g) during this phase.

The individual chunks do NOT add up linearly in memory because the engine releases
completed-extent memory between chunks. Each chunk's peak is dominated by:

- the pre-existing working set (~13–14 GiB from previously loaded extents), plus
- the in-flight transform output for the current chunk (~0.5–1 GiB per ~1 M row chunk).

### Single-pass OOM ceiling (stage 5)

With `BACKFILL_CHUNK_ROW_THRESHOLD` bypassed, the engine attempted to materialise all
12.7 M transformed Prices rows at once:

- Anon reached **14.74 GiB** in the 2 s before the crash.
- memory.peak rose from 15.03 GiB → **15.12 GiB** (94.5 % of 16 g) immediately before
  the crash was captured by the poll loop.
- The engine process received **SIGKILL** (confirmed by Kustainer log entry) and exited.
  Docker's `OOMKilled` flag was `false` — this is Kusto's internal memory-pressure
  self-termination, not a kernel cgroup hard-limit breach.
- The container restarted automatically. cgroup counters (oom / oom_kill) reset to 0.
- Recovery: databases reattached from the persistent `kustainer-data/` volume; engine
  became healthy within ~10 s.

The gap between chunked peak (15.03 GiB) and single-pass crash (15.12 GiB) is only
~0.09 GiB — there is essentially **no safe headroom** for single-pass Prices at 16 g and
this dataset size. The auto-chunking threshold exists precisely because of this margin.

---

## Operating states and limits

These tiers answer the question **"when do we approach 16 GiB?"**

A freshly-loaded or restarted engine idles at ~7 % of MEM_LIMIT (extents on disk, lazy
materialization). You only approach the ceiling **during** the ingest+transform pipeline
for a dataset of this size. The hot working set (~87 %) is a sustained post-ingest state
that persists until the engine restarts or memory is reclaimed.

All tiers are calibrated to `MEM_LIMIT=16g` and this specific dataset. They scale with
both `MEM_LIMIT` and dataset size. Each cell identifies the metric and source stage.

| State               | Condition                                                                          | Metric (source stage)                                           | % of MEM_LIMIT                    | Notes                                                                          |
| ------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------ |
| **Cold loaded**     | Post-restart or fresh `make up`, before heavy queries                              | anon: **1.12 GiB** (stage 6)                                    | 7.0 %                             | Floor; extents on disk, not yet materialized. Data intact and queryable.       |
| **Hot post-ingest** | Immediately after `make ingest` completes; extents fully materialized by transform | anon: **13.99 GiB** (stage 3d)                                  | 87.4 %                            | Sustained until restart or OS reclaim; this is NOT the steady-state floor      |
| **Degraded**        | Prices chunked-backfill high-water (during `make ingest`)                          | memory.peak: **15.03 GiB** (stage 3d cumulative HWM)            | 93.9 %                            | Within 0.09 GiB of single-pass crash; system completes but headroom is minimal |
| **Ceiling**         | Single-pass Prices transform attempt                                               | anon: ~14.74 GiB / memory.peak: **15.12 GiB** → crash (stage 5) | 92.1 % anon / 94.5 % peak → crash | Kusto self-terminates (SIGKILL); container restarts automatically              |

### When to raise MEM_LIMIT

- If your Prices dataset significantly exceeds 12.7 M rows, raise `MEM_LIMIT` before
  running `make ingest`. Each additional million Prices rows adds roughly 0.5–1 GiB to the
  idle working set (extrapolated from the Prices_final contribution observed here).
- `MEM_LIMIT=8g` is sufficient for Costs-only workflows (Costs_final peaks at 6.89 GiB
  during backfill, then settles to ~3.9 GiB idle). It is **not sufficient** for
  Prices at these dataset sizes.
- After raising `MEM_LIMIT`, update `BACKFILL_CHUNK_ROW_THRESHOLD` accordingly and
  re-run the single-pass OOM test before relying on single-pass for larger row counts.

---

## Environment

| Setting                | Value                                                           |
| ---------------------- | --------------------------------------------------------------- |
| MEM_LIMIT              | 16g (17,179,869,184 bytes; confirmed via `memory.max`)          |
| Kustainer image        | `mcr.microsoft.com/azuredataexplorer/kustainer-linux:latest`    |
| Kustainer build        | `1.0.9656.17219` (2026-06-09)                                   |
| Platform               | linux/amd64 on Rosetta (Apple Silicon, Docker Desktop)          |
| Host OS                | macOS (Apple Silicon, M-series)                                 |
| cgroup version         | v2 (confirmed)                                                  |
| memory.peak reset      | Not possible — kernel rejected write (read-only filesystem)     |
| memory.peak semantics  | Cumulative since container start; NOT resettable between stages |
| Poll interval (ingest) | 3 s                                                             |
| Poll interval (OOM)    | 2 s                                                             |

---

## Cleanliness

No absolute host paths, billing scope IDs, storage account names, or real cluster URIs
appear in this file. Dataset size is described in row counts only.
