# Headless vault sync, homemade, using rclone bisync/crypt
{ config, pkgs, lib, ... }:

let
  vaultPath  = "/var/lib/obsidian-vault";
  configPath = "/var/lib/vaultsync";
  rcloneConf = "${configPath}/rclone.conf";
  # Important requirement: rclone.conf remote [koofrcrypt] must have filename_encoding = base64
  #                        to ensure compatibility with Remotely Save plugin
in
{
  # Dedicated least-privilege identities
  users.groups.vault = {};
  users.users.vaultsync = {
    isSystemUser = true;
    group = "vault";
    home = configPath;
    createHome = true;
  };

  systemd.tmpfiles.rules = [
    "d ${configPath} 0700 vaultsync vault - -"
    "d ${configPath}/cache 0700 vaultsync vault - -"
    "d ${configPath}/logs 0700 vaultsync vault - -"
    "d ${vaultPath} 2770 root vault - -"
  ];

  # Two-way sync job (oneshot), safe to trigger by timer
  systemd.services.vaultsync = {
    description = "Two-way encrypted Koofr sync for Obsidian vault";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "vaultsync";
      Group = "vault";
      ExecStart = pkgs.writeShellScript "vaultsync-bisync" ''
        set -euo pipefail
        exec ${pkgs.util-linux}/bin/flock -n ${configPath}/bisync.lock \
          ${pkgs.rclone}/bin/rclone bisync \
            "${vaultPath}" "koofrcrypt:" \
            --config "${rcloneConf}" \
            --cache-dir ${configPath}/cache \
            --transfers 4 \
            --checkers 8 \
            --modify-window 2s \
            --timeout 60s \
            --retries 3 \
            --retries-sleep 10s \
            --resilient \
            --log-file ${configPath}/logs/bisync.log \
            --log-level INFO
      '';
#             --check-access \

      # Hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectControlGroups = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectClock = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];

      ReadWritePaths = [
        vaultPath
        configPath
      ];
      UMask = "0007"; # user+group: files 0660, dirs 0770, gid inherited from folder
    };
  };

  # Schedule
  systemd.timers.vaultsync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5"; # every 5 min
      RandomizedDelaySec = "45s";
      Persistent = true;
      Unit = "vaultsync.service";
    };
  };

  ###
  # N8N customization to access the vault
  users.users.n8n.extraGroups = lib.mkIf (config.users.users ? n8n) [ "vault" ]; # allow n8n user
  services.n8n = {
    environment = lib.mkIf (config.services ? n8n) {
        N8N_RESTRICT_FILE_ACCESS_TO = vaultPath;
    };
  };
  systemd.services.n8n.serviceConfig = lib.mkIf (config.services ? n8n) {
    ReadWritePaths = [ vaultPath ];
  };
}
