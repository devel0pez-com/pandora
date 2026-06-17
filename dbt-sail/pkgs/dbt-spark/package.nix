# Upstream-ready: drop this verbatim into
#   nixpkgs/pkgs/development/python-modules/dbt-spark/package.nix
# and add `dbt-spark = callPackage ../development/python-modules/dbt-spark { };`
# to python-packages.nix. Then delete this file and the overlay entry.
#
# Mirrors the existing dbt-* adapters already in nixpkgs (dbt-postgres, etc.):
# pure-Python, hatchling build, optional-dependencies for the connection
# methods, tests disabled (they need a live Spark / Databricks cluster).
{
  lib,
  buildPythonPackage,
  fetchPypi,
  hatchling,
  # core dbt stack (all already in nixpkgs)
  dbt-core,
  dbt-adapters,
  dbt-common,
  sqlparams,
  # optional connection methods
  pyspark,
}:

buildPythonPackage rec {
  pname = "dbt-spark";
  version = "1.10.1";
  pyproject = true;

  src = fetchPypi {
    pname = "dbt_spark"; # PEP 625 normalized sdist name
    inherit version;
    hash = "sha256-/DnVfmvGr8i8dUcr/SX21vv78XjJ5FXpJzAHSCcNGl4=";
  };

  build-system = [ hatchling ];

  dependencies = [
    dbt-core
    dbt-adapters
    dbt-common
    sqlparams
  ];

  # Connection method extras. `session` (the one Sail uses via Spark Connect)
  # only needs pyspark. `pyhive`/`odbc` are intentionally omitted because
  # pyhive/pyodbc are not packaged in nixpkgs yet.
  optional-dependencies = {
    session = [ pyspark ];
  };

  # The adapter's test suite requires a running Spark/Databricks backend.
  doCheck = false;

  pythonImportsCheck = [ "dbt.adapters.spark" ];

  meta = {
    description = "Apache Spark adapter plugin for dbt (data build tool)";
    homepage = "https://github.com/dbt-labs/dbt-spark";
    changelog = "https://github.com/dbt-labs/dbt-spark/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ davidlghellin ];
  };
}
