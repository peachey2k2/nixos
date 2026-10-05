# Tailscale on dalet, advertised as an exit node.
#
# First-time setup (key never enters the Nix store):
#   1. Tailscale admin console -> Settings -> Keys -> Generate auth key
#      (reusable, no expiry for a server, optionally tagged).
#   2. On dalet: `printf 'tskey-auth-...' | sudo tee /var/lib/tailscale/authkey
#      && sudo chmod 600 /var/lib/tailscale/authkey`
#   3. Rebuild, then approve the exit node + routes in the admin console.
#
# Without /var/lib/tailscale/authkey the daemon still runs and you can
# `tailscale up` manually over SSH; state persists in /var/lib/tailscale.
{
  services.tailscale = {
    enable = true;
    # Opens UDP 41641.
    openFirewall = true;
    # Enables IP forwarding so dalet can route as an exit node.
    useRoutingFeatures = "server";
    authKeyFile = "/var/lib/tailscale/authkey";
    extraUpFlags = [
      "--advertise-exit-node"
      "--hostname=dalet"
    ];
  };

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    # Tailscale's WireGuard traffic fails strict reverse-path filtering.
    checkReversePath = "loose";
  };

  systemd.tmpfiles.rules = [
    "d '/var/lib/tailscale' 0750 root root - -"
  ];
}
