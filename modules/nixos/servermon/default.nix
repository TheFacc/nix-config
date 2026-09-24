# servermon: Telegram server monitor / alert bot (disks, mounts, services, power, network)
#
# One python daemon (stdlib only, ./servermon.py) + a few helper units:
#   servermon.service                  daemon: spool/outbox, journal watcher, health/power/net checks, heartbeat
#   servermon-failure@<unit>.service   OnFailure= hook, reports the last journal lines of <unit>
#   servermon-shutdown-marker.service  its ExecStop marks clean shutdowns (for the boot report)
#   servermon-arr.{service,timer}      optional Sonarr/Radarr "stuck import" check (API keys via LoadCredential)
#   smartd                             optional, notifications routed through `servermon notify`
#
# Anything can alert through the spool, also while offline:
#   servermon-notify -s warn -t "title" "message"      (root, the servermon user or group members)
{ config, lib, pkgs, ... }:
let
  cfg = config.services.servermon;
  stateDir = "/var/lib/servermon";

  servermonPkg = pkgs.writers.writePython3Bin "servermon" {
    # long lines are fine, the rest of flake8 still runs at build time
    flakeIgnore = [ "E501" "W503" "W504" "E226" "E121" "E123" "E126" "E24" "E704" "E731" ];
  } (builtins.readFile ./servermon.py);
  bin = "${servermonPkg}/bin/servermon";

  configFile = pkgs.writeText "servermon.json" (builtins.toJSON {
    hostname = cfg.hostname;
    inherit stateDir;
    tokenFile = cfg.telegram.tokenFile;
    chatIdFile = cfg.telegram.chatIdFile;
    inherit (cfg) cooldown reminderInterval;
    intervals = {
      tick = 5;
      heartbeat = cfg.heartbeat.interval;
      heartbeatOnBattery = cfg.heartbeat.onBatteryInterval;
      health = cfg.healthInterval;
      power = cfg.power.pollInterval;
    };
    network = {
      inherit (cfg.network) enable interfaces gateway probeUrl interval offlineInterval failThreshold digestThreshold;
    };
    mounts = cfg.mounts;
    diskSpace = cfg.diskSpace;
    power = {
      inherit (cfg.power) enable ac battery;
      lowBattery = cfg.power.lowBatteryLevels;
      cooldown = 300;
    };
    journal = { inherit (cfg.journal) enable quiet maxWindow cooldown mountCooldown; };
    arr = { inherit (cfg.arr) instances; stuckAfter = cfg.arr.stuckAfter; };
  });

  # `servermon <subcommand>` with the system config baked in
  cli = pkgs.writeShellApplication {
    name = "servermon";
    text = ''exec ${bin} --config ${configFile} "$@"'';
  };
  notifyCli = pkgs.writeShellApplication {
    name = "servermon-notify";
    text = ''exec ${bin} --config ${configFile} notify "$@"'';
  };

  # smartd -M exec hook (runs as root, env documented in smartd.conf(5))
  smartdHook = pkgs.writeShellApplication {
    name = "servermon-smartd-hook";
    text = ''
      exec ${lib.getExe notifyCli} -s crit \
        -k "smart:''${SMARTD_DEVICE:-?}:''${SMARTD_FAILTYPE:-?}" -c ${toString cfg.smartd.cooldown} \
        -t "SMART ''${SMARTD_FAILTYPE:-problem}: ''${SMARTD_DEVICESTRING:-?}" \
        -- "''${SMARTD_FULLMESSAGE:-''${SMARTD_MESSAGE:-no message}}"
    '';
  };

  # known media/infra services, only those enabled on this host (default for failureAlerts.services)
  knownServices = lib.concatLists [
    (lib.optionals config.services.sonarr.enable [ "sonarr" ])
    (lib.optionals config.services.radarr.enable [ "radarr" ])
    (lib.optionals config.services.prowlarr.enable [ "prowlarr" ])
    (lib.optionals (config ? dupsvc && config.dupsvc.services.sonarr.enable or false) [ "sonarr-dupsvc" ])
    (lib.optionals (config ? dupsvc && config.dupsvc.services.radarr.enable or false) [ "radarr-dupsvc" ])
    (lib.optionals (config.services.qBittorrent.enable or false) [ "qBittorrent" ])
    (lib.optionals config.services.plex.enable [ "plex" ])
    (lib.optionals config.services.jellyfin.enable [ "jellyfin" ])
    (lib.optionals (config.services.jellyfin-backup.enable or false) [ "jellyfin-backup" ])
    (lib.optionals config.services.tautulli.enable [ "tautulli" ])
    (lib.optionals config.services.n8n.enable [ "n8n" ])
    (lib.optionals config.services.caddy.enable [ "caddy" ])
    (lib.optionals config.services.tailscale.enable [ "tailscaled" ])
  ];

  # no mount namespace here: the daemon must see the host's real mount table and trigger automounts
  baseHardening = {
    NoNewPrivileges = true;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [ "@system-service" ];
    CapabilityBoundingSet = "";
    UMask = "0027";
  };
  # for the small helpers, which don't inspect mounts
  fullHardening = baseHardening // {
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    ReadWritePaths = [ stateDir ];
  };
  unitBase = {
    User = cfg.user;
    Group = cfg.group;
    StateDirectory = "servermon";
    StateDirectoryMode = "0750";
  };

  mountOpts = { ... }: {
    options = {
      path = lib.mkOption { type = lib.types.str; description = "Mount point."; };
      uuid = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Filesystem UUID expected at this mount point. Enables the "disk missing" check and the
          stale-mount check (mounted device != current /dev/disk/by-uuid/<uuid>). Null for pools (mergerfs).
        '';
      };
      required = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Alert when the disk is missing. If false, its absence (and journal noise about it) is ignored.";
      };
      severity = lib.mkOption { type = lib.types.enum [ "warn" "crit" ]; default = "crit"; description = "Severity when the disk is missing."; };
      reminderInterval = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Seconds between reminders while the disk is missing (default: reminderInterval).";
      };
      readOnly = lib.mkOption { type = lib.types.bool; default = false; description = "Don't alert if mounted read-only."; };
      timeout = lib.mkOption { type = lib.types.int; default = 15; description = "Seconds allowed to list the mount point."; };
    };
  };

  spaceOpts = { ... }: {
    options = {
      path = lib.mkOption { type = lib.types.str; };
      warnFreePercent = lib.mkOption { type = lib.types.number; default = 10; };
      critFreePercent = lib.mkOption { type = lib.types.number; default = 5; };
      minFreeGiB = lib.mkOption { type = lib.types.nullOr lib.types.number; default = null; description = "Warn below this many GiB free."; };
      critFreeGiB = lib.mkOption { type = lib.types.nullOr lib.types.number; default = null; description = "Critical below this many GiB free."; };
    };
  };

  arrOpts = { ... }: {
    options = {
      name = lib.mkOption { type = lib.types.str; example = "sonarr"; description = "Name (also the credential name)."; };
      url = lib.mkOption { type = lib.types.str; example = "http://127.0.0.1:8989"; };
      apiKeyFile = lib.mkOption {
        type = lib.types.str;
        example = "/var/lib/sonarr/.config/NzbDrone/config.xml";
        description = ''
          File with the API key: either the app's config.xml (ApiKey/UrlBase are parsed) or a plain key file
          (e.g. a sops secret). Loaded by systemd (LoadCredential, as root), so the app-only permissions are fine.
        '';
      };
    };
  };
in
{
  options.services.servermon = {
    enable = lib.mkEnableOption "servermon, a Telegram server monitoring/alert bot";

    package = lib.mkOption {
      type = lib.types.package;
      default = servermonPkg;
      readOnly = true;
      description = "The servermon python program (built from ./servermon.py, flake8-checked).";
    };

    hostname = lib.mkOption { type = lib.types.str; default = config.networking.hostName; description = "Shown in every message."; };
    user = lib.mkOption { type = lib.types.str; default = "servermon"; };
    group = lib.mkOption { type = lib.types.str; default = "servermon"; };
    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "systemd-journal" ];
      description = "Supplementary groups of the daemon (journal access, read access to media mounts).";
    };

    telegram = {
      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "File with the bot token (read at every send, never copied to the store). Null: spool only.";
      };
      chatIdFile = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "File with the target chat_id."; };
    };

    cooldown = lib.mkOption {
      type = lib.types.int;
      default = 1800;
      description = "Default seconds between two alerts with the same key; repeats are summarized afterwards.";
    };
    reminderInterval = lib.mkOption { type = lib.types.int; default = 14400; description = "Seconds between reminders for failing health checks."; };
    healthInterval = lib.mkOption { type = lib.types.int; default = 300; description = "Seconds between health check runs."; };
    heartbeat = {
      interval = lib.mkOption { type = lib.types.int; default = 60; };
      onBatteryInterval = lib.mkOption { type = lib.types.int; default = 15; };
    };

    mounts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule mountOpts);
      default = [ ];
      description = "Mounts to verify (present, right device, not shut down, listable).";
    };
    diskSpace = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule spaceOpts);
      default = [ { path = "/"; } ];
      description = "Free space thresholds.";
    };

    network = {
      enable = lib.mkOption { type = lib.types.bool; default = true; description = "Online/offline tracking with a summary on recovery."; };
      interfaces = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; description = "NICs whose link state is watched."; };
      gateway = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Gateway to ping (default: from the routing table)."; };
      probeUrl = lib.mkOption { type = lib.types.str; default = "https://api.telegram.org"; };
      interval = lib.mkOption { type = lib.types.int; default = 60; };
      offlineInterval = lib.mkOption { type = lib.types.int; default = 30; };
      failThreshold = lib.mkOption { type = lib.types.int; default = 3; description = "Consecutive failed probes before going offline."; };
      digestThreshold = lib.mkOption { type = lib.types.int; default = 8; description = "Backlogs larger than this are sent as a digest."; };
    };

    power = {
      enable = lib.mkOption { type = lib.types.bool; default = true; };
      ac = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; example = "ADP1"; description = "power_supply name (default: first Mains)."; };
      battery = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; example = "BAT1"; description = "power_supply name (default: first Battery)."; };
      lowBatteryLevels = lib.mkOption { type = lib.types.listOf lib.types.int; default = [ 50 25 10 5 ]; };
      pollInterval = lib.mkOption { type = lib.types.int; default = 5; };
    };

    journal = {
      enable = lib.mkOption { type = lib.types.bool; default = true; description = "Watch kernel + PID1 messages for disk/USB/fs/NIC trouble."; };
      quiet = lib.mkOption { type = lib.types.int; default = 20; description = "An incident closes after this many quiet seconds."; };
      maxWindow = lib.mkOption { type = lib.types.int; default = 180; description = "Max seconds grouped into one incident."; };
      cooldown = lib.mkOption { type = lib.types.int; default = 1800; description = "Seconds between identical incidents."; };
      mountCooldown = lib.mkOption { type = lib.types.int; default = 21600; description = "Seconds between identical mount-unit failure alerts."; };
    };

    failureAlerts = {
      enable = lib.mkOption { type = lib.types.bool; default = true; };
      services = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = knownServices;
        defaultText = lib.literalMD "the enabled ones among sonarr, radarr, their -dupsvc copies, prowlarr, qBittorrent, plex, jellyfin, jellyfin-backup, tautulli, n8n, caddy, tailscaled";
        description = "Services (without .service) that get OnFailure=servermon-failure@%n.service. They must exist.";
      };
      extraServices = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    };

    smartd = {
      enable = lib.mkEnableOption "smartd for the listed disks, with notifications through servermon";
      devices = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            device = lib.mkOption { type = lib.types.str; example = "/dev/disk/by-id/usb-Seagate_Expansion_HDD_XXXX-0:0"; };
            options = lib.mkOption {
              type = lib.types.str;
              default = "";
              example = "-d removable -d sat";
              description = "Extra smartd directives. Use `-d removable` for disks that may be absent at start.";
            };
          };
        });
        default = [ ];
      };
      cooldown = lib.mkOption { type = lib.types.int; default = 43200; };
    };

    arr = {
      enable = lib.mkEnableOption "the Sonarr/Radarr stuck-import check";
      instances = lib.mkOption { type = lib.types.listOf (lib.types.submodule arrOpts); default = [ ]; };
      stuckAfter = lib.mkOption { type = lib.types.int; default = 7200; description = "Seconds an item may wait to import before alerting."; };
      interval = lib.mkOption { type = lib.types.str; default = "15min"; };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        description = "servermon alert bot";
      };
      users.groups.${cfg.group} = { };

      # incoming/ is the spool other units drop messages into: group-writable, not listable
      systemd.tmpfiles.rules = [
        "d ${stateDir} 0750 ${cfg.user} ${cfg.group} -"
        "d ${stateDir}/incoming 1730 ${cfg.user} ${cfg.group} -"
      ];

      environment.systemPackages = [ cli notifyCli ];

      systemd.services.servermon = {
        description = "servermon: Telegram server monitor";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        # stopped before the network/dbus at shutdown, so it can still say goodbye
        after = [ "network-online.target" "dbus.service" "systemd-journald.service" "local-fs.target" ];
        path = [ config.systemd.package pkgs.coreutils pkgs.iputils ];
        serviceConfig = unitBase // baseHardening // {
          ExecStart = "${bin} --config ${configFile} daemon";
          SupplementaryGroups = cfg.extraGroups;
          Restart = "always";
          RestartSec = 10;
          TimeoutStopSec = 20;
        };
      };

      systemd.services."servermon-failure@" = {
        description = "servermon: report failure of %i";
        path = [ config.systemd.package ];
        serviceConfig = unitBase // fullHardening // {
          Type = "oneshot";
          SupplementaryGroups = [ "systemd-journal" ];
          ExecStart = "${bin} --config ${configFile} failure %i";
        };
      };

      # ExecStop runs at shutdown: "clean shutdown" marker for the next boot report
      systemd.services.servermon-shutdown-marker = {
        description = "servermon: mark clean shutdowns";
        wantedBy = [ "multi-user.target" ];
        after = [ "dbus.service" "local-fs.target" "systemd-journald.service" ];
        path = [ config.systemd.package ];
        restartIfChanged = false;
        serviceConfig = unitBase // fullHardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/true";
          ExecStop = "${bin} --config ${configFile} mark-shutdown";
        };
      };
    }

    (lib.mkIf cfg.failureAlerts.enable {
      systemd.services = lib.genAttrs (cfg.failureAlerts.services ++ cfg.failureAlerts.extraServices ++ [ "servermon" ]
        ++ lib.optional cfg.arr.enable "servermon-arr")
        (_: { onFailure = [ "servermon-failure@%n.service" ]; });
    })

    (lib.mkIf cfg.smartd.enable {
      services.smartd = {
        enable = true;
        autodetect = false;
        # built-in notifiers off, we route through the bot
        notifications = {
          mail.enable = lib.mkDefault false;
          wall.enable = lib.mkDefault false;
          x11.enable = lib.mkDefault false;
        };
        # -n standby: don't spin up sleeping USB disks just to poll them
        defaults.monitored = "-a -n standby,24,q -m <nomailer> -M exec ${lib.getExe smartdHook}";
        devices = map (d: { inherit (d) device options; }) cfg.smartd.devices;
      };
      environment.systemPackages = [ pkgs.smartmontools ];
      # smartd skips `-d removable` disks absent at start: restart it when a USB disk shows up
      systemd.services.servermon-smartd-restart = {
        description = "Restart smartd after a USB disk appeared";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${config.systemd.package}/bin/systemctl try-restart smartd.service";
        };
      };
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_BUS}=="usb", TAG+="systemd", ENV{SYSTEMD_WANTS}+="servermon-smartd-restart.service"
      '';
    })

    (lib.mkIf cfg.arr.enable {
      systemd.services.servermon-arr = {
        description = "servermon: Sonarr/Radarr stuck import check";
        after = [ "network.target" ];
        serviceConfig = unitBase // fullHardening // {
          Type = "oneshot";
          ExecStart = "${bin} --config ${configFile} arr-check";
          LoadCredential = map (i: "${i.name}:${i.apiKeyFile}") cfg.arr.instances;
        };
      };
      systemd.timers.servermon-arr = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "10min";
          OnUnitActiveSec = cfg.arr.interval;
        };
      };
    })
  ]);
}
