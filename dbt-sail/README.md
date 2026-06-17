# dbt-sail

A reproducible **dbt + [Sail](https://github.com/lakehq/sail)** demo, fully on Nix.

dbt is the transformation/test/lineage layer; **Sail is the compute** (a
Spark-compatible engine in Rust). dbt talks to a local Sail server over the
**Spark Connect** protocol — no Spark JVM, no external warehouse, no database
to run. Clone it, `nix develop`, `demo`, done.

It is *not* an orchestrator like Airflow. It demonstrates the modern ELT path
end to end: **raw seeds → staging → marts → data-quality tests → lineage docs**,
all executing on Sail.

```
raw CSV seeds ──► staging (views) ──► marts (tables) ──► tests ──► docs
   customers        stg_customers        fct_orders       unique     lineage
   orders           stg_orders           dim_country      not_null    web
   countries                                              relationships
```

## Quick start

```bash
cd dbt-sail
nix develop          # or `direnv allow`
menu                 # list all helper commands
demo                 # sail-up + dbt build (seed + run + test)
```

Then explore:

```bash
dbt-docs             # lineage graph at http://localhost:8080
sail-down            # stop the Sail server
```

## Helper commands

| Command | What it does |
|---------|--------------|
| `sail-up` / `sail-down` | Start/stop the Sail Spark Connect server (`sc://127.0.0.1:50051`) |
| `dbt-build` | Seed + run + test in one Spark Connect session |
| `dbt-docs` | Generate + serve the lineage docs |
| `demo` | `sail-up` + `dbt-build`, end to end |

`dbt` itself is on the `PATH`, so any `dbt <cmd>` works too. `DBT_PROJECT_DIR`
and `DBT_PROFILES_DIR` are exported, so you can run from anywhere in the shell.

## Why `dbt build` and not separate `dbt seed` / `dbt run`?

Sail's default catalog is **in-memory and per-session** — each Spark Connect
connection gets a fresh, empty catalog
([`MemoryCatalogProvider`](https://github.com/lakehq/sail/blob/main/crates/sail-session/src/catalog.rs)
is constructed per session and is not shared). dbt opens **one connection per
CLI invocation**, so tables created by a standalone `dbt seed` would be invisible
to a later `dbt run` process.

`dbt build` runs seeds → models → tests **in a single process = a single
session**, so everything shares one in-memory catalog and the pipeline is
green end to end. Persisting across separate invocations would need a
persistent catalog (Iceberg REST, Unity, Glue, HMS, …) instead of `memory`.

## How dbt connects to Sail

`sail-up` runs `sail spark server` (the `sail` CLI already in nixpkgs). The dbt
profile uses the **`session`** method and passes `spark.remote` so the pyspark
session becomes a **Spark Connect client** pointed at Sail:

```yaml
# dbt_project/profiles.yml
type: spark
method: session
server_side_parameters:
  spark.remote: "sc://127.0.0.1:50051"
```

This needs `dbt-spark >= 1.9` (earlier versions had to be patched for Connect).
The Spark Connect client is pure gRPC — **no JVM in this shell**.

## Packaging — the point of this folder

`dbt-spark` and `sqlparams` are **not in nixpkgs yet**; `pysail` is in-flight as
[PR #530421](https://github.com/NixOS/nixpkgs/pull/530421). They are packaged
here under [`pkgs/`](./pkgs) **exactly as nixpkgs expects them**, then wired in
through an overlay in [`flake.nix`](./flake.nix):

| File | Status | Port to nixpkgs |
|------|--------|-----------------|
| [`pkgs/dbt-spark/package.nix`](./pkgs/dbt-spark/package.nix) | new | drop into `pkgs/development/python-modules/dbt-spark/` |
| [`pkgs/sqlparams/package.nix`](./pkgs/sqlparams/package.nix) | new | drop into `pkgs/development/python-modules/sqlparams/` |
| [`pkgs/pysail/package.nix`](./pkgs/pysail/package.nix) | vendored from PR #530421 | delete when the PR merges |

The day any of these land in your channel: **delete the file in `pkgs/` and its
line in the overlay** — the flake keeps working, now using the upstream package.

Verify the packaging in isolation:

```bash
nix build .#dbt-spark    # also .#sqlparams, .#pysail, .#default (full env)
```

> Note: `pysail` is a Rust/maturin build; `nix build .#pysail` compiles Sail.
> The demo itself does **not** need `pysail` — it uses the `sail` CLI for the
> server — so you only build it if you want to validate that package.
