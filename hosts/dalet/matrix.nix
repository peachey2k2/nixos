{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  domain = "2k2pea.ch";
  matrixDomain = "mx.${domain}";
  matrixRtcUrl = "https://${matrixDomain}/livekit/jwt";

  # This address is assigned directly to dalet's wan interface. Advertising it
  # explicitly keeps LiveKit from offering unroutable interface addresses as
  # ICE candidates.
  publicIPv4 = "159.195.248.150";

  livekitPort = 7880;
  livekitTcpPort = 7881;
  livekitUdpPortStart = 50100;
  livekitUdpPortEnd = 50200;
  # NOTE: 8081 is taken by evolution-api (host-networked, see evolution.nix)
  # and 8080 by stalwart JMAP (see mail.nix). Loopback-only, nginx fronts it.
  livekitJwtPort = 8090;
  livekitKeyFile = "/var/lib/matrix-rtc/livekit-keys";

  clientWellKnown = builtins.toJSON {
    "m.homeserver".base_url = "https://${matrixDomain}";
    "org.matrix.msc4143.rtc_foci" = [
      {
        type = "livekit";
        livekit_service_url = matrixRtcUrl;
      }
    ];
  };
in
{
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

        # Tuwunel uses this for both its MatrixRTC transports endpoint and its
        # own client well-known response. The apex-domain response below must
        # advertise the same URL because that is the server_name clients query.
        livekit_url = matrixRtcUrl;
      };

      # btrfs doesn't go well with RocksDB fallocate
      rocksdb_allow_fallocate = false;
    };
  };

  # Both services consume the same `key: secret` file through systemd
  # credentials, so the secret never enters the Nix store. Generate it once on
  # the host and retain it across rebuilds.
  systemd.services.matrix-rtc-secrets = {
    description = "Provision MatrixRTC LiveKit credentials";
    before = [
      "livekit.service"
      "lk-jwt-service.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      install -d -m 0700 /var/lib/matrix-rtc

      if [ ! -e ${livekitKeyFile} ]; then
        key="$(${pkgs.openssl}/bin/openssl rand -hex 10)"
        secret="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
        printf '%s: %s\n' "$key" "$secret" > ${livekitKeyFile}
      fi

      if ! ${pkgs.gnugrep}/bin/grep -Eq '^[0-9a-f]{20}: [0-9a-f]{64}$' ${livekitKeyFile}; then
        echo '${livekitKeyFile} is not a valid LiveKit key file' >&2
        exit 1
      fi

      chmod 0600 ${livekitKeyFile}
    '';
  };

  services.livekit = {
    enable = true;
    keyFile = livekitKeyFile;
    settings = {
      port = livekitPort;
      bind_addresses = [ "" ];
      rtc = {
        tcp_port = livekitTcpPort;
        port_range_start = livekitUdpPortStart;
        port_range_end = livekitUdpPortEnd;
        use_external_ip = false;
        node_ip = publicIPv4;
        enable_loopback_candidate = false;
      };

      # lk-jwt-service creates authorized rooms explicitly. Leaving LiveKit's
      # default auto-create enabled would let restricted remote users bypass
      # that policy.
      room.auto_create = false;
    };
  };

  services.lk-jwt-service = {
    enable = true;
    keyFile = livekitKeyFile;
    livekitUrl = "wss://${matrixDomain}/livekit/sfu";
    port = livekitJwtPort;
  };

  systemd.services.livekit = {
    requires = [ "matrix-rtc-secrets.service" ];
    after = [ "matrix-rtc-secrets.service" ];
  };

  systemd.services.lk-jwt-service = {
    requires = [ "matrix-rtc-secrets.service" ];
    after = [ "matrix-rtc-secrets.service" ];
    environment = {
      LIVEKIT_JWT_BIND = lib.mkForce "127.0.0.1:${toString livekitJwtPort}";
      LIVEKIT_FULL_ACCESS_HOMESERVERS = domain;
    };
  };

  networking.firewall = {
    # LiveKit signalling goes through nginx on 443. WebRTC media needs a
    # direct encrypted TCP/UDP path to the SFU.
    allowedTCPPorts = [ livekitTcpPort ];
    allowedUDPPortRanges = [
      {
        from = livekitUdpPortStart;
        to = livekitUdpPortEnd;
      }
    ];
  };

  services.nginx.virtualHosts.${domain} = {
    locations."= /.well-known/matrix/server".extraConfig = ''
      default_type application/json;
      add_header Access-Control-Allow-Origin "*" always;
      return 200 '{"m.server":"${matrixDomain}:443"}';
    '';

    locations."= /.well-known/matrix/client".extraConfig = ''
      default_type application/json;
      add_header Access-Control-Allow-Origin "*" always;
      return 200 '${clientWellKnown}';
    '';
  };

  services.nginx.virtualHosts.${matrixDomain} = {
    enableACME = true;
    forceSSL = true;

    extraConfig = ''
      client_max_body_size 100M;
    '';

    locations = {
      # MatrixRTC authorization service. The trailing slash on proxyPass strips
      # /livekit/jwt/ before forwarding, as required by lk-jwt-service.
      "^~ /livekit/jwt/" = {
        proxyPass = "http://127.0.0.1:${toString livekitJwtPort}/";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Server $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };

      # LiveKit WebSocket signalling. WebRTC media continues over the direct
      # TCP/UDP ports opened above.
      "^~ /livekit/sfu/" = {
        proxyPass = "http://127.0.0.1:${toString livekitPort}/";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header Connection "upgrade";
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Server $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_buffering off;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
        '';
      };

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
}
