{
  description = "PySpark 3.5 dev environment (Python 3.13 + JDK 17 + ptpython)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Pin pyspark to the latest 3.5.x release.
        # Bump `pysparkVersion`, clear `pysparkHash` to `lib.fakeHash`, run
        # `nix develop` once, copy the `got:` hash from the error message.
        pysparkVersion = "3.5.8";
        pysparkHash = "sha256-VMygdnshtA45U60dMPhgHFOr+cvadjZTKJzc/KxSMTw=";

        python = pkgs.python313.override {
          packageOverrides = _: pyprev: {
            pyspark = pyprev.pyspark.overridePythonAttrs (_: rec {
              version = pysparkVersion;
              src = pyprev.fetchPypi {
                pname = "pyspark";
                inherit version;
                hash = pysparkHash;
              };
            });
          };
        };

        pythonEnv = python.withPackages (ps: with ps; [
          pyspark
          ptpython
          pandas
          pyarrow
        ]);
      in {
        devShells.default = pkgs.mkShell {
          packages = [ pythonEnv pkgs.jdk17 ];
          shellHook = ''
            export JAVA_HOME=${pkgs.jdk17.home}
            export PATH=$JAVA_HOME/bin:$PATH
            # Use ptpython as the PySpark driver REPL (so `pyspark` launches
            # into ptpython with SparkSession pre-imported).
            export PYSPARK_DRIVER_PYTHON=ptpython
            echo "PySpark $(python -c 'import pyspark; print(pyspark.__version__)') ready"
            echo "Run 'pyspark' (uses ptpython) or 'ptpython' (plain)."
          '';
        };
      });
}
