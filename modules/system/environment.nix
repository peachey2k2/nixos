{
  config,
  pkgs,
  inputs,
  system,
  homeDirectory,
  username,
  ...
}@moduleArgs:

{
  services = {
    blueman.enable = true;

    thermald.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    switcherooControl.enable = true;
    upower.enable = true;
    gvfs.enable = true;
    gnome.gnome-keyring.enable = true;

    suricata = {
      enable = true;

      enabledSources = [
        "abuse.ch/sslbl-blacklist"
        "abuse.ch/sslbl-c2"
        "abuse.ch/sslbl-ja3"
        "et/open"
      ];

      settings = {
        vars.address-groups.HOME_NET = "192.168.1.0/24";

        pcap = [
          { interface = "wlp0s9"; }
        ];

        outputs = [
          {
            eve-log = {
              enabled = true;
              filetype = "regular";
              filename = "eve.json";
              community-id = true;
              types = [
                { alert = { }; }
                { dns = { }; }
                { tls = { }; }
                { flow = { }; }
              ];
            };
          }
        ];
      };
    };

    cron = {
      enable = true;
      systemCronJobs = [ ];
    };

    greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --cmd ${pkgs.niri}/bin/niri-session";
          user = "greeter";
        };
        initial_session = {
          command = "${pkgs.niri}/bin/niri-session";
          user = username;
        };
      };
    };

    openssh = {
      enable = true;
      ports = [ 22 ];
      settings = {
        PasswordAuthentication = true;
        AllowUsers = null;
        UseDns = true;
        X11Forwarding = false;
        PermitRootLogin = "yes";
      };
    };

    qemuGuest.enable = true;
    spice-vdagentd.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  systemd.user.services.reborder =
    let
      package = inputs.reborder.packages.${system}.default;
    in
    {
      description = "Hidden agent-owned Wayland compositor";
      wantedBy = [ "default.target" ];
      # Launched clients need the same applications available as the desktop session.
      path = [ config.system.path ];
      serviceConfig = {
        Type = "exec";
        ExecStart = "${package}/bin/reborder --width 1280 --height 720 --control %t/reborder.sock";
        ExecStop = "${package}/bin/reborderctl --control %t/reborder.sock shutdown";
        Restart = "on-failure";
        RestartSec = "2s";
        TimeoutStopSec = "5s";
      };
    };

  programs = {
    nix-ld.enable = true;
    steam.enable = true;
    xfconf.enable = true;

    ssh = {
      # just covering ground, some enterprise firewalls may block port 22
      extraConfig = ''
        Host github.com
          HostName ssh.github.com
          User git
          Port 443
      '';

      knownHosts."ssh.github.com:443" = {
        hostNames = [ "[ssh.github.com]:443" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
    };

    thunar.plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];

    niri = {
      enable = true;
      package = pkgs.niri;
    };

    obs-studio = {
      enable = true;
      enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        droidcam-obs
        input-overlay
      ];
    };

    virt-manager.enable = true;

    wireshark = {
      enable = true;
      package = pkgs.wireshark;
      usbmon.enable = true;
    };

    ydotool = {
      enable = true;
      group = "users";
    };
  };

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };

    docker.enable = true;
    spiceUSBRedirection.enable = true;
  };

  environment = {
    sessionVariables = {
      NIX_DIR = "${homeDirectory}/nixos";
      NIXOS_OZONE_WL = "1";
      GTK_THEME = "adw-gtk3-dark";
      QT_STYLE_OVERRIDE = "kvantum";
      KVANTUM_THEME = "KvGnomeDark";
      NIX_SYSTEM_PATH = "${homeDirectory}/nixos";
      NIX_CONFIG_PATH = "${homeDirectory}/nixos/configs";
      XDG_CONFIG_HOME = "${homeDirectory}/.config";
      EDITOR = "hx";
      VISUAL = "hx";
      SHELL = "${pkgs.nushell}/bin/nu";
    };

    shells = [
      pkgs.nushell
    ];

    systemPackages = [
      config.boot.kernelPackages.perf
    ]
    ++ import ./packages.nix moduleArgs
    ++ map (x: pkgs.makeDesktopItem x) (import ./desktop-extra.nix moduleArgs);
  };
}
