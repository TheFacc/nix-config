# RustDesk host: lets this machine be viewed/controlled from other RustDesk clients.
# Connections go direct over Tailscale (Direct IP access, TCP 21118), no ID/relay server.
#
# Upstream ships a root `rustdesk --service` unit that spawns `--server` in the
# user session via sudo; nixpkgs ships no unit. Running `--server` directly as a
# user service in the graphical session is simpler and unprivileged (Wayland can't
# serve the login screen anyway).
#
# Manual, one-time (stored in ~/.config/rustdesk, RustDesk rewrites it at runtime):
#   Settings > Security > enable "Direct IP access", set a permanent password.
{ pkgs, ... }:
let
  rustdesk = pkgs.rustdesk-flutter;
in
{
  imports = [ ./rustdesk.nix ];

  systemd.user.services.rustdesk = {
    description = "RustDesk server (accept incoming connections)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ pkgs.procps pkgs.which ];
    serviceConfig = {
      ExecStart = "${rustdesk}/bin/rustdesk --server";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Only reachable from the tailnet, never from LAN/internet.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 21118 ];
}
