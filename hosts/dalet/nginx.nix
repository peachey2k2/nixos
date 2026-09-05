{
  inputs,
  pkgs,
  ...
}:

let
  domain = "2k2pea.ch";
  matrixDomain = "mx.${domain}";
  cinnyDomain = "cinny.${domain}";

  cinnyUnwrapped = pkgs.cinny-unwrapped.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./cinny-authenticated-media.patch ];
  });

  cinny = pkgs.cinny.override {
    cinny-unwrapped = cinnyUnwrapped;
    pname = "cinny-2k2pea";
    conf = {
      defaultHomeserver = 0;
      homeserverList = [ domain ];
      allowCustomHomeservers = true;
    };
  };
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = null;
  };

  services.matrix-tuwunel = {
    enable = true;

    settings.global = {
      log = "debug";
      server_name = domain; # rtfm

      address = [ "127.0.0.1" ];
      port = [ 6167 ];

      max_request_size = 100 * 1024 * 1024;
      ip_source = "rightmost_x_forwarded_for";

      allow_encryption = true;
      allow_federation = true;
      allow_registration = false;

      trusted_servers = [ "matrix.org" ];

      well_known = {
        client = "https://${matrixDomain}";
        server = "${matrixDomain}:443";
      };

      # btrfs doesn't go well with RocksDB fallocate
      rocksdb_allow_fallocate = false;
    };
  };

  services.nginx = {
    enable = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;
      root = inputs.website.packages.default;

      locations."= /.well-known/matrix/server".extraConfig = ''
        default_type application/json;
        add_header Access-Control-Allow-Origin "*" always;
        return 200 '{"m.server":"${matrixDomain}:443"}';
      '';

      locations."= /.well-known/matrix/client".extraConfig = ''
        default_type application/json;
        add_header Access-Control-Allow-Origin "*" always;
        return 200 '{"m.homeserver":{"base_url":"https://${matrixDomain}"}}';
      '';
    };

    virtualHosts.${cinnyDomain} = {
      enableACME = true;
      forceSSL = true;
      root = cinny;

      locations."/".extraConfig = ''
        try_files $uri $uri/ /index.html;
      '';
    };

    virtualHosts.${matrixDomain} = {
      enableACME = true;
      forceSSL = true;

      extraConfig = ''
        client_max_body_size 100M;
      '';

      locations = {
        "/_matrix/" = {
          proxyPass = "http://127.0.0.1:6167";
          extraConfig = ''
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
          '';
        };

        "/_tuwunel/" = {
          proxyPass = "http://127.0.0.1:6167";
        };

        # Served by Tuwunel using global.well_known above.
        "/.well-known/matrix/" = {
          proxyPass = "http://127.0.0.1:6167";
        };
      };
    };
  };
}

