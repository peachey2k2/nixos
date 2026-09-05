{ pkgs, username, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ./nix.nix
    ./boot.nix
    ./misc.nix
    ./locale.nix
    ./environment.nix
    ./fonts.nix
    ./obsidian.nix
    ./printing.nix
    ./security.nix
    ./network-triage.nix
  ];

  users = {
    defaultUserShell = pkgs.nushell;
    users.${username} = {
      isNormalUser = true;
      shell = pkgs.nushell;
      description = username;
      extraGroups = [
        "networkmanager"
        "wheel"
        "docker"
        "video"
        "libvirtd"
        "seat"
        "dialout"
        "lpadmin"
        "wireshark"
      ];
      packages = [ ];
    };
  };

  services.udev.extraRules = ''
    # Ignore both built-in keyboard paths in libinput/Niri while leaving
    # external USB keyboards and the touchpad available.
    ACTION!="remove", SUBSYSTEM=="input", KERNEL=="event[0-9]*", ENV{ID_VENDOR_ID}=="048d", ENV{ID_MODEL_ID}=="c693", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    ACTION!="remove", SUBSYSTEM=="input", KERNEL=="event[0-9]*", ENV{ID_PATH}=="platform-i8042-serio-0", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';

  system.stateVersion = "24.11";
}
