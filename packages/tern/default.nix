{
  lib,
  stdenv,
  requireFile,
  autoPatchelfHook,
  makeWrapper,
  wayland,
  libxkbcommon,
  vulkan-loader,
  libglvnd,
  pam,
}:

stdenv.mkDerivation {
  pname = "tern";
  version = "0.4.1";

  src = requireFile {
    name = "Tern-0.4.1-linux-x86_64.tar.gz";
    sha256 = "sha256-0AwxeySlXSnBRAZXpkSG0BCOEhlSYYQOCObhdqEznjQ=";
    message = ''
      The Tern tarball is behind Stencil auth and cannot be fetched by Nix.
      Download it manually:
        https://build.stencil.so/d/tern/20261004-013402-188ec1a/Tern-0.4.1-linux-x86_64.tar.gz
      then run:
        nix-store --add-fixed sha256 /path/to/Tern-0.4.1-linux-x86_64.tar.gz
    '';
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    wayland
    libxkbcommon
    vulkan-loader
    libglvnd
    pam
  ];

  unpackPhase = ''
    runHook preUnpack
    tar -xzf "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/tern
    install -Dm755 tern/tern $out/opt/tern/tern
    cp -r --no-preserve=mode tern/assets $out/opt/tern/assets

    mkdir -p $out/bin
    makeWrapper $out/opt/tern/tern $out/bin/tern \
      --set STENCIL_ASSETS "$out/opt/tern/assets" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
        stdenv.cc.cc.lib
        wayland
        libxkbcommon
        vulkan-loader
        libglvnd
        pam
      ]}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Tern terminal workspace";
    homepage = "https://build.stencil.so/d/tern/20261004-013402-188ec1a/Tern-0.4.1-linux-x86_64.tar.gz";
    license = licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    mainProgram = "tern";
  };
}
