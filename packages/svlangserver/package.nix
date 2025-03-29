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
    hash = "sha256-CkcKyC2W6NBvxkwYDVHpBF5T2NMiiDVVwR1mftEks54=";
  };

  npmDepsHash = "sha256-XovXh3weLh7xO96chlYwkqUnzganjLmKcUsAdBhA060=";

  postInstall = ''
    rm -rf $out/lib/node_modules/@imc-trading/svlangserver/node_modules/.bin
  '';

  meta = {
    description = "A language server for systemverilog";
    homepage = "https://github.com/imc-trading/svlangserver";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "svlangserver";
  };
}
