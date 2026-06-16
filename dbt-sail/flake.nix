{
  description = "Pandora — dbt + Sail (Spark Connect) demo dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, devshell, flake-utils }:
    let
      # Upstream-ready overlay. Each entry mirrors a real nixpkgs python
      # package (see ./pkgs/*/package.nix). The day a package lands in your
      # channel, delete its file in ./pkgs and remove its line here — nothing
      # else in this flake changes.
      overlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {

            # ── sqlparams ────────────────────────────────────────────────
            # UPSTREAM: move ./pkgs/sqlparams/package.nix to
            #   nixpkgs/pkgs/development/python-modules/sqlparams/package.nix
            # and add to pkgs/top-level/python-packages.nix:
            #   sqlparams = callPackage ../development/python-modules/sqlparams { };
            # THEN DELETE: this entry + the ./pkgs/sqlparams folder.
            sqlparams = pyfinal.callPackage ./pkgs/sqlparams/package.nix { };

            # ── dbt-spark ────────────────────────────────────────────────
            # UPSTREAM: move ./pkgs/dbt-spark/package.nix to
            #   nixpkgs/pkgs/development/python-modules/dbt-spark/package.nix
            # and add to pkgs/top-level/python-packages.nix:
            #   dbt-spark = callPackage ../development/python-modules/dbt-spark { };
            # THEN DELETE: this entry + the ./pkgs/dbt-spark folder.
            dbt-spark = pyfinal.callPackage ./pkgs/dbt-spark/package.nix { };

            # ── pysail ───────────────────────────────────────────────────
            # Vendored verbatim from nixpkgs PR #530421 (not merged yet).
            # WHEN PR #530421 MERGES into your channel: DELETE this entire
            # entry + the ./pkgs/pysail folder. Nothing else changes — the
            # name `pysail` then resolves to the upstream package.
            # (`protoc = protobuf` only because the standalone `protoc` attr
            #  is newer than some nixpkgs-unstable snapshots; remove once your
            #  channel has `protoc` — upstream the arg resolves on its own.)
            pysail = pyfinal.callPackage ./pkgs/pysail/package.nix {
              protoc = final.protobuf;
            };
          })
        ];
      };
    in
    {
      overlays.default = overlay;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            devshell.overlays.default
            overlay
          ];
        };

        # dbt + the Spark Connect *client* (pure gRPC, no JVM needed).
        # dbt-spark pulls dbt-core/dbt-adapters/dbt-common/sqlparams itself.
        #
        # NOTE: must use buildEnv with ignoreCollisions, NOT withPackages.
        # dbt-core and every dbt adapter ship their own `dbt/__init__.py`
        # (PEP 420 namespace package), which collides in a plain symlink env.
        # This is exactly how upstream `dbt.withAdapters` builds its env
        # (pkgs/development/python-modules/dbt-core/with-adapters.nix).
        pythonEnv = pkgs.python3.buildEnv.override {
          extraLibs = with pkgs.python3Packages; [
            dbt-core
            dbt-spark
            pyspark
            grpcio
            grpcio-status
            googleapis-common-protos
            pyarrow
            pandas
            numpy
            zstandard # required by pyspark.sql.connect (>= 0.25.0)
          ];
          ignoreCollisions = true;
        };

        sailPort = "50051";
        sparkRemote = "sc://127.0.0.1:${sailPort}";
      in
      {
        # `nix build .#dbt-spark` / `.#sqlparams` / `.#pysail` to verify the
        # packaging in isolation; `.#default` builds the full python env.
        packages = {
          inherit (pkgs.python3Packages) dbt-spark sqlparams pysail;
          default = pythonEnv;
        };

        devShells.default = pkgs.devshell.mkShell {
          name = "pandora-dbt-sail";

          packages = [
            pythonEnv
            pkgs.sail # the `sail` CLI (Spark Connect server), already in nixpkgs
          ];

          env = [
            # dbt finds the project/profiles regardless of cwd inside the shell.
            { name = "DBT_PROJECT_DIR"; eval = "$PRJ_ROOT/dbt_project"; }
            { name = "DBT_PROFILES_DIR"; eval = "$PRJ_ROOT/dbt_project"; }
            { name = "SAIL_PORT"; value = sailPort; }
            # Belt-and-suspenders: profiles.yml already sets spark.remote, but
            # exporting this makes any stray pyspark builder go Connect too.
            { name = "SPARK_REMOTE"; value = sparkRemote; }
          ];

          commands = [
            {
              name = "sail-up";
              category = "sail";
              help = "Start the Sail Spark Connect server (background, port $SAIL_PORT)";
              command = ''
                set -euo pipefail
                mkdir -p "$PRJ_ROOT/.sail"
                PIDFILE="$PRJ_ROOT/.sail/server.pid"
                LOGFILE="$PRJ_ROOT/.sail/server.log"
                if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
                  echo "Sail already running (pid $(cat "$PIDFILE")) on ${sparkRemote}"
                  exit 0
                fi
                echo "Starting Sail Spark Connect server on ${sparkRemote} ..."
                RUST_LOG=info nohup sail spark server --ip 127.0.0.1 --port "$SAIL_PORT" \
                  >"$LOGFILE" 2>&1 &
                echo $! > "$PIDFILE"
                # wait for the port to accept connections
                for _ in $(seq 1 30); do
                  if ${pkgs.netcat-gnu}/bin/nc -z 127.0.0.1 "$SAIL_PORT" 2>/dev/null; then
                    echo "Sail ready (pid $(cat "$PIDFILE")). Logs: .sail/server.log"
                    exit 0
                  fi
                  sleep 0.5
                done
                echo "Sail did not come up in time — check .sail/server.log" >&2
                exit 1
              '';
            }
            {
              name = "sail-down";
              category = "sail";
              help = "Stop the Sail Spark Connect server";
              command = ''
                set -euo pipefail
                PIDFILE="$PRJ_ROOT/.sail/server.pid"
                if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
                  kill "$(cat "$PIDFILE")" && echo "Sail stopped."
                  rm -f "$PIDFILE"
                else
                  echo "Sail not running."
                fi
              '';
            }
            {
              name = "dbt-build";
              category = "dbt";
              # Sail's default catalog is in-memory and PER-SESSION, so seed +
              # run + test must share one Spark Connect connection. `dbt build`
              # does exactly that (one process = one session). Separate
              # `dbt seed`/`dbt run` would each open a fresh, empty catalog.
              help = "Seed + run + test in ONE Spark Connect session";
              command = ''exec dbt build "$@"'';
            }
            {
              name = "dbt-docs";
              category = "dbt";
              help = "Generate + serve the lineage docs (http://localhost:8080)";
              command = ''
                set -e
                dbt docs generate
                exec dbt docs serve --port 8080
              '';
            }
            {
              name = "demo";
              category = "demo";
              help = "End-to-end: start Sail + dbt build (seed + run + test)";
              command = ''
                set -e
                sail-up
                echo "== dbt build (seed + run + test) =="
                dbt build
                echo ""
                echo "Done. 'dbt-docs' for lineage, 'sail-down' to stop the server."
              '';
            }
          ];
        };
      }
    );
}
