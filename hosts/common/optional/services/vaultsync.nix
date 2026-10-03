# Headless vault sync, homemade, using rclone bisync/crypt
{ config, pkgs, lib, ... }:

let
  vaultPath  = "/var/lib/obsidian-vault";
  configPath = "/var/lib/vaultsync";
  rcloneConf = "${configPath}/rclone.conf";
  pendingDir = "/run/vaultsync-queue";
  pendingSync = "${pendingDir}/pending-sync";
  watchHermes = pkgs.writeShellScript "vaultsync-watch-hermes" ''
    set -euo pipefail
    # A completed write or rename is safer than syncing a file mid-write.
    # Directory events also cover new subdirectories before recursive watches are installed.
    while IFS= read -r -d ''' event && IFS= read -r -d ''' path; do
      if [[ "$event" == *ISDIR* ]] || [[ "$event" != *CREATE* ]]; then
        : > ${lib.escapeShellArg pendingSync}
      fi
    done < <(
      ${pkgs.inotify-tools}/bin/inotifywait --monitor --recursive --quiet \
        --event close_write --event moved_to --event moved_from \
        --event delete --event create \
        --format '%e%0%w%f%0' --no-newline ${lib.escapeShellArg "${vaultPath}/Hermes"}
    )
  '';
  syncPending = pkgs.writeShellScript "vaultsync-sync-pending" ''
    set -euo pipefail
    # Wait for five quiet seconds, even when one turn edits several files.
    while true; do
      before=$(${pkgs.coreutils}/bin/stat --format=%y ${lib.escapeShellArg pendingSync})
      ${pkgs.coreutils}/bin/sleep 5
      after=$(${pkgs.coreutils}/bin/stat --format=%y ${lib.escapeShellArg pendingSync})
      [[ "$before" == "$after" ]] && break
    done
    while true; do
      state=$(${pkgs.systemd}/bin/systemctl show --property=ActiveState --value vaultsync.service)
      case "$state" in
        active|activating|deactivating) ${pkgs.coreutils}/bin/sleep 1 ;;
        *) break ;;
      esac
    done
    ${pkgs.coreutils}/bin/rm -f ${lib.escapeShellArg pendingSync}
    if ! ${pkgs.systemd}/bin/systemctl start vaultsync.service; then
      # The periodic timer retries; rearming here would loop on a persistent failure.
      exit 1
    fi
  '';
  # Hermes' tools may create files 0600/0644 or dirs 0755 (explicit modes beat default ACLs),
  # which the vault group can't write into. Runs as sandboxed root before each sync; no-op when fine.
  # Hermes can write here, so never follow symlinks: -execdir (no parent swap), chgrp -h, setfacl -P
  # (skips symlink args). Files vanishing mid-run make find fail; ExecStartPre's "-" ignores that.
  # No g+s step: RestrictSUIDSGID forbids it, and new subdirs inherit setgid anyway.
  fixHermesPerms = pkgs.writeShellScript "vaultsync-fix-hermes-perms" ''
    set -uo pipefail
    dir=${lib.escapeShellArg "${vaultPath}/Hermes"}
    [[ -d "$dir" ]] || exit 0
    ${pkgs.findutils}/bin/find "$dir" ! -type l \
      \( ! -group vault -o \( -type d ! -perm -g=rwx \) -o \( ! -type d ! -perm -g=rw \) \) \
      -execdir ${pkgs.coreutils}/bin/chgrp -h vault {} + \
      -execdir ${pkgs.acl}/bin/setfacl -P -m g::rwX,m::rwX {} +
  '';
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
    "d ${pendingDir} 0770 vaultsync root - -"
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
      # "!": root, but still inside the sandbox below (ProtectSystem, ReadWritePaths, capability set);
      # "-": a failed fix-up must not block the sync
      ExecStartPre = "-!${fixHermesPerms}";
      ExecStart = pkgs.writeShellScript "vaultsync-bisync" ''
        set -euo pipefail
        # A snapshot can briefly hold the same lock; wait instead of treating that as a sync failure.
        exec ${pkgs.util-linux}/bin/flock -w 600 ${configPath}/bisync.lock \
          ${pkgs.rclone}/bin/rclone bisync \
            "${vaultPath}" "koofrcrypt:" \
            --config "${rcloneConf}" \
            --cache-dir ${configPath}/cache \
            --transfers 4 \
            --checkers 8 \
            --modify-window 2s \
            --no-update-dir-modtime \
            --timeout 60s \
            --retries 3 \
            --retries-sleep 10s \
            --resilient \
            --recover \
            --max-lock 2m \
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
      # Only for the "!" fix-up (read Hermes' dirs, chgrp, setfacl); the non-root rclone keeps none
      CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" "CAP_CHOWN" "CAP_FOWNER" ];
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

  # Hermes writes only under Hermes/. A filesystem watcher catches writes from
  # all its tools, including atomic renames, without giving the agent sudo.
  systemd.services.vaultsync-watch-hermes = {
    description = "Queue vault sync after Hermes vault edits";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "simple";
      User = "vaultsync";
      Group = "vault";
      ExecStart = watchHermes;
      Restart = "always";
      RestartSec = "5s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [ "AF_UNIX" ];
      ReadWritePaths = [ pendingDir ];
    };
  };

  # PathExists keeps a request queued while vaultsync is busy. The watcher may
  # also see files pulled by bisync; a follow-up no-op run drains those events.
  systemd.paths.vaultsync-on-change = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathExists = pendingSync;
      Unit = "vaultsync-on-change.service";
    };
  };
  systemd.services.vaultsync-on-change = {
    description = "Run queued Obsidian vault sync";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      ExecStart = syncPending;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [ "AF_UNIX" ];
      ReadWritePaths = [ pendingDir ];
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
