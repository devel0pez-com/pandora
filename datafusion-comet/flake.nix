{
  description = "Pandora — DataFusion Comet dev shell (upstream main)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, devshell, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ devshell.overlays.default ];
        };

        sparkVersion = "3.5.7";
        sparkVersionShort = "3.5";
        hadoopProfile = "3";
        scalaVersion = "2.12";
        sparkDirName = "spark-${sparkVersion}-bin-hadoop${hadoopProfile}";
        sparkTgz = "${sparkDirName}.tgz";

        sparkUrl = "https://archive.apache.org/dist/spark/spark-${sparkVersion}/${sparkTgz}";

        # Comet source directory (upstream clone)
        cometSrc = "datafusion-comet";
        cometRepo = "https://github.com/apache/datafusion-comet.git";

        # Shared: resolve Spark + Comet JAR
        sparkCheck = ''
          SPARK_LOCAL="$PWD/.spark/${sparkDirName}"
          if [ ! -d "$SPARK_LOCAL" ]; then
            echo "Spark not found. Run 'comet-setup' first."
            exit 1
          fi
          export SPARK_HOME="$SPARK_LOCAL"

          COMET_JAR=$(ls spark/target/comet-spark-spark*.jar 2>/dev/null | grep -v -E '(sources|javadoc|tests)' | head -1)
          if [ -z "$COMET_JAR" ]; then
            echo "Comet JAR not found. Run 'comet-build' first."
            exit 1
          fi
        '';

        # Shared: Comet Spark configuration flags
        cometConf = builtins.concatStringsSep " " [
          ''--master "local[4]"''
          "--jars \"$COMET_JAR\""
          "--driver-class-path \"$COMET_JAR\""
          "--conf spark.executor.extraClassPath=\"$COMET_JAR\""
          "--conf spark.plugins=org.apache.spark.CometPlugin"
          "--conf spark.shuffle.manager=org.apache.spark.sql.comet.execution.shuffle.CometShuffleManager"
          "--conf spark.comet.enabled=true"
          "--conf spark.comet.exec.enabled=true"
          "--conf spark.comet.exec.shuffle.enabled=true"
          "--conf spark.comet.explainFallback.enabled=true"
          "--conf spark.memory.offHeap.enabled=true"
          "--conf spark.memory.offHeap.size=4g"
        ];

      in
      {
        devShells.default = pkgs.devshell.mkShell {
          name = "pandora-comet";

          packages = with pkgs; [
            # JVM (Spark / Maven)
            jdk17
            maven

            # Rust (native DataFusion engine)
            rustup
            protobuf

            # C/C++ (needed by bindgen, jni, hdfs-sys)
            clang
            llvmPackages.libclang

            # System libs
            openssl
            openssl.dev

            # Build tools
            cmake
            pkg-config
            gnumake
            gnutar
            curl
            git
            python3
          ];

          env = [
            { name = "JAVA_HOME"; value = "${pkgs.jdk17.home}"; }
            { name = "LIBCLANG_PATH"; value = "${pkgs.llvmPackages.libclang.lib}/lib"; }
            { name = "OPENSSL_DIR"; value = "${pkgs.openssl.dev}"; }
            { name = "OPENSSL_LIB_DIR"; value = "${pkgs.openssl.out}/lib"; }
            { name = "OPENSSL_INCLUDE_DIR"; value = "${pkgs.openssl.dev}/include"; }
          ];

          commands = [
            {
              name = "comet-fetch";
              category = "setup";
              help = "Clone or update apache/datafusion-comet (main)";
              command = ''
                set -e
                if [ -d "$PWD/.git" ] && grep -q "datafusion-comet" "$PWD/.git/config" 2>/dev/null; then
                  SRC_DIR="$PWD"
                elif [ -d "$PWD/${cometSrc}/.git" ]; then
                  SRC_DIR="$PWD/${cometSrc}"
                elif [ -d "${cometSrc}/.git" ]; then
                  SRC_DIR="${cometSrc}"
                else
                  echo "Cloning apache/datafusion-comet (main)..."
                  git clone --depth 1 --branch main "${cometRepo}" "${cometSrc}"
                  echo ""
                  echo "Done. Source cloned to ${cometSrc}/"
                  echo "Now cd ${cometSrc} and run: nix develop path:.."
                  exit 0
                fi
                if [ -n "$(git -C "$SRC_DIR" status --porcelain)" ]; then
                  echo "WARNING: local changes detected in $SRC_DIR"
                  echo "Use --force to discard them, or stash/commit first."
                  if [ "''${1:-}" != "--force" ]; then
                    exit 1
                  fi
                fi
                echo "Updating apache/datafusion-comet (main)..."
                git -C "$SRC_DIR" fetch origin main
                git -C "$SRC_DIR" reset --hard origin/main
                echo ""
                echo "Updated to latest main."
              '';
            }
            {
              name = "comet-setup";
              category = "setup";
              help = "Download Spark ${sparkVersion}";
              command = ''
                set -euo pipefail
                SPARK_LOCAL="$PWD/.spark/${sparkDirName}"
                if [ ! -d "$SPARK_LOCAL" ]; then
                  echo "Downloading Spark ${sparkVersion}..."
                  mkdir -p .spark
                  ${pkgs.curl}/bin/curl -fSL "${sparkUrl}" -o ".spark/${sparkTgz}"
                  ${pkgs.gnutar}/bin/tar xzf ".spark/${sparkTgz}" -C .spark/
                  rm -f ".spark/${sparkTgz}"
                  echo "Spark ${sparkVersion} installed in .spark/"
                else
                  echo "Spark ${sparkVersion} already exists in .spark/"
                fi
                echo ""
                echo "SPARK_HOME=$SPARK_LOCAL"
              '';
            }
            {
              name = "comet-build";
              category = "build";
              help = "Full release build (native + JVM)";
              command = ''
                set -e
                echo "=== Building Comet (native + JVM) via make release ==="
                echo "    make release PROFILES=\"-Drat.skip=true\""
                echo ""
                make release PROFILES="-Drat.skip=true"
                echo ""
                COMET_JAR=$(ls spark/target/comet-spark-spark${sparkVersionShort}_${scalaVersion}-*.jar 2>/dev/null | grep -v -E '(sources|javadoc|tests)' | head -1)
                if [ -z "$COMET_JAR" ]; then
                  echo "Error: no Comet JAR found in spark/target/" >&2
                  exit 1
                fi
                echo "JAR ready: $COMET_JAR"
              '';
            }
            {
              name = "comet-build-debug";
              category = "build";
              help = "Quick Rust-only debug build (no JAR)";
              command = ''
                set -e
                echo "=== Building native only (debug) ==="
                cd native && cargo build
                echo "Done. Note: run 'comet-build' for a full release build with JAR."
              '';
            }
            {
              name = "comet-shell";
              category = "spark";
              help = "spark-shell with Comet (UI at localhost:4040)";
              command = ''
                ${sparkCheck}
                echo "Launching spark-shell with Comet..."
                echo "  SPARK_HOME=$SPARK_HOME"
                echo "  COMET_JAR=$COMET_JAR"
                echo "  Spark UI: http://localhost:4040"
                echo ""
                exec $SPARK_HOME/bin/spark-shell ${cometConf} "$@"
              '';
            }
            {
              name = "comet-sql";
              category = "spark";
              help = "spark-sql with Comet";
              command = ''
                ${sparkCheck}
                echo "Launching spark-sql with Comet..."
                echo "  Spark UI: http://localhost:4040"
                echo ""
                exec $SPARK_HOME/bin/spark-sql ${cometConf} "$@"
              '';
            }
            {
              name = "comet-pyspark";
              category = "spark";
              help = "pyspark with Comet";
              command = ''
                ${sparkCheck}
                echo "Launching pyspark with Comet..."
                echo "  Spark UI: http://localhost:4040"
                echo ""
                exec $SPARK_HOME/bin/pyspark ${cometConf} "$@"
              '';
            }
            {
              name = "comet-submit";
              category = "spark";
              help = "spark-submit with Comet";
              command = ''
                ${sparkCheck}
                echo "Launching spark-submit with Comet..."
                echo "  Spark UI: http://localhost:4040"
                echo ""
                exec $SPARK_HOME/bin/spark-submit ${cometConf} --conf spark.comet.exec.shuffle.mode=native "$@"
              '';
            }
            {
              name = "comet-run";
              category = "spark";
              help = "Run a .scala or .py file with Comet";
              command = ''
                ${sparkCheck}
                FILE="$1"
                if [ -z "$FILE" ]; then
                  echo "Usage: comet-run <file.scala|file.py>"
                  exit 1
                fi
                shift
                case "$FILE" in
                  *.scala)
                    echo "Running $FILE in spark-shell..."
                    exec $SPARK_HOME/bin/spark-shell ${cometConf} -I "$FILE" "$@"
                    ;;
                  *.py)
                    echo "Running $FILE with spark-submit..."
                    exec $SPARK_HOME/bin/spark-submit ${cometConf} "$FILE" "$@"
                    ;;
                  *)
                    echo "Unsupported file type. Use .scala or .py"
                    exit 1
                    ;;
                esac
              '';
            }
          ];

          bash = {
            extra = ''
              # Export SPARK_HOME if Spark is already downloaded
              if [ -d "$PWD/${cometSrc}/.spark/${sparkDirName}" ]; then
                export SPARK_HOME="$PWD/${cometSrc}/.spark/${sparkDirName}"
              elif [ -d "$PWD/.spark/${sparkDirName}" ]; then
                export SPARK_HOME="$PWD/.spark/${sparkDirName}"
              fi
            '';
            interactive = ''
              export PS1='\[\033[1;35m\]pandora/comet\[\033[0m\] ☄️  \[\033[1;33m\]\W\[\033[0m\] \$ '
            '';
          };
        };
      });
}
