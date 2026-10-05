{ inputs, pkgs, ... }:

let
  domain = "cinny.2k2pea.ch";
  domain2 = "cinny2.2k2pea.ch";
  port = 8787;

  cinny = inputs.cinny.packages.${pkgs.stdenv.hostPlatform.system}.cinny.override {
    enableEmbeds = true;
    conf = {
      defaultHomeserver = 0;
      homeserverList = [ "2k2pea.ch" ];
      allowCustomHomeservers = true;
    };
  };

  previewProxy = {
    proxyPass = "http://127.0.0.1:${toString port}";
    recommendedProxySettings = false;
    extraConfig = ''
      proxy_http_version 1.1;
      proxy_set_header Host $host;
      proxy_set_header Connection "";
      proxy_set_header Origin $http_origin;
      proxy_set_header Authorization "";
      proxy_set_header Cookie "";
      proxy_set_header Proxy-Authorization "";
      proxy_set_header X-Forwarded-For "";
      proxy_set_header X-Real-IP "";
      proxy_connect_timeout 3s;
      proxy_read_timeout 25s;
      proxy_send_timeout 25s;
      proxy_next_upstream off;
      proxy_redirect off;
      client_max_body_size 8k;
    '';
  };
in
{
  systemd.services.cinny-embeds = {
    wantedBy = [ "multi-user.target" ];
    environment = {
      ORIGIN = "https://${domain}";
      PORT = toString port;
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    serviceConfig = {
      ExecStart = "${cinny}/bin/cinny-embeds";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    root = "${cinny}/share/cinny";
    locations = {
      "= /_cinny/preview" = previewProxy;
      "^~ /_cinny/preview/media/" = previewProxy;
      "/_cinny/".return = "404";
      "/assets/".extraConfig = ''
        try_files $uri =404;
        expires 1y;
      '';
      "= /index.html".extraConfig = "expires -1;";
      "/".tryFiles = "$uri $uri/ /index.html";
    };
  };

  services.nginx.virtualHosts.${domain2} = {
    enableACME = true;
    forceSSL = true;
    root = inputs.matrix-client.packages.${pkgs.stdenv.hostPlatform.system}.matrix-client.override {
      conf = {
        defaultHomeserver = 0;
        homeserverList = [ "2k2pea.ch" ];
        allowCustomHomeservers = true;
      };
    };
    locations = {
      "= /config.json".extraConfig = ''
        expires -1;
        add_header Cache-Control "no-store" always;
      '';
      "= /index.html".extraConfig = "expires -1;";
      "/_app/immutable/".extraConfig = ''
        expires 1y;
        add_header Cache-Control "public, immutable" always;
      '';
      "/element-call/assets/".extraConfig = ''
        expires 1y;
        add_header Cache-Control "public, immutable" always;
      '';
      "^~ /element-call/".extraConfig = ''
        try_files $uri $uri/ =404;
        expires -1;
      '';
      "/".tryFiles = "$uri $uri/ /index.html";
    };
  };
}
