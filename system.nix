{ user, nixConfig }:
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

  nix.settings = nixConfig;

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

    # windows
    supportedFilesystems = [ "ntfs" ];

    kernelModules = [ "v4l2loopback" "lenovo-legion-module" ];

    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback # https://nixos.wiki/wiki/OBS_Studio
      lenovo-legion-module
    ];

    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
      options legion_laptop force=1
    '';
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

  console.keyMap = "trq";

  services = {
    xserver.xkb = {
      layout = "tr";
      variant = "intl";
    };
    # printing.enable = true;
    blueman.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };

    switcherooControl.enable = true;
    upower.enable = true;
    gvfs.enable = true;

    cron = {
      enable = true;
      systemCronJobs = [
      ];
    };

    getty = {
      autologinUser = user;
      autologinOnce = true;
    };

    # Enable the OpenSSH daemon.
    openssh = {
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

    qemuGuest.enable = true;
    spice-vdagentd.enable = true;  # enable copy and paste between host and guest
  };

  hardware = {
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };
  
  security.rtkit.enable = true;
  security.polkit.enable = true;

  users.users.${user} = {
    isNormalUser = true;
    shell = pkgs.unstable.nushell;
    description = user;
    extraGroups = [ "networkmanager" "wheel" "docker" "video" "libvirtd" ];
    packages = [];
  };

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
      # package = pkgs.unstable.obs-studio;
      enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        droidcam-obs
      ];
    };
    nh = {
      enable = true;
      clean.enable = false;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = flakeDir;
      package = pkgs.unstable.nh;
    };
    virt-manager = {
      enable = true;
    };
  };

  virtualisation = {
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };

  environment = {
    sessionVariables = import ./envvars.nix pkgs homeDir;

    shells = [ pkgs.nushell ];

    systemPackages =
      import ./packages.nix pkgs ++
      map (x: pkgs.makeDesktopItem x) (import ./desktop-extra.nix pkgs) ++ [
        config.boot.kernelPackages.perf
      ];
  };

  fonts = {
    enableDefaultPackages = true;
    packages = import ./fonts.nix pkgs;
  };


  networking.firewall.allowedUDPPorts = [ 9993 25565 22 42000 42001 ];
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
