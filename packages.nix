pkgs: with pkgs; [
  acpi
  alarm-clock-applet
  alsa-utils
  # android-studio
  anki
  antigravity
  arc-icon-theme
  aseprite
  bc
  # blender
  brave
  brightnessctl
  btop
  caelestia-cli
  caelestia-shell
  carapace
  clang
  cloc
  cmake
  copyq
  cpu-x
  # darwin.xcode
  dosbox-x
  duf
  ed
  edb
  # emacs
  emote
  fasm
  fd
  feh
  (fenix.withComponents ["cargo" "rustc"])
  # ffmpeg
  (flameshot.override { enableWlrSupport = true; })
  freeoffice
  fzf
  gcc
  gdb
  gemini-cli
  ghostty
  git
  gnumake
  # go
  # gopls
  gparted
  gtkwave
  hexdump
  hyperfine
  hyprpolkitagent
  # imagemagick
  iverilog
  jdk17_headless
  # jdk21_headless
  # jdk8_headless
  jq
  jujutsu
  kdePackages.kdenlive
  kdePackages.qtdeclarative
  krita
  lenovo-legion
  lf
  # libllvm
  love
  luajit
  lua-language-server
  # mako
  # manim
  mpv
  neovim
  networkmanagerapplet
  nil
  nim
  nimble
  ninja
  nodejs
  nur.repos.forkprince.helium-nightly
  nu_scripts
  nwg-look
  ocamlPackages.sexp
  odin
  ols
  omnisharp-roslyn
  # onlyoffice-desktopeditors
  pavucontrol
  pfetch-rs
  php
  picom
  prismlauncher
  protonvpn-gui
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
  typescript-language-server
  unrar
  unstable.godot
  unstable.helix
  # unstable.jetbrains.idea-community-bin
  unstable.llvmPackages_20.clang-tools
  # unstable.llvmPackages_20.libllvm
  # unstable.llvmPackages_20.llvm
  unstable.nushell
  unstable.rust-analyzer
  unstable.wezterm
  unstable.zls
  unstable.zulu25
  unzip
  vimix-gtk-themes
  virtiofsd
  vlc
  vscode
  waybar
  wayvnc
  wget
  wgsl-analyzer
  winetricks
  # wineWowPackages.staging
  wineWowPackages.wayland
  wl-clipboard
  wofi
  xarchiver
  xfce.thunar
  xfce.xfce4-terminal
  xorg.xhost
  zathura
  zen-browser
  zerotierone
  zfxtop
  zig
  zsh
]