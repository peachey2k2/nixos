{ pkgs, hostname, ... }:

{
  security = {
    rtkit.enable = true;
    sudo.enable = false;

    polkit = {
      enable = true;
      package = pkgs.polkit;

      extraConfig = /* js */ ''
        polkit.addRule(function(action, subject) {
          if (
            subject.isInGroup("wheel") && (
              action.id.indexOf("org.freedesktop.systemd1.") == 0 ||
              action.id == "org.freedesktop.policykit.exec"
            )
          ) {
            return polkit.Result.AUTH_KEEP;
          }
        });
      '';
    };
  };

  networking = {
    hostName = hostname;
    networkmanager.enable = true;

    firewall =
      let
        allowedPorts = [
          9993
          25565
          22
          42000
          42001
        ];

        allowedPortRanges = [
          { from = 1714; to = 1764; }
        ];

      in {
        allowedTCPPorts = allowedPorts;
        allowedUDPPorts = allowedPorts;
        allowedTCPPortRanges = allowedPortRanges;
        allowedUDPPortRanges = allowedPortRanges;
      };
  };
}
