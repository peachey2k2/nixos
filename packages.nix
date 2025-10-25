pkgs: with pkgs; [
  acpi
  alarm-clock-applet
  alsa-utils
  android-studio
  anki
  arc-icon-theme
  aseprite
  bc
  # blender
  brave
  brightnessctl
  btop
  carapace
  clang
  cloc
  cmake
  copyq
  # darwin.xcode
  dosbox-x
  duf
  ed
  # emacs
  emote
  fasm
  fd
  (fenix.withComponents ["cargo" "rustc"])
  # ffmpeg
  (flameshot.override { enableWlrSupport = true; })
  freeoffice
  fzf
  gcc
  gdb
  git
  gnumake
  # go
  # gopls
  gparted
  gtkwave
  hexdump
  hyperfine
  # imagemagick
  iverilog
  jdk17_headless
  # jdk21_headless
  # jdk8_headless
  jq
  jujutsu
  kdePackages.qtdeclarative
  krita
  lf
  # libllvm
  love
  luajit
  lua-language-server
  mako
  # manim
  mpv
  neovim
  networkmanagerapplet
  nil
  nim
  nimble
  ninja
  nodejs
  nu_scripts
  ocamlPackages.sexp
  odin
  ols
  omnisharp-roslyn
  # onlyoffice-desktopeditors
  pavucontrol
  pfetch
  php
  picom
  # prismlauncher
  python312Packages.python-lsp-server
  python3Minimal
  qbe
  qbittorrent
  renderdoc
  ripgrep
  satty
  # SDL2
  starship
  svlangserver
  swaybg
  sway-contrib.grimshot 
  themechanger
  trash-cli
  typescript-language-server
  unrar
  unstable.flutter
  unstable.godot
  unstable.helix
  # unstable.jetbrains.idea-community-bin
  unstable.llvmPackages_20.clang-tools
  # unstable.llvmPackages_20.libllvm
  # unstable.llvmPackages_20.llvm
  unstable.nushell
  unstable.quickshell
  unstable.rust-analyzer
  unstable.wezterm
  unstable.zls
  unzip
  vimix-gtk-themes
  vlc
  vscode
  waybar
  wayvnc
  wget
  wgsl-analyzer
  winetricks
  wineWowPackages.staging
  wl-clipboard
  wofi
  xarchiver
  xfce.thunar
  xfce.xfce4-terminal
  zathura
  zen-browser
  zerotierone
  zfxtop
  zig
  zsh
]