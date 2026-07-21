{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix

    ../../modules/system
  ];
}
