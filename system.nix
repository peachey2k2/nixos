{ user }:
{ config, lib, pkgs, ... }:

let
  homeDir = "/home/${user}";
  flakeDir = "${homeDir}/nixos";
in {
  imports = [
    # either generate and cp this or find it elsewhere
    ./hardware-configuration.nix
    # nvidia, optimus etc.
    # ./nvidia.nix
  ];

  # Bootloader.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
      timeout = 1;
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    hostName = "chey";
    networkmanager.enable = true;
  };

  # Set your time zone.
  time.timeZone = "Europe/Istanbul";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "tr_TR.UTF-8";
      LC_IDENTIFICATION = "tr_TR.UTF-8";
      LC_MEASUREMENT = "tr_TR.UTF-8";
      LC_MONETARY = "tr_TR.UTF-8";
      LC_NAME = "tr_TR.UTF-8";
      LC_NUMERIC = "tr_TR.UTF-8";
      LC_PAPER = "tr_TR.UTF-8";
      LC_TELEPHONE = "tr_TR.UTF-8";
      LC_TIME = "tr_TR.UTF-8";
    };
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "tr";
    variant = "intl";
  };

  # Configure console keymap
  console.keyMap = "trq";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # hardware.bluetooth.enable = true;
  # hardware.bluetooth.powerOnBoot = true;
  # services.blueman.enable = true;
  
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  
  services.teamviewer.enable = true;
  services.gvfs.enable = true;
  services.zerotierone = {
    enable = true;
    port = 9993;
  };
  services.cron = {
    enable = true;
    systemCronJobs = [
    ];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${user} = {
    isNormalUser = true;
    shell = pkgs.elvish;
    description = user;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = [];
  };

  # Enable automatic login for the user.
  services.getty = {
    autologinUser = user;
    autologinOnce = true;
  };

  nixpkgs = {
    config.allowUnfree = true;
    config.allowBroken = true;

    config.packageOverrides = with pkgs; {
      svlangserver = pkgs.callPackage ./packages/svlangserver/package.nix {};
      marked = pkgs.callPackage ./packages/marked/package.nix {};
    };
  };

  nix.settings.experimental-features = [
    "flakes" "nix-command"
  ];


  programs = {
    # zsh.enable = true;
    steam.enable = true;
    xfconf.enable = true; # for thunar, terminal etc. configs
    thunar.plugins = with pkgs.xfce; [
      thunar-archive-plugin thunar-volman
    ];
    hyprland = {
      enable = true;
      xwayland.enable = true;
    };
    obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
      ];
    };
    nh = {
      enable = true;
      clean.enable = false;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = flakeDir;
      package = pkgs.unstable.nh;
    };
  };

  environment = {
    variables = import ./envvars.nix pkgs homeDir;
    systemPackages = import ./packages.nix pkgs;
  };

  fonts = {
    enableDefaultPackages = true;
    packages = import ./fonts.nix pkgs;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = true;
      AllowUsers = null; # Allows all users by default. Can be [ "user1" "user2" ]
      UseDns = true;
      X11Forwarding = false;
      PermitRootLogin = "yes"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  networking.firewall.allowedUDPPorts = [ 9993 25565 22 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).

  # DO. NOT. CHANGE. THIS.
  system.stateVersion = "24.11"; # Did you read the comment?

}
