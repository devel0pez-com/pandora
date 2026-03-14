{
  description = "Pandora — Apache Auron dev shell (upstream master)";

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
        inherit (pkgs) lib stdenv;

        sparkVersion = "3.5";
        scalaVersion = "2.12";

        sparkFullVersion = "3.5.3";
        hadoopProfile = "3";
        sparkDirName = "spark-${sparkFullVersion}-bin-hadoop${hadoopProfile}";
        sparkTgz = "${sparkDirName}.tgz";
        sparkUrl = "https://archive.apache.org/dist/spark/spark-${sparkFullVersion}/${sparkTgz}";

        auronSrc = "auron";
        auronRepo = "https://github.com/apache/auron.git";

        # Shared: resolve Spark + Auron JAR
        sparkCheck = ''
          if [ -z "$PANDORA_SPARK" ] || [ ! -d "$PANDORA_SPARK/${sparkDirName}" ]; then
            echo "Spark not found. Run 'auron-setup' first."
            exit 1
          fi
          export SPARK_HOME="$PANDORA_SPARK/${sparkDirName}"

          # Resolve Auron source directory independently of CWD
          if [ -n "''${PANDORA_AURON_SRC:-}" ] && [ -d "$PANDORA_AURON_SRC" ]; then
            AURON_SRC_DIR="$PANDORA_AURON_SRC"
          elif git_root=$(git rev-parse --show-toplevel 2>/dev/null) && [ -d "$git_root/dev/mvn-build-helper" ]; then
            AURON_SRC_DIR="$git_root"
          else
            echo "Could not locate Auron source tree. Run from the Auron repo root or set PANDORA_AURON_SRC."
            exit 1
          fi

          AURON_ASSEMBLY_DIR="$AURON_SRC_DIR/dev/mvn-build-helper/assembly/target"
          if [ ! -d "$AURON_ASSEMBLY_DIR" ]; then
            echo "Auron build output directory not found at '$AURON_ASSEMBLY_DIR'. Run 'auron-build' first."
            exit 1
          fi

          AURON_JAR=$(find "$AURON_ASSEMBLY_DIR" -maxdepth 1 -name "auron-spark-${sparkVersion}_${scalaVersion}-*.jar" 2>/dev/null | grep -v -E '(sources|javadoc|tests|original)' | head -1 || true)
          if [ -z "$AURON_JAR" ]; then
            echo "Auron JAR not found in '$AURON_ASSEMBLY_DIR'. Run 'auron-build' first."
            exit 1
          fi
        '';

        # Shared Auron Spark conf
        auronConf = builtins.concatStringsSep " " [
          ''--master "local[4]"''
          "--jars \"$AURON_JAR\""
          "--driver-class-path \"$AURON_JAR\""
          "--conf spark.executor.extraClassPath=\"$AURON_JAR\""
          "--conf spark.sql.extensions=org.apache.spark.sql.auron.AuronSparkSessionExtension"
          "--conf spark.shuffle.manager=org.apache.spark.sql.execution.auron.shuffle.AuronShuffleManager"
        ];

      in
      {
        devShells.default = pkgs.devshell.mkShell {
          name = "pandora-auron";

          packages = with pkgs; [
            # JVM (Spark / Flink / Maven)
            jdk17
            maven

            # Rust (native engine)
            rustup
            protobuf

            # C/C++ (needed by bindgen, jni)
            clang
            llvmPackages.libclang

            # System libs
            openssl
            openssl.dev
            libiconv

            # Build tools
            cmake
            pkg-config
            gnumake
            gnutar
            curl
            git
            python3
          ] ++ lib.optionals stdenv.isDarwin [
            darwin.apple_sdk.frameworks.Security
            darwin.apple_sdk.frameworks.CoreFoundation
            darwin.apple_sdk.frameworks.SystemConfiguration
          ];

          env = [
            { name = "JAVA_HOME"; value = "${pkgs.jdk17.home}"; }
            { name = "LIBCLANG_PATH"; value = "${pkgs.llvmPackages.libclang.lib}/lib"; }
            { name = "OPENSSL_DIR"; value = "${pkgs.openssl.dev}"; }
            { name = "OPENSSL_LIB_DIR"; value = "${pkgs.openssl.out}/lib"; }
            { name = "OPENSSL_INCLUDE_DIR"; value = "${pkgs.openssl.dev}/include"; }
            { name = "LIBRARY_PATH"; value = "${pkgs.libiconv}/lib"; }
          ];

          commands = [
            {
              name = "auron-fetch";
              category = "setup";
              help = "Clone or update apache/auron (master)";
              command = ''
                set -e
                if [ -d "$PWD/.git" ] && grep -q "auron" "$PWD/.git/config" 2>/dev/null; then
                  SRC_DIR="$PWD"
                elif [ -d "$PWD/${auronSrc}/.git" ]; then
                  SRC_DIR="$PWD/${auronSrc}"
                elif [ -d "${auronSrc}/.git" ]; then
                  SRC_DIR="${auronSrc}"
                else
                  echo "Cloning apache/auron (master)..."
                  git clone --depth 1 --branch master "${auronRepo}" "${auronSrc}"
                  echo ""
                  echo "Done. Source cloned to ${auronSrc}/"
                  exit 0
                fi
                if [ -n "$(git -C "$SRC_DIR" status --porcelain)" ]; then
                  echo "WARNING: local changes detected in $SRC_DIR"
                  echo "Use --force to discard them, or stash/commit first."
                  if [ "''${1:-}" != "--force" ]; then
                    exit 1
                  fi
                fi
                echo "Updating apache/auron (master)..."
                git -C "$SRC_DIR" fetch origin master
                git -C "$SRC_DIR" reset --hard origin/master
                echo ""
                echo "Updated to latest master."
              '';
            }
            {
              name = "auron-setup";
              category = "setup";
              help = "Download Spark ${sparkFullVersion} (shared in resources/)";
              command = ''
                set -euo pipefail
                if [ -z "${PANDORA_SPARK:-}" ]; then
                  echo "Error: PANDORA_SPARK not set. Re-enter the devshell."
                  exit 1
                fi
                if [ -d "$PANDORA_SPARK/${sparkDirName}" ]; then
                  echo "Spark ${sparkFullVersion} already exists in $PANDORA_SPARK/"
                else
                  echo "Downloading Spark ${sparkFullVersion} to shared resources..."
                  mkdir -p "$PANDORA_SPARK"
                  ${pkgs.curl}/bin/curl -fSL "${sparkUrl}" -o "$PANDORA_SPARK/${sparkTgz}"
                  ${pkgs.gnutar}/bin/tar xzf "$PANDORA_SPARK/${sparkTgz}" -C "$PANDORA_SPARK/"
                  rm -f "$PANDORA_SPARK/${sparkTgz}"
                  echo "Spark ${sparkFullVersion} installed in $PANDORA_SPARK/"
                fi
                echo ""
                echo "SPARK_HOME=$PANDORA_SPARK/${sparkDirName}"
              '';
            }
            {
              name = "auron-build";
              category = "build";
              help = "Full build via auron-build.sh (Spark ${sparkVersion}, Scala ${scalaVersion})";
              command = ''
                set -e
                echo "=== Building Auron (Spark ${sparkVersion}, Scala ${scalaVersion}) ==="
                bash auron-build.sh --sparkver ${sparkVersion} --scalaver ${scalaVersion} --release "$@"
                echo ""
                AURON_JAR=$(find dev/mvn-build-helper/assembly/target -maxdepth 1 -name "auron-spark-${sparkVersion}_${scalaVersion}-*.jar" 2>/dev/null | grep -v -E '(sources|javadoc|tests|original)' | head -1)
                if [ -z "$AURON_JAR" ]; then
                  echo "Error: no Auron JAR found in dev/mvn-build-helper/assembly/target/" >&2
                  exit 1
                fi
                echo "JAR ready: $AURON_JAR"
              '';
            }
            {
              name = "auron-build-native";
              category = "build";
              help = "Build native engine only (Rust release)";
              command = ''
                set -e
                echo "=== Building native engine (Rust release) ==="
                cd native-engine && cargo build --release
                echo ""
                echo "Native build complete."
              '';
            }
            {
              name = "auron-build-debug";
              category = "build";
              help = "Build native engine (debug, faster compile)";
              command = ''
                set -e
                echo "=== Building native engine (debug) ==="
                cd native-engine && cargo build
                echo ""
                echo "Debug build complete."
              '';
            }
            {
              name = "auron-test";
              category = "build";
              help = "Run Auron tests (Maven)";
              command = ''
                set -e
                echo "=== Running Auron tests ==="
                bash auron-build.sh --sparkver ${sparkVersion} --scalaver ${scalaVersion} --skiptests false "$@"
              '';
            }
            {
              name = "auron-test-native";
              category = "build";
              help = "Run native engine tests (Rust)";
              command = ''
                set -e
                echo "=== Running native engine tests ==="
                cd native-engine && cargo test "$@"
              '';
            }
            {
              name = "auron-shell";
              category = "spark";
              help = "spark-shell with Auron (UI at localhost:4040)";
              command = ''
                ${sparkCheck}
                echo "Launching spark-shell with Auron..."
                echo "  SPARK_HOME=$SPARK_HOME"
                echo "  AURON_JAR=$AURON_JAR"
                echo "  Spark UI: http://localhost:4040"
                echo ""
                exec "$SPARK_HOME/bin/spark-shell" ${auronConf} "$@"
              '';
            }
            {
              name = "auron-sql";
              category = "spark";
              help = "spark-sql with Auron";
              command = ''
                ${sparkCheck}
                echo "Launching spark-sql with Auron..."
                echo "  Spark UI: http://localhost:4040"
                echo ""
                exec "$SPARK_HOME/bin/spark-sql" ${auronConf} "$@"
              '';
            }
            {
              name = "auron-pyspark";
              category = "spark";
              help = "pyspark with Auron";
              command = ''
                ${sparkCheck}
                echo "Launching pyspark with Auron..."
                echo "  Spark UI: http://localhost:4040"
                echo ""
                exec "$SPARK_HOME/bin/pyspark" ${auronConf} "$@"
              '';
            }
            {
              name = "auron-submit";
              category = "spark";
              help = "spark-submit with Auron";
              command = ''
                ${sparkCheck}
                echo "Launching spark-submit with Auron..."
                echo "  Spark UI: http://localhost:4040"
                echo ""
                exec "$SPARK_HOME/bin/spark-submit" ${auronConf} "$@"
              '';
            }
          ];

          bash = {
            extra = ''
              # Resolve pandora resources dir (absolute path, works from any CWD)
              PANDORA_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
              if [ -z "$PANDORA_ROOT" ]; then
                echo "Error: Could not determine PANDORA_ROOT. Please run this dev shell from within a Pandora git checkout." >&2
                return 1 2>/dev/null || exit 1
              fi
              export PANDORA_SPARK="$PANDORA_ROOT/resources/spark"
              if [ -d "$PANDORA_SPARK/${sparkDirName}" ]; then
                export SPARK_HOME="$PANDORA_SPARK/${sparkDirName}"
              fi
            '';
            interactive = ''
              export PS1='\[\033[1;31m\]pandora/auron\[\033[0m\] \[\033[1;33m\]\W\[\033[0m\] \$ '
            '';
          };
        };
      });
}
