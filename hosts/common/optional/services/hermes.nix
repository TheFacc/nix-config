# Hermes Agent (NousResearch) — personal knowledge/task assistant over the Obsidian vault
# https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup
#
# - Native (non-container) service, dedicated hermes:hermes user, no sudo.
# - Vault: read everything, write only `writableVaultDirs` (enforced by POSIX ACLs + systemd sandbox).
#   ACLs matter: cron jobs run in `systemd-run --user` scopes, OUTSIDE the unit's sandbox.
# - Telegram gateway (polling, no inbound port) + web dashboard on the tailnet via Caddy.
# - Model: ChatGPT/Codex subscription (OAuth), no API key.
#
# Secrets (add with `sops secrets.yaml` BEFORE deploying; sops-nix fails activation on missing keys):
#   services/hermes/public_port          tailnet HTTPS port for the dashboard (Caddy)
#   services/hermes/telegram_bot_token   @BotFather -> /newbot
#   services/hermes/telegram_user_id     your numeric Telegram id (only allowed user)
#   services/hermes/dashboard_password   dashboard login (user: facc)
#   services/hermes/dashboard_secret     `openssl rand -base64 32`
#
# One-time, imperative (credentials persist in /var/lib/hermes/.hermes/auth.json):
#   sudo -u hermes env HERMES_HOME=/var/lib/hermes/.hermes hermes auth add openai-codex
#   The default model is configured below; /model can switch individual sessions.
{ inputs, config, lib, ... }:
let
  inherit (config.networking) hostName;
  nixexSops = (hostName == "nixex" && config.local.hasSopsSecrets);
  cfg = config.services.hermes-agent;
  vaultPath = "/var/lib/obsidian-vault"; # see vaultsync.nix
  writableVaultDirs = [ "Hermes" ];
  hermesUnits = [ "hermes-agent" "hermes-backend" ];
  hardening = {
    # upstream leaves /home readable; not ProtectHome=true, it also hides /run/user (cron needs the user bus)
    InaccessiblePaths = [ "-/home" "-/root" ];
    PrivateDevices = true;
    ProtectControlGroups = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectClock = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    CapabilityBoundingSet = "";
    ReadWritePaths = map (d: "${vaultPath}/${d}") writableVaultDirs;
  };
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true; # `hermes` CLI + HERMES_HOME system-wide

    settings = {
      model.provider = "openai-codex";
      model.default = "gpt-6-sol";
      terminal.backend = "local"; # runs as the hermes user, inside the sandbox
    };

    backend = {
      mode = "dashboard"; # loopback only, Caddy exposes it on the tailnet
      host = "127.0.0.1";
      port = 9119;
    };

    environmentFiles = lib.mkIf nixexSops [ config.sops.templates."hermes-env".path ];

    workingDirectory = "${cfg.stateDir}/workspace";
    documents."AGENTS.md" = ''
      # Role
      You are my personal knowledge and task assistant. I get lost in thoughts and to-dos:
      help me capture, organise, remind and prioritise.

      # Obsidian vault: ${vaultPath}
      - You can READ the whole vault. Use it as context about me, my projects and notes.
      - You can WRITE only inside: ${lib.concatMapStringsSep ", " (d: "${vaultPath}/${d}") writableVaultDirs}.
        Never try to edit, move or delete anything else; propose changes to other notes instead.
      - The vault syncs to my devices every ~5 min; keep notes plain Markdown, Obsidian-friendly
        (wikilinks, `- [ ]` tasks with dates like `📅 2026-01-31`, YAML frontmatter).
      - Keep `Hermes/Dashboard.md` up to date: open tasks by priority/area, upcoming deadlines,
        waiting-for, and a short "focus today" list.
      - When I say "remind me …", create the task in the vault AND schedule a cron reminder.
    '';
  };

  # Extra hardening on top of upstream (NoNewPrivileges, ProtectSystem=strict, PrivateTmp)
  systemd.services.hermes-agent.serviceConfig = hardening;
  systemd.services.hermes-backend.serviceConfig = hardening;

  # Vault access via ACLs (not the `vault` group, which is read-write):
  # read-only on everything, read-write on writableVaultDirs; default ACLs cover new files from sync.
  systemd.tmpfiles.rules = [
    "A+ ${vaultPath} - - - - u:${cfg.user}:rX,d:u:${cfg.user}:rX"
  ] ++ lib.concatMap (d: [
    "d ${vaultPath}/${d} 2770 vaultsync vault - -"
    "A+ ${vaultPath}/${d} - - - - u:${cfg.user}:rwX,d:u:${cfg.user}:rwX"
  ]) writableVaultDirs;

  # Secrets -> $HERMES_HOME/.env (written by the hermes activation script)
  sops.secrets = lib.mkIf nixexSops {
    "hosts/nixex/tailscale/tailnet" = {};
    "services/hermes/public_port" = {};
    "services/hermes/telegram_bot_token" = {};
    "services/hermes/telegram_user_id" = {};
    "services/hermes/dashboard_password" = {};
    "services/hermes/dashboard_secret" = {};
  };
  sops.templates."hermes-env" = lib.mkIf nixexSops {
    restartUnits = map (u: "${u}.service") hermesUnits;
    content = let p = config.sops.placeholder; in ''
      TELEGRAM_BOT_TOKEN=${p."services/hermes/telegram_bot_token"}
      TELEGRAM_ALLOWED_USERS=${p."services/hermes/telegram_user_id"}
      HERMES_DASHBOARD_PUBLIC_URL=https://${hostName}.${p."hosts/nixex/tailscale/tailnet"}.ts.net:${p."services/hermes/public_port"}
      HERMES_DASHBOARD_BASIC_AUTH_USERNAME=facc
      HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${p."services/hermes/dashboard_password"}
      HERMES_DASHBOARD_BASIC_AUTH_SECRET=${p."services/hermes/dashboard_secret"}
    '';
  };

  # Caddy (same pattern as n8n.nix: Tailscale machine certs)
  # public_url above makes the dashboard accept the tailnet Host/Origin and enables its login gate.
  sops.templates."caddy-nixex-hermes" = lib.mkIf nixexSops {
    restartUnits = [ "caddy.service" ];
    owner = config.services.caddy.user;
    mode = "0400";
    content = let
      t = config.sops.placeholder."hosts/nixex/tailscale/tailnet";
      publicPort = config.sops.placeholder."services/hermes/public_port";
    in ''
      https://${hostName}.${t}.ts.net:${publicPort} {
        reverse_proxy 127.0.0.1:${toString cfg.backend.port}
      }
    '';
  };
  services.caddy = lib.mkIf nixexSops {
    enable = true;
    extraConfig = ''
      import ${config.sops.templates."caddy-nixex-hermes".path}
    '';
  };
  services.tailscale.permitCertUid = lib.mkIf (hostName == "nixex") "caddy";
}
