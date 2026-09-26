# Periodic git snapshots of the Obsidian vault: an undo button for bad edits (agents, sync conflicts, me)
# The repo lives OUTSIDE the vault (not synced, not readable by hermes); only cfg.user can write it.
#   vault-git log --stat
#   vault-git diff HEAD~3 -- Hermes/
#   vault-git restore --source=<rev> -- path/to/note.md
# Offsite (optional): daily `git bundle` of the whole history -> rclone crypt remote, never the vault's own remote.
#   Restore: rclone copy <remote>vault.bundle . && git clone vault.bundle
{ config, lib, pkgs, ... }:
let
  cfg = config.services.vault-snapshot;
  git = lib.getExe pkgs.git;
  gitFlags = lib.escapeShellArgs [
    "-C" cfg.vaultDir # else git resolves .gitattributes/.mailmap against the caller's cwd
    "-c" "safe.directory=*"
    "-c" "user.name=vault-snapshot"
    "-c" "user.email=vault-snapshot@${config.networking.hostName}"
    "--git-dir=${cfg.repoDir}"
    "--work-tree=${cfg.vaultDir}"
  ];
  snapshotScript = pkgs.writeShellScript "vault-snapshot" ''
    set -euo pipefail
    [ -f ${cfg.repoDir}/HEAD ] || ${git} init -q --bare ${cfg.repoDir}
    printf '%s\n' ${lib.escapeShellArgs cfg.excludes} > ${cfg.repoDir}/info/exclude
    ${git} ${gitFlags} add -A
    ${git} ${gitFlags} diff --cached --quiet || ${git} ${gitFlags} commit -q -m "snapshot $(date -Is)"
  '';
  offsiteScript = pkgs.writeShellScript "vault-snapshot-offsite" ''
    set -euo pipefail
    bundle=/tmp/vault.bundle
    ${git} -c 'safe.directory=*' --git-dir=${cfg.repoDir} bundle create -q "$bundle" --all
    # never overwrite a good offsite copy with junk
    ${git} -c 'safe.directory=*' --git-dir=${cfg.repoDir} bundle verify -q "$bundle"
    ${pkgs.rclone}/bin/rclone copyto "$bundle" ${lib.escapeShellArg "${cfg.offsite.remote}vault.bundle"} \
      --config ${cfg.offsite.rcloneConfig} --cache-dir /tmp/rclone-cache \
      --timeout 60s --retries 3 --retries-sleep 10s
  '';
  # Run as cfg.user so restores keep the vault's ownership/perms
  vaultGit = pkgs.writeShellScriptBin "vault-git" ''
    exec /run/wrappers/bin/sudo -u ${cfg.user} ${git} ${gitFlags} "$@"
  '';
in
{
  options.services.vault-snapshot = {
    enable = lib.mkEnableOption "periodic git snapshots of the Obsidian vault";
    vaultDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/obsidian-vault";
      description = "Vault to snapshot (read-only for the snapshot job).";
    };
    repoDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vault-snapshot/vault.git";
      description = "Bare git repo holding the history, outside the vault.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "vaultsync";
      description = "User owning the repo (needs read access to the vault).";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "vault";
      description = "Group for the snapshot job.";
    };
    lockFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/var/lib/vaultsync/bisync.lock";
      description = "Shared flock with vaultsync so snapshots never catch a half-synced vault; null to disable.";
    };
    excludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ".obsidian/workspace*.json" ".trash/" ];
      description = "gitignore patterns (noisy UI state, trash).";
    };
    calendar = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd OnCalendar for snapshots.";
    };
    offsite = {
      enable = lib.mkEnableOption "daily encrypted offsite copy of the history (git bundle via rclone)";
      remote = lib.mkOption {
        type = lib.types.str;
        default = "vaulthistory:";
        description = "rclone remote (+ path ending in / or :) for vault.bundle; must NOT be inside the vault's sync remote.";
      };
      rcloneConfig = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/vaultsync/rclone.conf";
        description = "rclone.conf holding the remote, readable by user.";
      };
      calendar = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "systemd OnCalendar for offsite uploads.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ vaultGit ];

    systemd.tmpfiles.rules = [
      "d ${dirOf cfg.repoDir} 0700 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.timers.vault-snapshot = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.calendar;
        RandomizedDelaySec = "2min";
        Persistent = true;
        Unit = "vault-snapshot.service";
      };
    };

    systemd.services.vault-snapshot = {
      description = "Git snapshot of the Obsidian vault";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart =
          if cfg.lockFile == null then snapshotScript
          else "${pkgs.util-linux}/bin/flock -w 600 ${cfg.lockFile} ${snapshotScript}";

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateNetwork = true;
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
        CapabilityBoundingSet = "";
        ReadWritePaths = [ (dirOf cfg.repoDir) ]
          ++ lib.optional (cfg.lockFile != null) (dirOf cfg.lockFile);
        UMask = "0077";
      };
    };

    systemd.timers.vault-snapshot-offsite = lib.mkIf cfg.offsite.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.offsite.calendar;
        RandomizedDelaySec = "30min";
        Persistent = true;
        Unit = "vault-snapshot-offsite.service";
      };
    };

    systemd.services.vault-snapshot-offsite = lib.mkIf cfg.offsite.enable {
      description = "Upload encrypted git bundle of the vault history";
      after = [ "network-online.target" "vault-snapshot.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = offsiteScript;

        # Hardening: read-only everywhere, no vault access, network only for rclone
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
        InaccessiblePaths = [ cfg.vaultDir ];
        UMask = "0077";
      };
    };
  };
}
