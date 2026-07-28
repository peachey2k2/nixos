{ pkgs, username, ... }:

{
  imports = [
    ./nix.nix
    ./boot.nix
    ./misc.nix
    ./locale.nix
    ./environment.nix
    ./fonts.nix
    ./obsidian.nix
    ./printing.nix
    ./security.nix
  ];

  users = {
    defaultUserShell = pkgs.nushell;
    users.${username} = {
      isNormalUser = true;
      shell = pkgs.nushell;
      description = username;
      extraGroups = [
        "networkmanager" # manage network connections
        "wheel" # run0 access
        # "docker" # run Docker without sudo
        "video" # access GPU/video devices
        "libvirtd" # manage local VMs
        "seat" # seat/session device access
        "dialout" # access serial devices
        "lpadmin" # manage printers
        "wireshark" # wireshark access
      ];
      packages = [ ];
    };
  };

  # no touching
  system.stateVersion = "24.11"; # again, no touching
}
