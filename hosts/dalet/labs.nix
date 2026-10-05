{ inputs, pkgs, ... }:

let
  domain = "labs.2k2pea.ch";
  ae2-sim = inputs.ae2-sim.packages.${pkgs.stdenv.hostPlatform.system}.site;
in
{
  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations = {
      # The sim loads its assets relative to the page, so it needs the trailing slash.
      "= /ae2".return = "301 /ae2/";
      "/ae2/" = {
        alias = "${ae2-sim}/";
        index = "index.html";
      };
      "/ae2/assets/".extraConfig = ''
        alias ${ae2-sim}/assets/;
        expires 1y;
        add_header Cache-Control "public, immutable" always;
      '';
      "/".return = "404";
    };
  };
}
