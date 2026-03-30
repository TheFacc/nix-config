# n8n
{ config, pkgs, lib, ... }:
let
  inherit (config.networking) hostName;
  nixexSops = (hostName == "nixex" && config.local.hasSopsSecrets);
in
{
  services.n8n = {
      enable = true;
      openFirewall = true;
  };

  # User and Group
  systemd.services.n8n.serviceConfig = {
    User = "n8n";
    Group = "n8n";
  };
  users.groups.n8n = {};
  users.users.n8n = {
    isSystemUser = true;
    group = "n8n";
  };

  # env
  sops.templates."n8n-env" = lib.mkIf (nixexSops) {
    content = ''
      N8N_PORT=${config.sops.placeholder."services/n8n/local_port"}
    '';
  };
  systemd.services.n8n.serviceConfig = {
    EnvironmentFile = lib.mkIf (nixexSops) config.sops.templates."n8n-env".path;
  };

  # Community nodes
  # workaround to make installation work in the UI (not so nixy)
  # https://github.com/nixos/nixpkgs/issues/435198
  systemd.services.n8n.serviceConfig.ExecStart = lib.mkForce (
    lib.getExe (
      pkgs.writeShellApplication {
        name = "n8n";
        runtimeInputs = with pkgs; [
          nodejs
          gnutar
          gzip
        ];
        text = ''
          exec ${lib.getExe pkgs.n8n} "$@"
        '';
      }
    )
  );


  # Caddy
  # - init secrets
  sops.secrets = lib.mkIf nixexSops {
    "hosts/nixex/tailscale/tailnet" = {};
    "services/n8n/public_port" = {};
    "services/n8n/local_port" = {};
  };
  # - svc refresh (avoid activation-script restarts, depr in 26.11)
  systemd.services.caddy.restartTriggers = lib.mkIf nixexSops [
    config.sops.secrets."hosts/nixex/tailscale/tailnet".path
    config.sops.secrets."services/n8n/public_port".path
    config.sops.secrets."services/n8n/local_port".path
  ];
  systemd.services.n8n.restartTriggers = lib.mkIf nixexSops [
    config.sops.secrets."services/n8n/local_port".path
  ];
  # - define proxy
  sops.templates."caddy-nixex-n8n" = lib.mkIf nixexSops {
  	# Default template owner is root; Caddy runs as services.caddy.user and must read this file.
    owner = config.services.caddy.user;
    mode = "0400";
    # Use Tailscale machine certs, not Caddy ACME (LE cannot issue for MagicDNS names).
    content = let
      t = config.sops.placeholder."hosts/nixex/tailscale/tailnet";
      publicPort = config.sops.placeholder."services/n8n/public_port";
      localPort = config.sops.placeholder."services/n8n/local_port";
    in ''
      https://${hostName}.${t}.ts.net:${publicPort} {
        reverse_proxy 127.0.0.1:${localPort}
      }
    '';
  };
  # - finally, the caddy service
  services.caddy = lib.mkIf nixexSops {
    enable = true;
    extraConfig = ''
      import ${config.sops.templates."caddy-nixex-n8n".path}
    '';
  };
  # - and allow it
  services.tailscale.permitCertUid = lib.mkIf (hostName == "nixex") "caddy";
}
