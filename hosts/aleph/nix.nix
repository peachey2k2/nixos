{
  pkgs,
  nixConfig,
  homeDirectory,
  ...
}:

{
  nix.settings = nixConfig;

  programs.nh = {
    enable = true;
    clean.enable = false;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "${homeDirectory}/nixos";
    package = pkgs.nh;
  };
}
