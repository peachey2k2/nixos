{ pkgs, ... }:

let
  domain = "larpmail.2k2pea.ch";
  port = 3000;
  image = "ghcr.io/bulwarkmail/webmail:1.9.2";
  jmapUrl = "https://mail.2k2pea.ch";
  dataDir = "/var/lib/bulwark-webmail";
  envFile = "${dataDir}/session.env";
in
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  systemd.tmpfiles.rules = [
    "d '${dataDir}' 0750 root root - -"
    "d '${dataDir}/settings' 0750 root root - -"
    "d '${dataDir}/admin' 0750 root root - -"
    "d '${dataDir}/admin-state' 0750 root root - -"
    "d '${dataDir}/telemetry' 0750 root root - -"
  ];

  systemd.services.bulwark-env-init = {
    description = "Generate Bulwark Webmail session secret";
    wantedBy = [ "multi-user.target" ];
    before = [ "docker-bulwark-webmail.service" ];
    path = [ pkgs.openssl pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = /* sh */ ''
      if [ ! -f "${envFile}" ]; then
        SECRET=$(openssl rand -base64 32)
        printf 'SESSION_SECRET=%s\n' "$SECRET" > "${envFile}"
        chmod 0600 "${envFile}"
        echo "Bulwark session secret written to ${envFile}"
      fi
    '';
  };

  virtualisation.oci-containers.containers.bulwark-webmail = {
    image = image;
    extraOptions = [ "--network=host" ];
    volumes = [
      "${dataDir}/settings:/app/data/settings"
      "${dataDir}/admin:/app/data/admin"
      "${dataDir}/admin-state:/app/data/admin-state"
      "${dataDir}/telemetry:/app/data/telemetry"
    ];
    environmentFiles = [ envFile ];
    environment = {
      HOSTNAME = "0.0.0.0";
      PORT = toString port;
      JMAP_SERVER_URL = jmapUrl;
      STALWART_FEATURES = "true";

      SETTINGS_SYNC_ENABLED = "true";
      SETTINGS_DATA_DIR = "/app/data/settings";

      ADMIN_CONFIG_DIR = "/app/data/admin";
      ADMIN_STATE_DIR = "/app/data/admin-state";

      BULWARK_TELEMETRY = "off";
      TELEMETRY_DATA_DIR = "/app/data/telemetry";

      LOG_FORMAT = "text";
      LOG_LEVEL = "info";
    };
  };

  systemd.services.docker-bulwark-webmail = {
    after = [ "bulwark-env-init.service" ];
    wants = [ "bulwark-env-init.service" ];
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;

    extraConfig = ''
      client_max_body_size 50M;
    '';

    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      extraConfig = ''
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
      '';
    };
  };
}
