{ pkgs, ... }:

let
  domain = "evolution.2k2pea.ch";
  port = 8081;
  dataDir = "/var/lib/evolution";
  envFile = "${dataDir}/evolution.env";
in
{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "evolution" ];
    ensureUsers = [
      {
        name = "evolution";
        ensureDBOwnership = true;
      }
    ];
    authentication = ''
      host evolution evolution 127.0.0.1/32 trust
      host evolution evolution ::1/128 trust
    '';
  };

  services.redis.servers.evolution = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1";
  };

  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  systemd.tmpfiles.rules = [
    "d '${dataDir}' 0750 root root - -"
    "d '${dataDir}/instances' 0750 root root - -"
  ];

  systemd.services.evolution-env-init = {
    description = "Generate Evolution API env file";
    wantedBy = [ "multi-user.target" ];
    before = [ "docker-evolution-api.service" ];
    path = [ pkgs.openssl pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = /* sh */ ''
      if [ ! -f "${envFile}" ]; then
        KEY=$(openssl rand -hex 32)
        printf 'AUTHENTICATION_API_KEY=%s\n' "$KEY" > "${envFile}"
        chmod 0600 "${envFile}"
        echo "Evolution API key written to ${envFile}"
      fi
    '';
  };

  virtualisation.oci-containers.containers.evolution-api = {
    image = "evoapicloud/evolution-api:latest";
    extraOptions = [ "--network=host" ];
    volumes = [ "${dataDir}/instances:/evolution/instances" ];
    environmentFiles = [ envFile ];
    environment = {
      SERVER_NAME = "evolution";
      SERVER_TYPE = "http";
      SERVER_PORT = toString port;
      SERVER_URL = "https://${domain}";

      DATABASE_PROVIDER = "postgresql";
      DATABASE_CONNECTION_URI = "postgresql://evolution@127.0.0.1:5432/evolution";
      DATABASE_CONNECTION_CLIENT_NAME = "evolution";
      DATABASE_SAVE_DATA_INSTANCE = "true";
      DATABASE_SAVE_DATA_NEW_MESSAGE = "true";
      DATABASE_SAVE_MESSAGE_UPDATE = "true";
      DATABASE_SAVE_DATA_CONTACTS = "true";
      DATABASE_SAVE_DATA_CHATS = "true";
      DATABASE_SAVE_DATA_HISTORIC = "true";

      CACHE_REDIS_ENABLED = "true";
      CACHE_REDIS_URI = "redis://127.0.0.1:6379";
      CACHE_REDIS_PREFIX_KEY = "evolution-cache";
      CACHE_LOCAL_ENABLED = "true";

      CORS_ORIGIN = "*";
      CORS_METHODS = "POST,GET,PUT,DELETE";
      CORS_CREDENTIALS = "true";

      LANGUAGE = "en";
      CONFIG_SESSION_PHONE_CLIENT = "Evolution API";
      CONFIG_SESSION_PHONE_NAME = "Chrome";
      QRCODE_LIMIT = "30";
      WEBSOCKET_ENABLED = "true";
      TELEMETRY_ENABLED = "false";
      SERVER_DISABLE_DOCS = "false";
      SERVER_DISABLE_MANAGER = "false";
      DEL_INSTANCE = "false";
      N8N_ENABLED = "true";
      LOG_LEVEL = "ERROR,WARN,INFO,LOG,WEBHOOKS,WEBSOCKET";
      LOG_COLOR = "false";
      LOG_BAILEYS = "error";
    };
  };

  systemd.services.docker-evolution-api = {
    after = [ "evolution-env-init.service" ];
    wants = [ "evolution-env-init.service" ];
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
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
