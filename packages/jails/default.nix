{ lib
, stdenv
, autoPatchelfHook
}:

stdenv.mkDerivation {
  pname = "jails";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp bin/jails $out/bin/jails
    chmod +x $out/bin/jails

    runHook postInstall
  '';

  meta = with lib; {
    description = "An experimental language server for the Jai programming language";
    homepage = "https://github.com/ApparentlyStudio/Jails";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "jails";
  };
}
