{
  lib,
  ...
}:

let
  domain = "2k2pea.ch";
  mailDomain = "mail.${domain}";
in
{
  services.stalwart = {
    enable = true;
    stateVersion = "26.11";

    # Only the fallback admin is Nix-managed. Mailbox passwords live in
    # stalwart's internal directory (RocksDB) and are set via webadmin
    # Directory -> Accounts, so rebuilds never stomp them.
    credentials = {
      admin-pw = "/var/lib/stalwart-secrets/admin-pw";
    };

    settings = {
      server = {
        hostname = mailDomain;

        tls = {
          enable = true;
          implicit = false;
          certificate = "nixos-acme";
        };

        listener = {
          smtp = {
            bind = [ "[::]:25" ];
            protocol = "smtp";
          };
          submission = {
            bind = [ "[::]:587" ];
            protocol = "smtp";
          };
          submissions = {
            bind = [ "[::]:465" ];
            protocol = "smtp";
            tls.implicit = true;
          };
          imap = {
            bind = [ "[::]:143" ];
            protocol = "imap";
          };
          imaps = {
            bind = [ "[::]:993" ];
            protocol = "imap";
            tls.implicit = true;
          };
          jmap = {
            bind = [ "127.0.0.1:8080" ];
            protocol = "http";
            url = "https://${mailDomain}";
          };
        };
      };

      certificate."nixos-acme" = {
        cert = "%{file:/var/lib/acme/${mailDomain}/fullchain.pem}%";
        private-key = "%{file:/var/lib/acme/${mailDomain}/key.pem}%";
      };

      lookup.default = {
        hostname = mailDomain;
        domain = domain;
      };

      session.auth = {
        mechanisms = "[plain]";
        directory = "'internal'";
      };
      session.rcpt.directory = "'internal'";

      authentication.fallback-admin = {
        user = "admin";
        secret = "%{file:/run/credentials/stalwart.service/admin-pw}%";
      };

      http = {
        # NOTE: on the pinned 0.15.5 these are flat keys (newer upstream
        # uses an `http.*` object with usePermissiveCors/useXForwarded).
        permissive-cors = true;
        use-x-forwarded = true;
      };
    };
  };

  security.acme.certs.${mailDomain} = {
    reloadServices = [ "stalwart.service" ];
  };
  users.users.stalwart.extraGroups = [ "nginx" ];

  security.acme.defaults.email = lib.mkForce "postmaster@${domain}";

  networking.firewall.allowedTCPPorts = [
    25 # SMTP
    465 # submissions
    587 # submission
    143 # imap (STARTTLS)
    993 # imaps
  ];

  services.nginx.virtualHosts.${mailDomain} = {
    enableACME = true;
    forceSSL = true;

    extraConfig = ''
      client_max_body_size 50M;
    '';

    locations."= /.well-known/mta-sts.txt".extraConfig = ''
      default_type text/plain;
      return 200 "version: STSv1\nmode: enforce\nmx: ${mailDomain}\nmax_age: 86400\n";
    '';

    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      extraConfig = ''
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };

  services.nginx.virtualHosts."mta-sts.${domain}" = {
    enableACME = true;
    forceSSL = true;

    locations."= /.well-known/mta-sts.txt".extraConfig = ''
      default_type text/plain;
      return 200 "version: STSv1\nmode: enforce\nmx: ${mailDomain}\nmax_age: 86400\n";
    '';

    locations."/".extraConfig = ''
      return 404;
    '';
  };

  # larpmail.${domain} is served by Bulwark Webmail (see bulwark.nix).
}
