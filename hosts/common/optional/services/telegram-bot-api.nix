# Local Telegram Bot API server for the Hermes gateway
# https://github.com/tdlib/telegram-bot-api
#
# - Lifts the public Bot API's 20 MB download cap (local mode: up to 2 GB).
# - Loopback only (127.0.0.1:8081), no firewall opening; it reaches out to Telegram's DCs itself.
# - Runs as the Hermes user: in --local mode getFile returns absolute paths under `dataDir`
#   that the gateway reads directly, and file:// uploads from Hermes are read by this server.
#
# Credentials (https://my.telegram.org -> API development tools), kept OUTSIDE Nix for now:
#   /var/lib/telegram-bot-api-secrets/api.env   root:root 0700 dir, read by systemd (PID 1)
#     TELEGRAM_API_ID=...
#     TELEGRAM_API_HASH=...
#
# One-time, already done: the bot was moved off api.telegram.org with logOut. Never rerun it.
{ config, lib, pkgs, ... }:
let
  hermes = config.services.hermes-agent;
  host = "127.0.0.1";
  port = 8081;
  dataDir = "/var/lib/telegram-bot-api";
  waitForPort = pkgs.writeShellScript "telegram-bot-api-wait" ''
    for _ in $(seq 1 60); do
      (exec 3<>/dev/tcp/${host}/${toString port}) 2>/dev/null && exit 0
      sleep 0.5
    done
    echo "telegram-bot-api: not listening on ${host}:${toString port} after 30s" >&2
    exit 1
  '';
in
{
  systemd.services.telegram-bot-api = {
    description = "Local Telegram Bot API server (Hermes)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      User = hermes.user;
      Group = hermes.group;
      EnvironmentFile = "/var/lib/telegram-bot-api-secrets/api.env";
      ExecStart = lib.escapeShellArgs [
        (lib.getExe pkgs.telegram-bot-api)
        "--local"
        "--http-ip-address=${host}"
        "--http-port=${toString port}"
        "--dir=${dataDir}"
      ];
      # Port open = ready, so units ordered after this one find the API up
      ExecStartPost = waitForPort;
      Restart = "on-failure";
      RestartSec = 5;

      # Existing hermes:hermes 0700 dir, kept as is (systemd only fixes owner/mode if they differ)
      StateDirectory = baseNameOf dataDir;
      StateDirectoryMode = "0700";

      # Hardening: the filesystem stays readable (file:// uploads from Hermes' state and the vault),
      # only the data dir is writable; network is left open for Telegram's endpoints.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectControlGroups = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectClock = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
    };
  };

  # Gateway after the API; Wants, not Requires: a brief API restart is ridden out by the
  # adapter's polling reconnect, instead of tearing down the gateway and its in-flight runs.
  systemd.services.hermes-agent = {
    after = [ "telegram-bot-api.service" ];
    wants = [ "telegram-bot-api.service" ];
  };

  # Default profile only (deep-merged into $HERMES_HOME/config.yaml; token stays in .env)
  services.hermes-agent.settings.platforms.telegram.extra = {
    base_url = "http://${host}:${toString port}/bot";
    base_file_url = "http://${host}:${toString port}/file/bot";
    local_mode = true;
  };
}
