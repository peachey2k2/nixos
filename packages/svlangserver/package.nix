{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "svlangserver";
  version = "0.3.5";

  src = fetchFromGitHub {
    owner = "imc-trading";
    repo = "svlangserver";
    rev = "v${version}";
    hash = "";
  };

  npmDepsHash = "";

  dontNpmBuild = true;

  meta = {
    description = "A language server for systemverilog";
    homepage = "https://github.com/imc-trading/svlangserver";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "svlangserver";
  };
}
