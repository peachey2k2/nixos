{ inputs, ... }:

let
  domain = "2k2pea.ch";
in
{
  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    root = inputs.website.packages.default;
  };
}
