# auron

Nix dev shell for working with [Apache Auron](https://github.com/apache/auron) from upstream master.

Auron accelerates query processing in Spark and Flink using native vectorized execution via Apache DataFusion (Rust).

## Quick start

```bash
cd pandora/auron
nix develop
auron-fetch                # clone apache/auron master
cd auron                   # enter source tree
auron-setup                # download Spark 3.5.3
auron-build                # full build (native + JVM)
auron-shell                # spark-shell with Auron (UI at localhost:4040)
```

## Available commands

| Command              | Description                                  |
|----------------------|----------------------------------------------|
| `auron-fetch`        | Clone or update apache/auron (master)        |
| `auron-setup`        | Download Spark 3.5.3                         |
| `auron-build`        | Full build (native + JVM)                    |
| `auron-build-native` | Build native engine only (Rust release)      |
| `auron-build-debug`  | Build native engine (debug, faster compile)  |
| `auron-test`         | Run Auron tests (Maven)                      |
| `auron-test-native`  | Run native engine tests (Rust)               |
| `auron-shell`        | spark-shell with Auron (UI at localhost:4040)|
| `auron-sql`          | spark-sql with Auron                         |
| `auron-pyspark`      | pyspark with Auron                           |
| `auron-submit`       | spark-submit with Auron                      |

## Examples

Run examples inside `auron-shell` or `auron-pyspark`:

```bash
# Scala
auron-shell -i ../examples/auron-demo.scala

# Python
auron-pyspark < ../examples/auron-demo.py
```

The examples generate parquet data, perform joins and aggregations, and show the physical plan. Look for `Native*` operators (e.g. `NativeParquetScan`, `NativeHashAggregate`) in the Spark UI at `http://localhost:4040`.

## Structure

```
auron/
  flake.nix        # nix dev shell
  .gitignore       # ignores auron/
  README.md        # this file
  examples/        # custom examples
  auron/           # (gitignored) upstream master clone
```
