{
  description = "PySpark 4.x dev environment (Python 3.13 + JDK 17 + ptpython)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # PySpark 4.1.x is the version tracked by nixpkgs-unstable for python313.
        # No override needed — the native package is already on the latest stable 4.x.
        pythonEnv = pkgs.python313.withPackages (ps: with ps; [
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
            echo "PySpark $(python -c 'import pyspark; print(pyspark.__version__)') ready"
            echo "Run 'pyspark' or 'ptpython'."
          '';
        };
      });
}
