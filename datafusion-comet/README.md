# datafusion-comet

Nix dev shell for working with [Apache DataFusion Comet](https://github.com/apache/datafusion-comet) from upstream main.

## Quick start

```bash
cd pandora/datafusion-comet
nix develop
comet-fetch                # clone apache/datafusion-comet main
cd datafusion-comet        # enter source tree
comet-setup                # download Spark 3.5.7
comet-build                # build Comet (native + JVM)
comet-shell                # spark-shell with Comet
```

## Available commands

| Command             | Description                                       |
|---------------------|---------------------------------------------------|
| `comet-fetch`       | Clone or update apache/datafusion-comet (main)     |
| `comet-setup`       | Download Spark 3.5.7                               |
| `comet-build`       | Full build: cargo release + mvnw install           |
| `comet-build-debug` | Quick Rust-only debug build (no JAR)               |
| `comet-shell`       | spark-shell with Comet (UI at localhost:4040)       |
| `comet-sql`         | spark-sql with Comet                               |
| `comet-pyspark`     | pyspark with Comet                                 |
| `comet-submit`      | spark-submit with Comet                            |
| `comet-run`         | Run a .scala or .py file with Comet                |

## Running examples

```bash
# Scala (opens spark-shell and loads the file)
comet-run ../examples/comet-demo.scala

# Python (runs with spark-submit)
comet-run ../examples/comet-demo.py
```

## Structure

```
datafusion-comet/
  flake.nix              # nix dev shell
  .gitignore             # ignores datafusion-comet/ and .spark/
  README.md              # this file
  examples/
    comet-demo.scala     # Scala example for spark-shell
    comet-demo.py        # Python example for pyspark
  datafusion-comet/      # (gitignored) upstream main clone
```
