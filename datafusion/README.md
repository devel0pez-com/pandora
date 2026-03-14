# datafusion

Nix dev shell for working with [Apache DataFusion](https://github.com/apache/datafusion) from upstream main.

## Quick start

```bash
cd pandora/datafusion
nix develop
df-fetch                   # clone apache/datafusion main
cd datafusion              # enter source tree
df-build                   # build DataFusion (release)
df-cli                     # interactive SQL shell
```

## Available commands

| Command          | Description                                          |
|------------------|------------------------------------------------------|
| `df-fetch`       | Clone or update apache/datafusion (main)              |
| `df-build`       | Build DataFusion (release)                            |
| `df-build-debug` | Build DataFusion (debug, faster compile)              |
| `df-test`        | Run DataFusion tests                                  |
| `df-cli`         | Launch DataFusion CLI (interactive SQL shell)          |
| `df-bench`       | Run DataFusion benchmarks                             |
| `df-example`     | Run a DataFusion example (e.g. `df-example simple_udaf`) |

## Structure

```
datafusion/
  flake.nix          # nix dev shell
  .gitignore         # ignores datafusion/
  README.md          # this file
  examples/          # custom examples
  datafusion/        # (gitignored) upstream main clone
```
