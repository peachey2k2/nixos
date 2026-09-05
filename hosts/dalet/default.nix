{
  inputs,
  modulesPath,
  nixConfig,
  username,
  ...
}:

{
  imports = [
    inputs.disko.nixosModules.disko
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disko.nix
    ./nginx.nix
    ./blight.nix
  ];

  nix.settings = nixConfig;

  networking = {
    hostName = "dalet";
    useDHCP = false;
    interfaces.wan = {
      ipv4.addresses = [
        {
          address = "159.195.248.150";
          prefixLength = 22;
        }
      ];
      ipv6.addresses = [
        {
          address = "2a0a:4cc0:60:24b5:8814:d4ff:fe60:9d7c";
          prefixLength = 64;
        }
      ];
    };
    defaultGateway = {
      address = "159.195.248.1";
      interface = "wan";
    };
    defaultGateway6 = {
      address = "fe80::1";
      interface = "wan";
    };
    nameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };

  systemd.network.links."10-wan" = {
    matchConfig.PermanentMACAddress = "8a:14:d4:60:9d:7c";
    linkConfig.Name = "wan";
  };

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFKNIMY3c/4MmJTNWlRDFrJNvQf/ZHe5V0StB/sAS/Ab me@aleph"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  system.stateVersion = "26.11";
}
