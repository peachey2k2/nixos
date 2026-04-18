{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "zynk-cli";
  version = "1.1.0";

  src = fetchurl {
    url = "https://zynk.it/downloads/latest/linux/cli/x86";
    hash = "sha256-ckfoh3hj/abTeiMmI0lNscbkKrX1zAJGIYYzrEBdrpo=";
  };

  unpackPhase = ''
    runHook preUnpack
    tar -xzf "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 0755 zynk-cli $out/bin/zynk

    runHook postInstall
  '';

  meta = with lib; {
    description = "Zynk CLI";
    homepage = "https://zynk.it/";
    license = licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zynk";
  };
}
