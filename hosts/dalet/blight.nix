{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  domain = "blight.2k2pea.ch";
  port = 8787;
  enableEmbeds = true;
  blight = inputs.blight.packages.${pkgs.stdenv.hostPlatform.system}.blight.override {
    inherit enableEmbeds;
  };

  # Exact page, redirect and media/CDN hosts only; no implicit subdomains.
  # Add reviewed sites here as needed. Unsupported sites show an actionable error.
  embedHosts = [
    "github.com"
    "opengraph.githubassets.com"
    "youtube.com"
    "www.youtube.com"
    "youtu.be"
    "i.ytimg.com"
    "x.com"
    "www.x.com"
    "twitter.com"
    "www.twitter.com"
    "pbs.twimg.com"
    "video.twimg.com"
  ];

  previewLocation = {
    proxyPass = "http://127.0.0.1:${toString port}";
    # Define headers/timeouts locally, instead of inheriting Matrix defaults.
    recommendedProxySettings = false;
    extraConfig = ''
      proxy_http_version 1.1;
      proxy_set_header Host $host;
      proxy_set_header Connection "";
      proxy_set_header Origin $http_origin;
      # Preserve Cookie/Authorization so the backend can reject mistakes.
      # Do not forward a synthetic client identity: backend trusts its socket only.
      proxy_set_header X-Forwarded-For "";
      proxy_set_header X-Real-IP "";
      proxy_connect_timeout 3s;
      proxy_send_timeout 25s;
      proxy_read_timeout 25s;
      proxy_next_upstream off;
      proxy_redirect off;
      proxy_cache off;
      proxy_buffering off;
      proxy_request_buffering off;
      proxy_max_temp_file_size 0;
      client_max_body_size 8k;
      client_body_buffer_size 16k;
      client_body_timeout 10s;
      max_ranges 0;
      access_log off;
      error_log /dev/null crit;
      limit_req zone=blight_embeds_requests burst=10 nodelay;
      limit_req_status 429;
      limit_conn blight_embeds_connections 4;
      limit_conn_status 429;
    '';
  };
in
{
  # Blight now exports a package, not the old Rust-era nixosModules.blight.
  systemd.services.blight-embeds = lib.mkIf enableEmbeds {
    description = "Blight preview-only embed backend";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    startLimitIntervalSec = 60;
    startLimitBurst = 3;
    environment = {
      ORIGIN = "https://${domain}";
      PORT = toString port;
      EMBED_ALLOWED_HOSTS = lib.concatStringsSep "," embedHosts;
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    serviceConfig = {
      ExecStart = "${blight}/bin/blight-embeds";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 10;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      # Node/V8 needs JIT memory and DNS/outbound HTTPS; do not enable
      # MemoryDenyWriteExecute or PrivateNetwork for this service.
      MemoryMax = "1G";
      TasksMax = 64;
      LimitNOFILE = 256;
    };
  };

  services.nginx = {
    enable = true;
    appendHttpConfig = lib.optionalString enableEmbeds ''
      limit_req_zone $binary_remote_addr zone=blight_embeds_requests:1m rate=15r/m;
      limit_conn_zone $binary_remote_addr zone=blight_embeds_connections:1m;
    '';
    virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;
      root = "${blight}/share/blight";
      extraConfig = ''
        # Includes SSO callback queries as well as private preview capabilities.
        access_log off;
        error_log /dev/null crit;
        add_header X-Content-Type-Options nosniff always;
        add_header Referrer-Policy no-referrer always;
        add_header Content-Security-Policy "frame-ancestors 'none'" always;
      '';
      locations = {
        "/_blight/".return = "404";
        "= /index.html".extraConfig = ''
          expires -1;
        '';
        "/assets/".extraConfig = ''
          try_files $uri =404;
          expires 1y;
        '';
        "/".tryFiles = "$uri $uri/ =404";
      }
      // lib.optionalAttrs enableEmbeds {
        "= /_blight/preview" = previewLocation;
        "^~ /_blight/preview/media/" = previewLocation;
      };
    };
  };
}
