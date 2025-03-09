
{ config, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  defEditor = "emacs.desktop";
in {
  home = {
    packages = with pkgs; [home-manager];
    stateVersion = "24.11";
    sessionVariables = {
      XDG_CONFIG_HOME = "${homeDir}/.config";
    };
    # sessionPath = [
    #   "${homeDir}/.emacs.d/bin"
    # ];

    shellAliases = {
        "@rebuild" = "sudo nixos-rebuild switch --flake ~/nixos#chey";
        "@edit" = "nvim ~/nixos/flake.nix '+cd ~/nixos'";
        "@config-reload" = "nix run ~/nixos#generate-configs";

        "fz" = "export FZF=$(fzf --walker=dir,file,hidden) && echo $FZF";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "thunar.desktop";
      "text/plain" = defEditor;
      "text/markdown" = defEditor;
    };
  };

  xdg.configFile = (import ./config.nix {inherit pkgs;}).hmConfig {};

  programs.zsh = {
    enable = true;
    initExtra = /* zsh */ ''
      # ---[ p10k ]---
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      if [[ -r "${homeDir}/.config/p10k.zsh" ]]; then
        source "${homeDir}/.config/p10k.zsh"
      fi

      # ---[ Keybinds ]---
      # ctrl + L/R arrow keys to jump by a word
      bindkey "^[[1;5D" backward-word
      bindkey "^[[1;5C" forward-word

      # ctrl + bspace to erase previous word
      bindkey '^H' backward-kill-word  # Ctrl + Backspace
    '';
  };

  
}
