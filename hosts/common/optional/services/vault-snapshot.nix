# Periodic Git snapshots of the Obsidian vault plus custom Hermes commits on a separate branch.
# The bare repo lives outside the vault and is not readable by Hermes; generated diffs are.
#   vault-git log --stat
#   vault-git log --all --stat
#   vault-git restore --source=<rev> -- path/to/note.md
# Offsite (optional): daily `git bundle` of the whole history -> rclone crypt remote, never the vault's own remote.
#   Restore: rclone copy <remote>vault.bundle . && git clone vault.bundle
{ config, lib, pkgs, ... }:
let
  cfg = config.services.vault-snapshot;
  hermesEnabled = config.services.hermes-agent.enable or false;
  historyDir = "/var/lib/vault-history";
  requestDir = "/run/vault-save-request";
  readyDir = "${requestDir}/ready";
  stagingDir = "${requestDir}/staging";
  resultsDir = "${requestDir}/results";
  messageFile = "${requestDir}/message";
  hermesRef = "refs/heads/hermes"; # see vault_history.py
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
    message="''${1:-snapshot $(date -Is)}"
    [ -f ${cfg.repoDir}/HEAD ] || ${git} init -q --bare ${cfg.repoDir}
    printf '%s\n' ${lib.escapeShellArgs cfg.excludes} > ${cfg.repoDir}/info/exclude
    # Git's markdown driver labels diff hunks with the nearest heading
    printf '*.md diff=markdown\n' > ${cfg.repoDir}/info/attributes
    if [[ $# -eq 0 ]]; then
      ${git} ${gitFlags} add -A
      ${git} ${gitFlags} diff --cached --quiet || ${git} ${gitFlags} commit -q -m "$message"
    else
      # A separate ref preserves the requested message even if the hourly job
      # already snapshotted the same files on the main branch.
      ${pkgs.python3}/bin/python3 ${./vault_history.py} commit-hermes --git-bin ${git} -- \
        ${lib.escapeShellArg cfg.repoDir} ${lib.escapeShellArg cfg.vaultDir} "$message" \
        ${lib.escapeShellArg "vault-snapshot@${config.networking.hostName}"}
    fi
    ${pkgs.python3}/bin/python3 ${./vault_history.py} render \
      ${lib.escapeShellArg cfg.repoDir} ${lib.escapeShellArg cfg.vaultDir} ${historyDir} --git-bin ${git}
  '';
  saveRequest = pkgs.writeShellScriptBin "vault-save" ''
    set -euo pipefail
    if [[ $# -ne 1 ]]; then
      echo 'Usage: vault-save "one-line commit message"' >&2
      exit 2
    fi
    if [[ -z "$1" || "$1" == *[$'\001'-$'\037']* ]]; then
      echo 'Usage: vault-save "one-line commit message"' >&2
      exit 2
    fi
    if (( $(printf %s "$1" | ${pkgs.coreutils}/bin/wc -c) > 120 )); then
      echo 'Commit message must be at most 120 bytes' >&2
      exit 2
    fi
    request=$(${pkgs.coreutils}/bin/mktemp ${stagingDir}/request.XXXXXX)
    trap '${pkgs.coreutils}/bin/rm -f "$request"' EXIT
    printf '%s' "$1" > "$request"
    result=${resultsDir}/''${request##*/}
    ${pkgs.coreutils}/bin/mv "$request" ${readyDir}/
    trap - EXIT
    for ((i = 0; i < 900; i++)); do
      if [[ -f "$result" ]]; then
        read -r status commit < "$result" || true
        # Link straight to the new commit, or to the Hermes list when nothing changed
        url=""
        if [[ -n "''${HERMES_DASHBOARD_PUBLIC_URL:-}" ]]; then
          if [[ "$commit" =~ ^[0-9a-f]{40,64}$ ]]; then
            url="''${HERMES_DASHBOARD_PUBLIC_URL%/}/diffs/$commit.html"
          else
            url="''${HERMES_DASHBOARD_PUBLIC_URL%/}/diffs/hermes.html"
          fi
        fi
        if [[ "$status" == OK ]]; then
          if [[ -n "$commit" ]]; then
            echo 'Vault synced, changes committed and diff viewer updated'
          else
            echo 'Vault synced; nothing changed since the last save'
          fi
          [[ -z "$url" ]] || echo "$url"
          exit 0
        fi
        if [[ "$status" == SYNC_FAILED ]]; then
          if [[ -n "$commit" ]]; then
            echo 'Vault committed locally and diff viewer updated; sync failed and its timer will retry' >&2
          else
            echo 'Vault sync failed and its timer will retry; nothing changed since the last save' >&2
          fi
          [[ -z "$url" ]] || echo "$url"
          exit 1
        fi
        echo 'Vault save failed; check vault-save-request.service' >&2
        exit 1
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo 'Timed out waiting for vault save' >&2
    exit 1
  '';
  processRequest = pkgs.writeShellScript "vault-save-process-request" ''
    set -euo pipefail
    # Run a short command as another user via PID 1: inside this sandbox runuser's setuid()
    # fails with EPERM, and a transient unit also sandboxes the helper and bounds its runtime.
    as_user() {
      local user=$1
      shift
      ${pkgs.coreutils}/bin/timeout 10 ${pkgs.systemd}/bin/systemd-run --quiet --wait --pipe --collect \
        --uid="$user" -p NoNewPrivileges=yes -p PrivateNetwork=yes -p ProtectSystem=strict \
        -p ProtectHome=yes -p RuntimeMaxSec=5 -E HOME=/var/empty -- "$@"
    }
    # As the repo owner: root must not run git on a repo another user can write
    hermes_ref() {
      as_user ${cfg.user} ${git} --git-dir=${cfg.repoDir} rev-parse -q --verify ${hermesRef} || true
    }
    # Atomic, so the polling client never reads a half-written result
    finish() {
      printf '%s' "$1" > "$result.tmp"
      ${pkgs.coreutils}/bin/mv -f -- "$result.tmp" "$result"
    }
    for request in ${readyDir}/request.*; do
      [[ -e "$request" || -L "$request" ]] || continue
      result=${resultsDir}/''${request##*/}
      # Read as hermes, so a malicious symlink cannot make root read a secret.
      if [[ -L "$request" ]]; then
        ${pkgs.coreutils}/bin/rm -f -- "$request"
        finish ERROR
        continue
      fi
      if ! message=$(as_user hermes ${pkgs.coreutils}/bin/head -c 121 -- "$request"); then
        ${pkgs.coreutils}/bin/rm -f -- "$request"
        finish ERROR
        continue
      fi
      ${pkgs.coreutils}/bin/rm -f -- "$request"
      if [[ -z "$message" || "$message" == *[$'\001'-$'\037']* ]] || \
         (( $(printf %s "$message" | ${pkgs.coreutils}/bin/wc -c) > 120 )); then
        echo 'Invalid vault-save message' >&2
        finish ERROR
        continue
      fi
      ${pkgs.coreutils}/bin/install -o ${cfg.user} -g ${cfg.group} -m 0600 /dev/null ${messageFile}
      printf '%s' "$message" > ${messageFile}
      before=$(hermes_ref)
      sync_ok=true
      if ! ${pkgs.systemd}/bin/systemctl start vaultsync.service; then
        sync_ok=false
      fi
      if ${pkgs.systemd}/bin/systemctl start vault-snapshot-requested.service; then
        after=$(hermes_ref)
        commit=""
        [[ "$after" == "$before" ]] || commit=$after
        if [[ "$sync_ok" == true ]]; then
          finish "OK $commit"
        else
          finish "SYNC_FAILED $commit"
        fi
      else
        finish ERROR
      fi
      ${pkgs.coreutils}/bin/rm -f ${messageFile}
    done
  '';
  requestedSnapshot = pkgs.writeShellScript "vault-snapshot-requested" ''
    set -euo pipefail
    message=$(${pkgs.coreutils}/bin/cat ${messageFile})
    exec ${snapshotScript} "$message"
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
    environment.systemPackages = [ vaultGit ] ++ lib.optional hermesEnabled saveRequest;

    users.groups.vault-history = {};
    users.users = { ${cfg.user}.extraGroups = [ "vault-history" ]; } // lib.optionalAttrs hermesEnabled {
      hermes.extraGroups = [ "vault-history" ];
    };

    systemd.tmpfiles.rules = [
      "d ${dirOf cfg.repoDir} 0700 ${cfg.user} ${cfg.group} - -"
      "d ${historyDir} 2750 ${cfg.user} vault-history - -"
    ] ++ lib.optionals hermesEnabled [
      "d ${requestDir} 0711 root root - -"
      "d ${readyDir} 0700 hermes hermes - -"
      "d ${stagingDir} 0700 hermes hermes - -"
      "d ${resultsDir} 2750 root hermes - -"
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
        ReadWritePaths = [ (dirOf cfg.repoDir) historyDir ]
          ++ lib.optional (cfg.lockFile != null) (dirOf cfg.lockFile);
        UMask = "0077";
      };
    };

    systemd.services.vault-snapshot-requested = lib.mkIf hermesEnabled {
      description = "Requested Git snapshot of the Obsidian vault";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart =
          if cfg.lockFile == null then requestedSnapshot
          else "${pkgs.util-linux}/bin/flock -w 600 ${cfg.lockFile} ${requestedSnapshot}";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateNetwork = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ (dirOf cfg.repoDir) historyDir ]
          ++ lib.optional (cfg.lockFile != null) (dirOf cfg.lockFile);
        UMask = "0077";
      };
    };
    systemd.paths.vault-save-request = lib.mkIf hermesEnabled {
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      pathConfig = {
        DirectoryNotEmpty = readyDir;
        Unit = "vault-save-request.service";
      };
    };
    systemd.services.vault-save-request = lib.mkIf hermesEnabled {
      description = "Run vault sync and snapshot requested by Hermes";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = processRequest;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        ReadWritePaths = [ requestDir ];
        UMask = "0027";
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
