{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
}:

let
  pname = "zcode";
  version = "2.13.0";

  src = fetchurl {
    url = "https://cdn.codegeex.cn/zcode/electron/releases/${version}/ZCode-${version}-linux-x64.AppImage";
    hash = "sha256-DewS1K/7TqZob9HwDSSaG3mWVCvzutGp8yOHjv4YMGE=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    mv $out/bin/zcode $out/bin/.zcode-wrapped
    makeWrapper $out/bin/.zcode-wrapped $out/bin/zcode \
      --set APPIMAGE $out/bin/zcode \
      --add-flags --no-sandbox

    install -Dm444 ${appimageContents}/zcode.desktop \
      $out/share/applications/zcode.desktop
    substituteInPlace $out/share/applications/zcode.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' "Exec=$out/bin/zcode %U"

    install -Dm444 ${appimageContents}/zcode.png \
      $out/share/icons/hicolor/512x512/apps/zcode.png
  '';

  meta = {
    description = "CodeGeeX ZCode desktop app";
    homepage = "https://codegeex.cn/";
    license = lib.licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zcode";
  };
}
