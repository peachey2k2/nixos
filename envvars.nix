pkgs: homeDir: with pkgs; {
  NIX_DIR = "${homeDir}/nixos";
  NIXOS_OZONE_WL = "1";
  GTK_THEME = "Vimix-dark-doder:dark";
  NIX_SYSTEM_PATH = "${homeDir}/nixos";
  NIX_CONFIG_PATH = "${homeDir}/nixos/configs";
  XDG_CONFIG_HOME = "${homeDir}/.config";
  EDITOR = "hx";
  VISUAL = "hx";
  GTK_IM_MODULE = "simple";
}
