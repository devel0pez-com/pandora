{
  description = "Pandora — Apache DataFusion dev shell (upstream main)";

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

        dfSrc = "datafusion";
        dfRepo = "https://github.com/apache/datafusion.git";

      in
      {
        devShells.default = pkgs.devshell.mkShell {
          name = "pandora-datafusion";

          packages = with pkgs; [
            # Rust
            rustup
            protobuf

            # C/C++
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
            { name = "LIBCLANG_PATH"; value = "${pkgs.llvmPackages.libclang.lib}/lib"; }
            { name = "OPENSSL_DIR"; value = "${pkgs.openssl.dev}"; }
            { name = "OPENSSL_LIB_DIR"; value = "${pkgs.openssl.out}/lib"; }
            { name = "OPENSSL_INCLUDE_DIR"; value = "${pkgs.openssl.dev}/include"; }
            { name = "LIBRARY_PATH"; value = "${pkgs.libiconv}/lib"; }
          ];

          commands = [
            {
              name = "df-fetch";
              category = "setup";
              help = "Clone or update apache/datafusion (main)";
              command = ''
                set -e
                if [ -d "$PWD/.git" ] && grep -q "datafusion" "$PWD/.git/config" 2>/dev/null; then
                  SRC_DIR="$PWD"
                elif [ -d "$PWD/${dfSrc}/.git" ]; then
                  SRC_DIR="$PWD/${dfSrc}"
                elif [ -d "${dfSrc}/.git" ]; then
                  SRC_DIR="${dfSrc}"
                else
                  echo "Cloning apache/datafusion (main)..."
                  git clone --depth 1 --branch main "${dfRepo}" "${dfSrc}"
                  echo ""
                  echo "Done. Source cloned to ${dfSrc}/"
                  exit 0
                fi
                if [ -n "$(git -C "$SRC_DIR" status --porcelain)" ]; then
                  echo "WARNING: local changes detected in $SRC_DIR"
                  echo "Use --force to discard them, or stash/commit first."
                  if [ "''${1:-}" != "--force" ]; then
                    exit 1
                  fi
                fi
                echo "Updating apache/datafusion (main)..."
                git -C "$SRC_DIR" fetch origin main
                git -C "$SRC_DIR" reset --hard origin/main
                echo ""
                echo "Updated to latest main."
              '';
            }
            {
              name = "df-build";
              category = "build";
              help = "Build DataFusion (release)";
              command = ''
                set -e
                echo "=== Building DataFusion (release) ==="
                cargo build --release
                echo ""
                echo "Build complete."
              '';
            }
            {
              name = "df-build-debug";
              category = "build";
              help = "Build DataFusion (debug, faster compile)";
              command = ''
                set -e
                echo "=== Building DataFusion (debug) ==="
                cargo build
                echo ""
                echo "Build complete."
              '';
            }
            {
              name = "df-test";
              category = "build";
              help = "Run DataFusion tests";
              command = ''
                set -e
                echo "=== Running DataFusion tests ==="
                cargo test
              '';
            }
            {
              name = "df-cli";
              category = "run";
              help = "Launch DataFusion CLI (interactive SQL shell)";
              command = ''
                set -e
                if [ ! -f target/release/datafusion-cli ] && [ ! -f target/debug/datafusion-cli ]; then
                  echo "DataFusion CLI not found. Building..."
                  cargo build --release --bin datafusion-cli
                fi
                CLI=$(ls target/release/datafusion-cli 2>/dev/null || ls target/debug/datafusion-cli 2>/dev/null)
                echo "Launching DataFusion CLI..."
                exec "$CLI" "$@"
              '';
            }
            {
              name = "df-bench";
              category = "run";
              help = "Run DataFusion benchmarks";
              command = ''
                set -e
                echo "=== Running DataFusion benchmarks ==="
                cargo bench "$@"
              '';
            }
            {
              name = "df-example";
              category = "run";
              help = "Run a DataFusion example (e.g. df-example simple_udaf)";
              command = ''
                set -e
                if [ -z "$1" ]; then
                  echo "Usage: df-example <example_name>"
                  echo ""
                  echo "Available examples:"
                  ls examples/*.rs 2>/dev/null | sed 's|examples/||;s|\.rs||' || echo "  (clone first with df-fetch)"
                  exit 1
                fi
                EXAMPLE="$1"
                shift
                echo "Running example: $EXAMPLE"
                cargo run --example "$EXAMPLE" "$@"
              '';
            }
          ];

          bash = {
            interactive = ''
              export PS1='\[\033[1;34m\]pandora/datafusion\[\033[0m\] \[\033[1;33m\]\W\[\033[0m\] \$ '
            '';
          };
        };
      });
}
