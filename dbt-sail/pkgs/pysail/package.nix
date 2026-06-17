# VENDORED, verbatim, from nixpkgs PR #530421 (python3Packages.pysail 0.6.4):
#   https://github.com/NixOS/nixpkgs/pull/530421
# When that PR merges into your channel, delete this file and the overlay
# entry in ../../flake.nix — nothing else changes.
#
# Note: the overlay passes `protoc = protobuf` because the standalone `protoc`
# attribute is newer than some nixpkgs-unstable snapshots. Upstream this arg
# resolves on its own.
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  rustPlatform,
  nix-update-script,
  testers,
  pysail,

  protoc,
  protobuf,
}:

buildPythonPackage (finalAttrs: {
  pname = "pysail";
  version = "0.6.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "lakehq";
    repo = "sail";
    tag = "v${finalAttrs.version}";
    hash = "sha256-EX8cDed32uF7NSreViKBn7RQeWIG7C7sI6O0c+hVf4M=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname src version;
    hash = "sha256-ouNXKPpwKTLfI+Gcp393r7oHZAjUFQL9225+AuFzdoo=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"pyo3/generate-import-lib",' ""
  '';

  nativeBuildInputs = with rustPlatform; [
    cargoSetupHook
    maturinBuildHook
    protoc
  ];

  buildInputs = [
    protobuf
  ];

  pythonImportsCheck = [
    "pysail"
    "pysail._native"
  ];

  doCheck = false;

  passthru = {
    updateScript = nix-update-script { };
    tests.version = testers.testVersion {
      package = pysail;
    };
  };

  meta = {
    description = "Python bindings for Sail, a Spark-compatible compute engine on Apache Arrow and DataFusion";
    homepage = "https://github.com/lakehq/sail";
    changelog = "https://github.com/lakehq/sail/blob/v${finalAttrs.version}/docs/reference/changelog/index.md";
    license = lib.licenses.asl20;
    mainProgram = "sail";
    maintainers = [ lib.maintainers.davidlghellin ];
  };
})
