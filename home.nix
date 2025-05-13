
{ config, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
in {
  home = {
    packages = with pkgs; [home-manager];
    stateVersion = "24.11";
    enableNixpkgsReleaseCheck = false;
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
    sessionPath = [
    #   "${homeDir}/.emacs.d/bin"
    ];
  };

  xdg.mimeApps = import ./mime.nix;
  xdg.desktopEntries = import ./desktop-extra.nix pkgs;
  xdg.configFile = (import ./config.nix {inherit pkgs;}).hmConfig {};

  programs = {
    zoxide = {
      enable = true;
    };
  };
}
