{ pkgs, ... }:

{
  fonts = {
    enableDefaultPackages = true;

    packages = with pkgs; [
      twitter-color-emoji
      corefonts
      miracode
      monaspace
      nerd-fonts.symbols-only
      # nerdfonts-custom
      noto-fonts-cjk-sans
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "Monaspace Krypton" ];
        emoji = [ "Twitter Color Emoji" ];
      };
    };
  };
}
