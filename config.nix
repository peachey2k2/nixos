{pkgs}:

let
  configDir = ./configs;

  allowedExtensions = [
    "lua" "txt" "nu"
  ];
  replacements = with pkgs; {
    editor = "hx";
    monaspace = monaspace;
    nu_scripts = nu_scripts;
  };

  lib = pkgs.lib;

  # nixos removed pkgs.substituteAll so i do this instead.
  # and no pkgs.replaceVars won't work since it errors when it doesn't find a replacement
  safeSubstitute = src:
    pkgs.runCommand
      "processed-${builtins.baseNameOf src}"
      replacements
     ''substituteAll "${src}" "$out"'';

  getExt = filename: 
    let 
      split = lib.splitString "." filename;
    in 
      if lib.length split > 1 then 
        lib.last split 
     else "";

  processEntry = path: type:
    let
      relPath = lib.removePrefix (toString configDir + "/") (toString path);
    in
      if type == "directory" then
        lib.concatLists <| lib.mapAttrsToList
          (name: type: processEntry (path + "/${name}") type)
          (builtins.readDir path)
      else if type == "regular" then
        let
          ext = getExt relPath;
          file = if lib.elem ext allowedExtensions then
            safeSubstitute path
          else
            path;
        in
          [ { name = relPath; value = file; } ]
      else
        [];

in {
  run = {}:
    pkgs.runCommand "generated-configs" {
      nativeBuildInputs = [ pkgs.coreutils ];
    } ''
      mkdir -p $out/config
      ${lib.concatMapStrings (file: ''
        targetPath="$out/config/${lib.escapeShellArg file.name}"
        mkdir -p "$(dirname "$targetPath")"
        ln -sfT "${file.value}" "$targetPath"
      '') (processEntry configDir "directory")}
    '';
}
