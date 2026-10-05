# Tailscale client on aleph. Login is interactive:
#   tailscale up
# then authenticate as tailscale@2k2pea.ch (Pocket ID).
# Exit node is toggled from the nilshell dashboard ("Opsec Mode" button).
# (extraSetFlags --operator=me lets cli/dashboard manage tailscaled without sudo.)
{ username, ... }:
{
  services.tailscale = {
    enable = true;
    # Opens UDP 41641.
    openFirewall = true;
    # "client" also relaxes reverse-path filtering for WG traffic.
    useRoutingFeatures = "client";
    extraSetFlags = [ "--operator=${username}" ];
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
