# pandora

```
          ╔══════════════════════════════════╗
          ║      ✦  P A N D O R A  ✦        ║
          ╠══════════════════════════════════╣
          ║                                  ║
          ║           ███    ███             ║
          ║          ██  █  █  ██            ║
          ║         ██    ██    ██           ║
          ║        ██   ██  ██   ██          ║
          ║       ██  ██  ██  ██  ██         ║
          ║        ██   ██  ██   ██          ║
          ║         ██    ██    ██           ║
          ║          ██  █  █  ██            ║
          ║           ███    ███             ║
          ║                                  ║
          ║      { nix flake toolbox }       ║
          ║                                  ║
          ╠══════════════════════════════════╣
          ║  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
          ║  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
          ╚══════════════════════════════════╝
```

> *Once opened, there's no going back.*

A Nix flake toolbox for Apache data projects. Each subfolder is an independent dev shell.

## Projects

| Folder | Project | Description |
|--------|---------|-------------|
| `datafusion-comet/` | [Apache DataFusion Comet](https://github.com/apache/datafusion-comet) | Spark plugin — accelerates queries with native DataFusion execution |
| `auron/` | [Apache Auron](https://github.com/apache/auron) | Spark & Flink plugin — native vectorized execution via DataFusion |
| `datafusion/` | [Apache DataFusion](https://github.com/apache/datafusion) | Standalone Rust SQL query engine |

## Comet vs Auron

Both are Spark plugins that use Apache DataFusion (Rust) to accelerate query execution. They replace Spark JVM operators with native implementations.

| | Comet | Auron |
|---|---|---|
| **Apache status** | Incubating | Incubating (formerly Blaze) |
| **Approach** | Replaces individual operators (scan, filter, aggregate) | Converts entire stages to native execution |
| **Shuffle** | JVM-based (Comet shuffle manager) | Native Arrow-based shuffle |
| **Flink support** | No | Yes |
| **Pre-built JAR** | Yes (Maven Central) | No (must compile from source) |
| **Spark versions** | 3.4, 3.5 | 3.0 - 4.1 |
| **Spark UI operators** | `CometScan`, `CometHashAggregate`, ... | `NativeParquetScan`, `NativeHashAggregate`, ... |
| **offHeap required** | Yes (`spark.memory.offHeap.enabled=true`) | No |
| **Key config** | `spark.plugins=...CometPlugin` | `spark.sql.extensions=...AuronSparkSessionExtension` |

**When to use Comet**: Quick setup, pre-built JAR available, mature operator coverage.

**When to use Auron**: Broader Spark version support, native shuffle, Flink workloads, more aggressive native conversion.

## Usage

```bash
cd <project-folder>
nix develop
# Each shell provides helper commands (run 'menu' to see them)
```
