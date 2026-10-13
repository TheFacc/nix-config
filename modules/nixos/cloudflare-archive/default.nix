# cloudflare-archive: keep Cloudflare's per-request analytics after Cloudflare drops them (~31 days)
#
# A daily oneshot (./cloudflare_archive.py, stdlib only) copies every complete UTC hour of
# httpRequestsAdaptive / firewallEventsAdaptive still inside Cloudflare's window and not yet on disk:
#   <dataDir>/<zone>/<dataset>/YYYY/MM/DD/HH.ndjson.gz  (+ manifest.json per day: rows, estimate, flags)
# After ipRetentionDays, clientIP becomes clientIPHash (HMAC, key in <dataDir>/.ip-hash-key) + clientIPNet.
#
#   cloudflare-archive status                    coverage and size
#   sudo systemctl start cloudflare-archive      run now (first run backfills ~30 days, takes a while)
#   zcat <file> | jq ...                         read rows
{ config, lib, pkgs, ... }:
let
  cfg = config.services.cloudflare-archive;

  pkg = pkgs.writers.writePython3Bin "cloudflare-archive" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./cloudflare_archive.py);

  configFile = pkgs.writeText "cloudflare-archive.json" (builtins.toJSON {
    inherit (cfg) dataDir zones datasets days lagHours ipRetentionDays alertMissingDays;
    tokenFile = "$CREDENTIALS_DIRECTORY/token";
  });

  # `cloudflare-archive status` for admins (reads the archive as its user)
  cli = pkgs.writeShellScriptBin "cloudflare-archive" ''
    exec /run/wrappers/bin/sudo -u ${cfg.user} ${lib.getExe pkg} --config ${configFile} "$@"
  '';

  zoneOpts = { ... }: {
    options = {
      name = lib.mkOption { type = lib.types.str; example = "example.com"; description = "Directory name for the zone."; };
      id = lib.mkOption { type = lib.types.str; description = "Cloudflare zone ID (dashboard > zone overview)."; };
    };
  };
in
{
  options.services.cloudflare-archive = {
    enable = lib.mkEnableOption "daily archive of Cloudflare per-request analytics";

    zones = lib.mkOption { type = lib.types.listOf (lib.types.submodule zoneOpts); };
    datasets = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "http" "firewall" ]);
      default = [ "http" "firewall" ];
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      description = "File with a Cloudflare API token allowed Zone > Analytics > Read on the zones (loaded via LoadCredential).";
    };
    dataDir = lib.mkOption { type = lib.types.str; default = "/var/lib/cloudflare-archive"; };
    days = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "How far back each run looks for missing hours (Cloudflare keeps ~31 days).";
    };
    lagHours = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Skip hours younger than this; Cloudflare may still be filling them in.";
    };
    ipRetentionDays = lib.mkOption {
      type = lib.types.int;
      default = 90;
      description = "Days to keep raw client IPs before replacing them with a keyed hash and their network.";
    };
    alertMissingDays = lib.mkOption {
      type = lib.types.int;
      default = 21;
      description = "Fail the run (OnFailure alerts) when an hour older than this still can't be archived completely.";
    };
    calendar = lib.mkOption { type = lib.types.str; default = "daily"; description = "systemd OnCalendar."; };
    user = lib.mkOption { type = lib.types.str; default = "cloudflare-archive"; };
    group = lib.mkOption { type = lib.types.str; default = "cloudflare-archive"; };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cli ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.${cfg.group} = { };

    systemd.timers.cloudflare-archive = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.calendar;
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    systemd.services.cloudflare-archive = {
      description = "Archive Cloudflare per-request analytics";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.RequiresMountsFor = [ cfg.dataDir ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        # created at start, not by tmpfiles: dataDir may live on a mount that isn't up at boot
        ExecStartPre = "+${pkgs.coreutils}/bin/install -d -m 0750 -o ${cfg.user} -g ${cfg.group} ${cfg.dataDir}";
        ExecStart = "${lib.getExe pkg} --config ${configFile} run";
        LoadCredential = [ "token:${cfg.tokenFile}" ];
        TimeoutStartSec = "12h"; # the first run backfills a month at a gentle pace
        Nice = 10;
        IOSchedulingClass = "idle";

        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
        CapabilityBoundingSet = "";
        ReadWritePaths = [ cfg.dataDir ];
        UMask = "0027";
      };
    };
  };
}
