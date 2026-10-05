{ pkgs, ... }:

let
  domain = "2k2pea.ch";
  authDomain = "auth.${domain}";
  port = 1411;
  secretsDir = "/var/lib/pocket-id-secrets";
  encryptionKeyFile = "${secretsDir}/encryption_key";
in
{
  systemd.tmpfiles.rules = [
    "d '${secretsDir}' 0750 root pocket-id - -"
  ];

  systemd.services.pocket-id-secrets-init = {
    description = "Generate Pocket ID encryption key";
    wantedBy = [ "multi-user.target" ];
    before = [ "pocket-id.service" ];
    path = [ pkgs.openssl pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -f "${encryptionKeyFile}" ]; then
        openssl rand -base64 32 | tr -d '\n' > "${encryptionKeyFile}"
        chmod 0600 "${encryptionKeyFile}"
        chown root:pocket-id "${encryptionKeyFile}"
        echo "Pocket ID encryption key written to ${encryptionKeyFile}"
      fi
    '';
  };

  services.pocket-id = {
    enable = true;
    credentials = {
      ENCRYPTION_KEY = encryptionKeyFile;
    };
    settings = {
      APP_URL = "https://${authDomain}";
      TRUST_PROXY = true;
      HOST = "127.0.0.1";
      PORT = port;
    };
  };

  systemd.services.pocket-id = {
    after = [ "pocket-id-secrets-init.service" ];
    wants = [ "pocket-id-secrets-init.service" ];
  };

  services.nginx.virtualHosts.${authDomain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      extraConfig = ''
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
      '';
    };
  };

  # WebFinger on the apex domain. nginx matches the location without the
  # query string, so ?resource=acct:... still hits this block. Echo the
  # requested resource back as subject; Tailscale only checks the issuer href.
  services.nginx.virtualHosts.${domain}.locations."= /.well-known/webfinger".extraConfig = ''
    default_type application/jrd+json;
    add_header Access-Control-Allow-Origin "*" always;
    return 200 '{"subject":"$arg_resource","links":[{"rel":"http://openid.net/specs/connect/1.0/issuer","href":"https://${authDomain}"}]}';
  '';
}
