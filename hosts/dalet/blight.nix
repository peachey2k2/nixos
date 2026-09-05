{ inputs, ... }:

{
  imports = [
    inputs.blight.nixosModules.blight
  ];

  services.blight = {
    enable = true;
    hostname = "blight.2k2pea.ch";
    nginx.enableACME = true;
    nginx.forceSSL = true;
  };
}
