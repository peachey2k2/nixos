{ pkgs, ... }:

let
  domain = "n8n.2k2pea.ch";
  port = 5678;
  secretsDir = "/var/lib/n8n-secrets";
  encryptionKeyFile = "${secretsDir}/encryption_key";

  assistantDir = "/var/lib/n8n-assistant";
  assistantEnvFile = "${assistantDir}/sandbox.env";
  assistantN8nEnvFile = "${assistantDir}/n8n.env";
  tlsDir = "${assistantDir}/tls";
  sandboxNetwork = "n8n-sandbox-net";
  sandboxApiImage = "ghcr.io/n8n-io/n8n-sandbox-service-api:1.2.0";
  sandboxRunnerImage = "ghcr.io/n8n-io/n8n-sandbox-service-runner-dind:1.2.0";
  sandboxExecImage = "ghcr.io/n8n-io/n8n-sandbox-service-sandbox:latest";
  sandboxApiHostPort = 8380;
  sandboxApiUrl = "http://127.0.0.1:${toString sandboxApiHostPort}";

  customNodesDir = pkgs.linkFarm "n8n-custom-nodes" [
    {
      name = pkgs.n8n-nodes-evolution-api.pname;
      path = "${pkgs.n8n-nodes-evolution-api}/lib/node_modules/${pkgs.n8n-nodes-evolution-api.pname}";
    }
  ];
in
{
  systemd.tmpfiles.rules = [
    "d '${secretsDir}' 0750 root root - -"
    "d '${assistantDir}' 0750 root root - -"
    "d '${tlsDir}' 0755 root root - -"
  ];

  systemd.services.n8n-secrets-init = {
    description = "Generate n8n secrets";
    wantedBy = [ "multi-user.target" ];
    before = [
      "n8n.service"
      "sandbox-certs.service"
      "docker-sandbox-api.service"
      "docker-sandbox-runner-1.service"
    ];
    path = [ pkgs.openssl pkgs.coreutils pkgs.gnugrep pkgs.gnused ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -f "${encryptionKeyFile}" ]; then
        openssl rand -hex 32 > "${encryptionKeyFile}"
        chmod 0600 "${encryptionKeyFile}"
        echo "n8n encryption key written to ${encryptionKeyFile}"
      fi
      if [ ! -f "${assistantEnvFile}" ]; then
        API_KEY=$(openssl rand -hex 24)
        REG_TOKEN=$(openssl rand -hex 24)
        RUNNER_KEY=$(openssl rand -hex 24)
        printf 'SANDBOX_API_KEYS=%s\n' "$API_KEY" > "${assistantEnvFile}"
        printf 'SANDBOX_API_RUNNER_REGISTRATION_TOKEN=%s\n' "$REG_TOKEN" >> "${assistantEnvFile}"
        printf 'SANDBOX_API_RUNNER_API_KEY=%s\n' "$RUNNER_KEY" >> "${assistantEnvFile}"
        printf 'SANDBOX_RUNNER_API_KEYS=%s\n' "$RUNNER_KEY" >> "${assistantEnvFile}"
        printf 'SANDBOX_RUNNER_REGISTRATION_TOKEN=%s\n' "$REG_TOKEN" >> "${assistantEnvFile}"
        chmod 0600 "${assistantEnvFile}"
        echo "n8n sandbox secrets written to ${assistantEnvFile}"
      fi
      if [ ! -f "${assistantN8nEnvFile}" ]; then
        API_KEY=$(sed -n 's/^SANDBOX_API_KEYS=//p' "${assistantEnvFile}")
        printf 'N8N_SANDBOX_SERVICE_API_KEY=%s\n' "$API_KEY" > "${assistantN8nEnvFile}"
        chmod 0600 "${assistantN8nEnvFile}"
        echo "n8n assistant env written to ${assistantN8nEnvFile} (add N8N_INSTANCE_AI_MODEL_API_KEY there)"
      fi
    '';
  };

  services.n8n = {
    enable = true;

    # Evolution API nodes in the palette, alongside the built-in
    # Schedule / Webhook / HTTP / Code / AI nodes you'll use for
    # the daily-summaries workflow.
    customNodes = with pkgs; [
      n8n-nodes-evolution-api
    ];

    environment = {
      N8N_PORT = port;
      N8N_LISTEN_ADDRESS = "127.0.0.1";
      N8N_PROTOCOL = "https";
      N8N_HOST = domain;
      WEBHOOK_URL = "https://${domain}/";
      N8N_EDITOR_BASE_URL = "https://${domain}/";
      N8N_ENCRYPTION_KEY_FILE = encryptionKeyFile;

      # n8n Assistant (instance-ai): self-hosted code-execution sandbox
      # plus a custom OpenAI-compatible model endpoint.
      # The sandbox API key and the model API key live in
      # /var/lib/n8n-assistant/n8n.env (see EnvironmentFile below),
      # never in the nix store.
      N8N_INSTANCE_AI_SANDBOX_ENABLED = "true";
      N8N_INSTANCE_AI_SANDBOX_PROVIDER = "n8n-sandbox";
      N8N_INSTANCE_AI_SANDBOX_IMAGE = sandboxExecImage;
      N8N_INSTANCE_AI_SANDBOX_API_URL = sandboxApiUrl;
      N8N_SANDBOX_SERVICE_URL = sandboxApiUrl;
      # Leave the model unset so it can be selected and changed in n8n's web UI.
      N8N_INSTANCE_AI_MODEL_URL = "https://slop.amaanq.com/v1";
    };
  };

  systemd.services.n8n = {
    after = [
      "n8n-secrets-init.service"
      "docker-sandbox-api.service"
    ];
    wants = [
      "n8n-secrets-init.service"
      "docker-sandbox-api.service"
    ];
    serviceConfig.EnvironmentFile = [ assistantN8nEnvFile ];
  };

  # Internal docker network so sandbox-api and sandbox-runner-1 resolve
  # each other by name (mTLS certs are issued for those names).
  systemd.services.sandbox-network = {
    description = "Create n8n sandbox docker network";
    after = [ "docker.service" ];
    wants = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    before = [
      "docker-sandbox-api.service"
      "docker-sandbox-runner-1.service"
    ];
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker network inspect "${sandboxNetwork}" >/dev/null 2>&1 || docker network create "${sandboxNetwork}"
    '';
  };

  systemd.services.sandbox-certs = {
    description = "Generate n8n sandbox mTLS certificates";
    after = [
      "docker.service"
      "n8n-secrets-init.service"
      "sandbox-network.service"
    ];
    wants = [
      "docker.service"
      "n8n-secrets-init.service"
    ];
    wantedBy = [ "multi-user.target" ];
    before = [
      "docker-sandbox-api.service"
      "docker-sandbox-runner-1.service"
    ];
    path = [ pkgs.docker pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -f "${tlsDir}/api/ca.crt" ]; then
        docker run --rm --user 0:0 --entrypoint sh \
          -e NUM_RUNNERS=1 \
          -v "${tlsDir}:/tls" \
          "${sandboxApiImage}" -c \
          'bootstrap-mtls.sh --out-dir /tls --api-san sandbox-api --control-san-prefix sandbox-runner --world-readable && chown -R sandbox-api:sandbox-api /tls/api && chmod -R a+rX /tls'
        chmod -R a+rX "${tlsDir}"
        echo "sandbox mTLS certs written to ${tlsDir}"
      fi
    '';
  };

  virtualisation.oci-containers.containers = {
    sandbox-api = {
      image = sandboxApiImage;
      hostname = "sandbox-api";
      volumes = [ "${tlsDir}:/tls:ro" ];
      environmentFiles = [ assistantEnvFile ];
      environment = {
        SANDBOX_API_GRPC_TLS_CERT_FILE = "/tls/api/grpc-server.crt";
        SANDBOX_API_GRPC_TLS_KEY_FILE = "/tls/api/grpc-server.key";
        SANDBOX_API_GRPC_TLS_CLIENT_CA_FILE = "/tls/api/ca.crt";
        SANDBOX_API_RUNNER_CONTROL_GRPC_TLS_CA_FILE = "/tls/api/ca.crt";
        SANDBOX_API_RUNNER_CONTROL_GRPC_TLS_CERT_FILE = "/tls/api/control-grpc-api-client.crt";
        SANDBOX_API_RUNNER_CONTROL_GRPC_TLS_KEY_FILE = "/tls/api/control-grpc-api-client.key";
        SANDBOX_API_RUNNER_CONTROL_GRPC_TLS_SERVER_NAME = "sandbox-runner-1";
      };
      extraOptions = [
        "--network=${sandboxNetwork}"
        "--publish=127.0.0.1:${toString sandboxApiHostPort}:8080"
      ];
    };
    sandbox-runner-1 = {
      image = sandboxRunnerImage;
      hostname = "sandbox-runner-1";
      volumes = [ "${tlsDir}:/tls:ro" ];
      environmentFiles = [ assistantEnvFile ];
      environment = {
        SANDBOX_RUNNER_API_GRPC_ADDR = "sandbox-api:9090";
        SANDBOX_RUNNER_HTTP_BASE_URL = "http://sandbox-runner-1:8080";
        SANDBOX_RUNNER_CONTROL_GRPC_LISTEN_ADDR = ":9091";
        SANDBOX_RUNNER_CONTROL_GRPC_ADVERTISE_ADDR = "sandbox-runner-1:9091";
        SANDBOX_RUNNER_ID = "runner-1";
        SANDBOX_RUNNER_DOCKER_SANDBOX_IMAGE = sandboxExecImage;
        SANDBOX_RUNNER_REGISTRATION_GRPC_CA_FILE = "/tls/runner/ca.crt";
        SANDBOX_RUNNER_REGISTRATION_GRPC_CERT_FILE = "/tls/runner/grpc-client.crt";
        SANDBOX_RUNNER_REGISTRATION_GRPC_KEY_FILE = "/tls/runner/grpc-client.key";
        SANDBOX_RUNNER_REGISTRATION_GRPC_SERVER_NAME = "sandbox-api";
        SANDBOX_RUNNER_CONTROL_GRPC_TLS_CERT_FILE = "/tls/runner/control-grpc-server.crt";
        SANDBOX_RUNNER_CONTROL_GRPC_TLS_KEY_FILE = "/tls/runner/control-grpc-server.key";
        SANDBOX_RUNNER_CONTROL_GRPC_TLS_CLIENT_CA_FILE = "/tls/runner/ca.crt";
      };
      extraOptions = [
        "--network=${sandboxNetwork}"
        "--privileged"
      ];
    };
  };

  systemd.services.docker-sandbox-api = {
    after = [
      "sandbox-certs.service"
      "sandbox-network.service"
      "n8n-secrets-init.service"
    ];
    wants = [
      "sandbox-certs.service"
      "sandbox-network.service"
      "n8n-secrets-init.service"
    ];
  };

  systemd.services.docker-sandbox-runner-1 = {
    after = [
      "sandbox-certs.service"
      "sandbox-network.service"
      "n8n-secrets-init.service"
      "docker-sandbox-api.service"
    ];
    wants = [
      "sandbox-certs.service"
      "sandbox-network.service"
      "n8n-secrets-init.service"
    ];
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
        # Required for n8n's live execution / push UI (websocket).
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };
}
