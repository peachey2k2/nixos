{ inputs, lib, ... }:

{
  imports = [ inputs.ncro.nixosModules.ncro ];

  services.ncro = {
    enable = true;
    settings = lib.importTOML ../ncro.toml;
  };

  nix.settings.substituters = lib.mkForce [ "http://127.0.0.1:8080" ];
  nix.settings.extra-substituters = lib.mkForce [ ];
}
