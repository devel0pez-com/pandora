# Upstream-ready: drop this verbatim into
#   nixpkgs/pkgs/development/python-modules/sqlparams/package.nix
# and add `sqlparams = callPackage ../development/python-modules/sqlparams { };`
# to python-packages.nix. Then delete this file and the overlay entry.
{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
}:

buildPythonPackage rec {
  pname = "sqlparams";
  version = "6.2.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-N0SirRb3EpPbZQWyH9Uim0dXSJqbCfNVNlahrpe6fKU=";
  };

  build-system = [ setuptools ];

  pythonImportsCheck = [ "sqlparams" ];

  meta = {
    description = "Convert DB API 2.0 named/numeric parameter styles to the style a driver supports";
    homepage = "https://github.com/cpburnz/python-sql-parameters";
    changelog = "https://github.com/cpburnz/python-sql-parameters/blob/v${version}/CHANGES.rst";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ davidlghellin ];
  };
}
