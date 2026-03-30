# { config, lib, ... }:
{
  services.tailscale.enable = true;

    # networking.firewall = {
    #     # enable the firewall
    #     enable = true;

    #     # allow all ports from your Tailscale network
    #     trustedInterfaces = [ "tailscale0" ];
    #     #or allow you to SSH in over the public internet (run `sudo tailscale up --ssh --qr` to authenticate and enable tailscale ssh)
    #     # allowedTCPPorts = [ 22 ];

    #     # allow the Tailscale UDP port through the firewall
    #     allowedUDPPorts = [ config.services.tailscale.port ];
    # };

    # services.openssh = {
    #     enable = true;
    #     # require public key authentication for better security
    #     settings = {
    #         PasswordAuthentication = false;
    #         KbdInteractiveAuthentication = false;
    #     };
    #     #permitRootLogin = "yes";
    # };
}
