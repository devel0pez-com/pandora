{
  description = "Pandora — DataFusion Comet dev shell (upstream main)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        sparkVersion = "3.5.7";
        sparkVersionShort = "3.5";
        hadoopProfile = "3";
        scalaVersion = "2.12";
        sparkDirName = "spark-${sparkVersion}-bin-hadoop${hadoopProfile}";
        sparkTgz = "${sparkDirName}.tgz";

        sparkUrl = "https://archive.apache.org/dist/spark/spark-${sparkVersion}/${sparkTgz}";

        # Directorio del source de Comet (clone de upstream)
        cometSrc = "datafusion-comet";
        cometRepo = "https://github.com/apache/datafusion-comet.git";

        # Clona o actualiza apache/datafusion-comet main
        cometFetch = pkgs.writeShellScriptBin "comet-fetch" ''
          set -e
          FLAKE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
          # Si estamos dentro de src/, subir un nivel
          if [ -d "$PWD/.git" ] && grep -q "datafusion-comet" "$PWD/.git/config" 2>/dev/null; then
            SRC_DIR="$PWD"
          elif [ -d "$PWD/${cometSrc}/.git" ]; then
            SRC_DIR="$PWD/${cometSrc}"
          elif [ -d "${cometSrc}/.git" ]; then
            SRC_DIR="${cometSrc}"
          else
            echo "Cloning apache/datafusion-comet (main)..."
            ${pkgs.git}/bin/git clone --depth 1 --branch main "${cometRepo}" "${cometSrc}"
            echo ""
            echo "Done. Source cloned to ${cometSrc}/"
            echo "Now cd ${cometSrc} and run: nix develop path:.."
            exit 0
          fi
          echo "Updating apache/datafusion-comet (main)..."
          ${pkgs.git}/bin/git -C "$SRC_DIR" fetch origin main
          ${pkgs.git}/bin/git -C "$SRC_DIR" reset --hard origin/main
          echo ""
          echo "Updated to latest main."
        '';

        # Descarga Spark
        downloadSpark = pkgs.writeShellScriptBin "comet-setup" ''
          SPARK_LOCAL="$PWD/.spark/${sparkDirName}"
          if [ ! -d "$SPARK_LOCAL" ]; then
            echo "Descargando Spark ${sparkVersion}..."
            mkdir -p .spark
            ${pkgs.curl}/bin/curl -fSL "${sparkUrl}" -o ".spark/${sparkTgz}"
            tar xzf ".spark/${sparkTgz}" -C .spark/
            rm -f ".spark/${sparkTgz}"
            echo "Spark ${sparkVersion} instalado en .spark/"
          else
            echo "Spark ${sparkVersion} ya existe en .spark/"
          fi
          echo ""
          echo "SPARK_HOME=$SPARK_LOCAL"
        '';

        cometBuild = pkgs.writeShellScriptBin "comet-build" ''
          set -e
          echo "=== Building Comet (native + JVM) via make release ==="
          echo "    cargo build --release + mvnw install -Prelease -DskipTests"
          echo ""
          make release PROFILES="-Drat.skip=true"
          echo ""
          COMET_JAR=$(ls spark/target/comet-spark-spark${sparkVersionShort}_${scalaVersion}-*.jar 2>/dev/null | grep -v -E '(sources|javadoc|tests)' | head -1)
          echo "JAR ready: $COMET_JAR"
        '';

        cometBuildDebug = pkgs.writeShellScriptBin "comet-build-debug" ''
          set -e
          echo "=== Building native only (debug) ==="
          cd native && cargo build
          echo "Done. Note: run 'comet-build' for a full release build with JAR."
        '';

        cometShell = pkgs.writeShellScriptBin "comet-shell" ''
          SPARK_LOCAL="$PWD/.spark/${sparkDirName}"
          if [ ! -d "$SPARK_LOCAL" ]; then
            echo "Spark no encontrado. Ejecuta 'comet-setup' primero."
            exit 1
          fi
          export SPARK_HOME="$SPARK_LOCAL"

          COMET_JAR=$(ls spark/target/comet-spark-spark*.jar 2>/dev/null | grep -v -E '(sources|javadoc|tests)' | head -1)
          if [ -z "$COMET_JAR" ]; then
            echo "JAR de Comet no encontrado. Ejecuta 'comet-build' primero."
            exit 1
          fi

          echo "Lanzando spark-shell con Comet..."
          echo "  SPARK_HOME=$SPARK_HOME"
          echo "  COMET_JAR=$COMET_JAR"
          echo "  Spark UI: http://localhost:4040"
          echo ""

          exec "$SPARK_HOME/bin/spark-shell" \
            --master "local[4]" \
            --jars "$COMET_JAR" \
            --driver-class-path "$COMET_JAR" \
            --conf spark.executor.extraClassPath="$COMET_JAR" \
            --conf spark.plugins=org.apache.spark.CometPlugin \
            --conf spark.shuffle.manager=org.apache.spark.sql.comet.execution.shuffle.CometShuffleManager \
            --conf spark.comet.enabled=true \
            --conf spark.comet.exec.enabled=true \
            --conf spark.comet.exec.shuffle.enabled=true \
            --conf spark.comet.explainFallback.enabled=true \
            --conf spark.memory.offHeap.enabled=true \
            --conf spark.memory.offHeap.size=4g \
            "$@"
        '';

        cometSql = pkgs.writeShellScriptBin "comet-sql" ''
          SPARK_LOCAL="$PWD/.spark/${sparkDirName}"
          if [ ! -d "$SPARK_LOCAL" ]; then
            echo "Spark no encontrado. Ejecuta 'comet-setup' primero."
            exit 1
          fi
          export SPARK_HOME="$SPARK_LOCAL"

          COMET_JAR=$(ls spark/target/comet-spark-spark*.jar 2>/dev/null | grep -v -E '(sources|javadoc|tests)' | head -1)
          if [ -z "$COMET_JAR" ]; then
            echo "JAR de Comet no encontrado. Ejecuta 'comet-build' primero."
            exit 1
          fi

          echo "Lanzando spark-sql con Comet..."
          echo "  Spark UI: http://localhost:4040"
          echo ""

          exec "$SPARK_HOME/bin/spark-sql" \
            --master "local[4]" \
            --jars "$COMET_JAR" \
            --driver-class-path "$COMET_JAR" \
            --conf spark.executor.extraClassPath="$COMET_JAR" \
            --conf spark.plugins=org.apache.spark.CometPlugin \
            --conf spark.shuffle.manager=org.apache.spark.sql.comet.execution.shuffle.CometShuffleManager \
            --conf spark.comet.enabled=true \
            --conf spark.comet.exec.enabled=true \
            --conf spark.comet.exec.shuffle.enabled=true \
            --conf spark.comet.explainFallback.enabled=true \
            --conf spark.memory.offHeap.enabled=true \
            --conf spark.memory.offHeap.size=4g \
            "$@"
        '';

        cometPyspark = pkgs.writeShellScriptBin "comet-pyspark" ''
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

          echo "Launching pyspark with Comet..."
          echo "  Spark UI: http://localhost:4040"
          echo ""

          exec "$SPARK_HOME/bin/pyspark" \
            --master "local[4]" \
            --jars "$COMET_JAR" \
            --driver-class-path "$COMET_JAR" \
            --conf spark.executor.extraClassPath="$COMET_JAR" \
            --conf spark.plugins=org.apache.spark.CometPlugin \
            --conf spark.shuffle.manager=org.apache.spark.sql.comet.execution.shuffle.CometShuffleManager \
            --conf spark.comet.enabled=true \
            --conf spark.comet.exec.enabled=true \
            --conf spark.comet.exec.shuffle.enabled=true \
            --conf spark.comet.explainFallback.enabled=true \
            --conf spark.memory.offHeap.enabled=true \
            --conf spark.memory.offHeap.size=4g \
            "$@"
        '';

        # Ejecuta un .scala o .py con Comet
        cometRun = pkgs.writeShellScriptBin "comet-run" ''
          SPARK_LOCAL="$PWD/.spark/${sparkDirName}"
          if [ ! -d "$SPARK_LOCAL" ]; then
            echo "Spark no encontrado. Ejecuta 'comet-setup' primero."
            exit 1
          fi
          export SPARK_HOME="$SPARK_LOCAL"

          COMET_JAR=$(ls spark/target/comet-spark-spark*.jar 2>/dev/null | grep -v -E '(sources|javadoc|tests)' | head -1)
          if [ -z "$COMET_JAR" ]; then
            echo "JAR de Comet no encontrado. Ejecuta 'comet-build' primero."
            exit 1
          fi

          FILE="$1"
          if [ -z "$FILE" ]; then
            echo "Usage: comet-run <file.scala|file.py>"
            exit 1
          fi
          shift

          COMET_CONF=(
            --master "local[4]"
            --jars "$COMET_JAR"
            --driver-class-path "$COMET_JAR"
            --conf spark.executor.extraClassPath="$COMET_JAR"
            --conf spark.plugins=org.apache.spark.CometPlugin
            --conf spark.shuffle.manager=org.apache.spark.sql.comet.execution.shuffle.CometShuffleManager
            --conf spark.comet.enabled=true
            --conf spark.comet.exec.enabled=true
            --conf spark.comet.exec.shuffle.enabled=true
            --conf spark.comet.explainFallback.enabled=true
            --conf spark.memory.offHeap.enabled=true
            --conf spark.memory.offHeap.size=4g
          )

          case "$FILE" in
            *.scala)
              echo "Running $FILE in spark-shell..."
              exec "$SPARK_HOME/bin/spark-shell" "''${COMET_CONF[@]}" -I "$FILE" "$@"
              ;;
            *.py)
              echo "Running $FILE in pyspark..."
              exec "$SPARK_HOME/bin/spark-submit" "''${COMET_CONF[@]}" "$FILE" "$@"
              ;;
            *)
              echo "Unsupported file type. Use .scala or .py"
              exit 1
              ;;
          esac
        '';

        cometSubmit = pkgs.writeShellScriptBin "comet-submit" ''
          SPARK_LOCAL="$PWD/.spark/${sparkDirName}"
          if [ ! -d "$SPARK_LOCAL" ]; then
            echo "Spark no encontrado. Ejecuta 'comet-setup' primero."
            exit 1
          fi
          export SPARK_HOME="$SPARK_LOCAL"

          COMET_JAR=$(ls spark/target/comet-spark-spark*.jar 2>/dev/null | grep -v -E '(sources|javadoc|tests)' | head -1)
          if [ -z "$COMET_JAR" ]; then
            echo "JAR de Comet no encontrado. Ejecuta 'comet-build' primero."
            exit 1
          fi

          echo "Lanzando spark-submit con Comet..."
          echo "  Spark UI: http://localhost:4040"
          echo ""

          exec "$SPARK_HOME/bin/spark-submit" \
            --master "local[4]" \
            --jars "$COMET_JAR" \
            --driver-class-path "$COMET_JAR" \
            --conf spark.executor.extraClassPath="$COMET_JAR" \
            --conf spark.plugins=org.apache.spark.CometPlugin \
            --conf spark.shuffle.manager=org.apache.spark.sql.comet.execution.shuffle.CometShuffleManager \
            --conf spark.comet.enabled=true \
            --conf spark.comet.exec.enabled=true \
            --conf spark.comet.exec.shuffle.enabled=true \
            --conf spark.comet.exec.shuffle.mode=native \
            --conf spark.comet.explainFallback.enabled=true \
            --conf spark.memory.offHeap.enabled=true \
            --conf spark.memory.offHeap.size=4g \
            "$@"
        '';

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
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
            curl
            git

            # Comet helper scripts
            cometFetch
            downloadSpark
            cometBuild
            cometBuildDebug
            cometShell
            cometSql
            cometPyspark
            cometSubmit
            cometRun
          ];

          shellHook = ''
            export JAVA_HOME="${pkgs.jdk17.home}"

            # bindgen needs libclang
            export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"

            # openssl-sys
            export OPENSSL_DIR="${pkgs.openssl.dev}"
            export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
            export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"

            # Si Spark ya esta descargado, exportar SPARK_HOME
            if [ -d "$PWD/.spark/${sparkDirName}" ]; then
              export SPARK_HOME="$PWD/.spark/${sparkDirName}"
            fi

            echo "╔══════════════════════════════════════════════════╗"
            echo "║   pandora — datafusion-comet dev shell           ║"
            echo "╚══════════════════════════════════════════════════╝"
            echo ""
            echo "  Java:     $(java -version 2>&1 | head -1)"
            echo "  Maven:    $(mvn --version 2>&1 | head -1)"
            echo "  Protoc:   $(protoc --version)"
            if [ -n "$SPARK_HOME" ]; then
              echo "  Spark:    ${sparkVersion}"
            else
              echo "  Spark:    (not installed — run 'comet-setup')"
            fi
            if [ -d "${cometSrc}/.git" ]; then
              echo "  Comet:    $(${pkgs.git}/bin/git -C ${cometSrc} log -1 --format='%h %s' 2>/dev/null)"
            else
              echo "  Comet:    (not cloned — run 'comet-fetch')"
            fi
            echo ""
            echo "Quick start:"
            echo "  0. comet-fetch       — clone/update apache/datafusion-comet (main)"
            echo "  1. cd ${cometSrc}            — enter source tree"
            echo "  2. comet-setup       — download Spark ${sparkVersion} (first time only)"
            echo "  3. comet-build       — full release build (native + JVM)"
            echo "  4. comet-shell       — spark-shell with Comet (UI at localhost:4040)"
            echo "  5. comet-sql         — spark-sql with Comet"
            echo "  6. comet-pyspark     — pyspark with Comet"
            echo "  7. comet-submit      — spark-submit with Comet"
            echo ""
            echo "Other:"
            echo "  comet-build-debug    — quick Rust-only debug build (no JAR)"
            echo ""

            export PS1='\[\033[1;35m\]pandora/comet\[\033[0m\] ☄️  \[\033[1;33m\]\W\[\033[0m\] \$ '
          '';
        };
      });
}
