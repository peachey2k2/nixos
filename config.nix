{pkgs}:

let
  configDir = ./configs;

  allowedExtensions = [
    "lua" "txt"
  ];
  replacements = with pkgs; {
    arc_icon_theme = arc-icon-theme;
  };

  lib = pkgs.lib;
  
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
        lib.concatLists (lib.mapAttrsToList
          (name: type: processEntry (path + "/${name}") type)
          (builtins.readDir path))
      else if type == "regular" then
        let
          ext = getExt relPath;
          file = if lib.elem ext allowedExtensions then
            pkgs.substituteAll ({ src = path; } // replacements)
          else
            path;
        in
          [ { name = relPath; value = file; } ]
      else
        [];

  mkConfig = {}:
    let
      files = processEntry configDir "directory";
    in
      pkgs.symlinkJoin {
        name = "generated-configs";
        paths = map (x: x.value) files;
        postBuild = ''
          mkdir -p $out/config
          ${lib.concatMapStrings (x: ''
            mkdir -p $out/config/$(dirname ${lib.escapeShellArg x.name})
            ln -sf ${x.value} $out/config/${lib.escapeShellArg x.name}
          '') files}
        '';
      };

in {
  hmConfig = {}:
    lib.listToAttrs (map (x: lib.nameValuePair x.name { source = x.value; })
      (processEntry configDir "directory"));

  standaloneConfig = {}:
    pkgs.runCommand "generated-configs" {
      nativeBuildInputs = [ pkgs.coreutils ];
    } ''
      mkdir -p $out/config
      ${lib.concatMapStrings (file: ''
        targetPath="$out/config/${lib.escapeShellArg file.name}"
        mkdir -p "$(dirname "$targetPath")"
        ln -sfT "${lib.escapeShellArg file.value}" "$targetPath"
      '') (processEntry configDir "directory")}
    '';
}
