
{ config, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
in {
  home = {
    packages = with pkgs; [home-manager];
    stateVersion = "24.11";
    sessionVariables = {
      XDG_CONFIG_HOME = "${homeDir}/.config";
    };
    sessionPath = [
    #   "${homeDir}/.emacs.d/bin"
    ];

    shellAliases = {
        "@rebuild" = "sudo nixos-rebuild switch --flake ~/nixos#chey";
        "@edit" = "hx ~/nixos/flake.nix -w ~/nixos";
        "@config-reload" = "nix run ~/nixos#generate-configs";
        "@list-packages" = "nix-store -q --references /run/current-system/sw | awk '{print substr(\$0, 45)}'";

        fz = "export FZF=$(fzf --walker=dir,file,hidden) && echo $FZF";
        cd = "z";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = let
      fileManager = "thunar.desktop";
      text = "emacs.desktop";
      pdf = "zathura.desktop";
      word = "freeoffice-textmaker.desktop";
    in {
      "inode/directory" = fileManager;
      "text/plain" = text;
      "text/markdown" = text;
      "application/pdf" = pdf;
      "application/msword" = word;
    };
  };

  xdg.configFile = (import ./config.nix {inherit pkgs;}).hmConfig {};

  programs = {
    zsh = {
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
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
