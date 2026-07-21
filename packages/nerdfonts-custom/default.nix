{ pkgs, ... }:

let
  fixMonaspaceFallbackMetrics = ./fix-monaspace-fallback-metrics.py;
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "nerdfonts-custom";
  version = pkgs.nerd-fonts.symbols-only.version;

  src = pkgs.nerd-fonts.symbols-only;

  nativeBuildInputs = [ pkgs.fontforge ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/truetype

    for font in $src/share/fonts/truetype/NerdFonts/Symbols/*.ttf; do
      target="$out/share/fonts/truetype/$(basename "$font")"
      cp "$font" "$target"
      chmod +w "$target"
      fontforge -lang=py -script ${fixMonaspaceFallbackMetrics} "$target"
      mv "$target.fixed.ttf" "$target"
    done

    runHook postInstall
  '';
}
