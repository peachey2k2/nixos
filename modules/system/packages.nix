{
  pkgs,
  inputs,
  system,
  ...
}:

with pkgs;
[
  claude-code
  tokscale
  fooyin
  (llama-cpp.override { cudaSupport = true; })
  chatgpt
  openutau
  zap
  libnotify
  # ollama-cuda
  ryubing
  _0fetch
  acpi
  alarm-clock-applet
  alsa-utils
  android-studio
  anki-bin
  adwaita-icon-theme
  arc-icon-theme
  aseprite
  bc
  brightnessctl
  btop
  carapace
  clang
  cloc
  cmake
  copyq
  cpu-x
  duf
  easyeffects
  ed
  edb
  emote
  fasm
  fd
  feh
  (fenix.complete.withComponents [
    "cargo"
    "rustc"
    "rust-src"
  ])
  (flameshot.override { enableWlrSupport = true; })
  freeoffice
  fzf
  gcc
  gdb
  # ghostty
  git
  gnumake
  gparted
  grayjay
  gtkwave
  hexdump
  hyperfine
  hyprpolkitagent
  iverilog
  # jai
  # jails
  jdk17_headless
  jq
  jujutsu
  kdePackages.kdeconnect-kde
  kdePackages.kdenlive
  kdePackages.okular
  kdePackages.qtdeclarative
  krita
  lenovo-legion
  lf
  # loopspinner
  love
  luajit
  lua-language-server
  man-pages
  marksman
  microfetch
  mpv
  neovim
  nethack
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
  obsidian
  pavucontrol
  php
  pi
  prismlauncher
  proton-vpn
  python314Packages.python-lsp-server
  python3Minimal
  qbe
  qbittorrent
  (qdiskinfo.override { themeBundle = qdiskinfo.themeBundles.aoi; })
  radicle-node
  renderdoc
  replace
  ripgrep
  run0-sudo-shim
  # rusic
  rust-analyzer-nightly
  satty
  (
    let
      rustToolchain = (fenix.fromToolchainName {
        name = "nightly-2026-04-03";
        sha256 = "sha256-WAg39aJqFUa71UYBIAPxIX9uriD11P6uGKAPNmxSNMo=";
      }).withComponents [
        "cargo"
        "llvm-tools-preview"
        "rust-src"
        "rustc"
        "rustc-dev"
      ];
    in
    callPackage ../../packages/shrimply {
      rustPlatform = makeRustPlatform {
        cargo = rustToolchain;
        rustc = rustToolchain;
        # CUDA supports a narrower compiler range than the default stdenv.
        # Keep Rust host linking and CUDA dependencies on the same toolchain.
        stdenv = cudaPackages.backendStdenv;
      };
    }
  )
  sillytavern
  starship
  svlangserver
  swaybg
  sway-contrib.grimshot
  tack
  autolith
  reborder
  blank
  tokei
  tmux
  typescript-language-server
  unrar
  codex
  godot
  steelix
  llvmPackages_20.clang-tools
  nushell
  opencode
  wezterm
  ghostty
  zls
  zulu25
  unzip
  adw-gtk3
  qt6Packages.qtstyleplugin-kvantum
  virtiofsd
  vlc
  vscode
  nilshell
  wayvnc
  weechat
  wget
  wgsl-analyzer
  winetricks
  wlrctl
  wtype
  wineWow64Packages.full
  wl-clipboard
  wl-clip-persist
  wofi
  xarchiver
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
  xdg-utils
  thunar
  xfce4-terminal
  xhost
  xwayland-satellite
  yazi
  zathura
  zen-browser
  zerotierone
  zfxtop
  zig
  zynk-cli
]
