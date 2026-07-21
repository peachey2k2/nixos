{ pkgs }:

let
  lib = pkgs.lib;
  dotfilesDir = ./dotfiles;

  processedExtensions = [
    "lua"
    "txt"
    "nu"
  ];

  replacements = {
    "@editor@" = "hx";
    "@monaspace@" = toString pkgs.monaspace;
    "@noto_cjk@" = toString pkgs.noto-fonts-cjk-sans;
    "@twemoji@" = toString pkgs.twitter-color-emoji;
    "@nf_symbols@" = toString pkgs.nerd-fonts.symbols-only;
    "@nu_scripts@" = toString pkgs.nu_scripts;
  };

  substituteKnown = src:
    pkgs.writeText "processed-${builtins.baseNameOf src}" (
      lib.replaceStrings
        (builtins.attrNames replacements)
        (builtins.attrValues replacements)
        (builtins.readFile src)
    );

  extensionOf = filename:
    let
      parts = lib.splitString "." filename;
    in
    if lib.length parts > 1 then lib.last parts else "";

  processEntry = path: type:
    let
      relPath = lib.removePrefix (toString dotfilesDir + "/") (toString path);
    in
    if type == "directory" then
      lib.concatLists (
        lib.mapAttrsToList
          (name: entryType: processEntry (path + "/${name}") entryType)
          (builtins.readDir path)
      )
    else if type == "regular" then
      let
        ext = extensionOf relPath;
        file = if lib.elem ext processedExtensions then substituteKnown path else path;
      in
      [
        {
          name = relPath;
          value = file;
        }
      ]
    else
      [ ];

  dotfiles = processEntry dotfilesDir "directory";
in
{
  run = { }:
    pkgs.runCommand "generated-configs" { } ''
      mkdir -p "$out/config"
      ${lib.concatMapStrings (file: ''
        targetPath="$out/config/${file.name}"
        mkdir -p "$(dirname "$targetPath")"
        ln -sfT "${file.value}" "$targetPath"
      '') dotfiles}
    '';
}
