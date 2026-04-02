{ config, lib, pkgs, ... }:
let
  cfg = config.services.jellyfin-backup;
  src = toString cfg.sourceDir;
  zipExcludeFlags = lib.concatStringsSep "" (
    map (sub: " -x " + lib.escapeShellArg (src + "/" + sub)) cfg.excludeSuffixes
  );
  ownershipLine =
    if cfg.fileUser == null then
      "chgrp ${lib.escapeShellArg cfg.fileGroup} \"$BACKUP_FILE\""
    else
      "chown ${lib.escapeShellArg cfg.fileUser}:${lib.escapeShellArg cfg.fileGroup} \"$BACKUP_FILE\"";
  backupScript = pkgs.writeShellScriptBin "jellyfin-backup" ''
    set -euo pipefail
    SOURCE_DIR=${lib.escapeShellArg src}
    BACKUP_DIR=${lib.escapeShellArg cfg.destinationDir}
    DATE=$(date +%Y-%m-%d)
    BACKUP_FILE="$BACKUP_DIR/jellyfin-backup-$DATE.zip"
    KEEP=${toString cfg.keep}

    mkdir -p "$BACKUP_DIR"
    # Overwrite same calendar day if the timer re-runs
    ${lib.getExe pkgs.zip} -rq "$BACKUP_FILE" "$SOURCE_DIR"${zipExcludeFlags}

    ${ownershipLine}
    chmod 664 "$BACKUP_FILE"

    mapfile -t files < <(ls -t "$BACKUP_DIR"/jellyfin-backup-*.zip 2>/dev/null || true)
    if (( ''${#files[@]} > KEEP )); then
      for ((i = KEEP; i < ''${#files[@]}; i++)); do
        rm -f "''${files[i]}"
      done
    fi
  '';
in
{
  options.services.jellyfin-backup = {
    enable = lib.mkEnableOption "periodic Jellyfin data directory backup (zip)";
    sourceDir = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      default = config.services.jellyfin.dataDir;
      description = "Jellyfin data directory to archive (--datadir), including config and metadata.";
    };
    excludeSuffixes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "cache/*"
        "log/*"
        "data/backups/*"
        # Actor/people images (~GB); re-fetched from providers; skip if you don’t care about custom people art
        "metadata/People/*"
      ];
      description = ''
        Path suffixes under sourceDir passed to zip -x.
        Keeps library metadata under metadata/library (and Studio/Genre/etc.) plus data/subtitles.
        Skips logs, cache, Jellyfin’s data/backups zips, and metadata/People (large, usually safe to regenerate).
        Remove the People line if you use custom people images or offline-only metadata.
      '';
    };
    destinationDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/mediapool/mainet/_bk/scheduled";
      description = "Directory for jellyfin-backup-YYYY-MM-DD.zip files.";
    };
    keep = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = "How many newest backup zips to retain.";
    };
    fileUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.services.jellyfin.user;
      description = ''
        Owner user for the backup zip. Set to null to only run chgrp (see fileGroup), leaving the
        creating user unchanged (with this service, typically root:media after chmod 664).
      '';
    };
    fileGroup = lib.mkOption {
      type = lib.types.str;
      default = config.services.jellyfin.group;
      description = "Owner group for the backup zip (chown); defaults to services.jellyfin.group.";
    };
    calendar = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        If set, timer uses only OnCalendar (e.g. "05:00" daily). If null, uses OnBootSec + OnUnitActiveSec
        instead (see interval).
      '';
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "5d";
      description = "When calendar is null: systemd OnUnitActiveSec after each successful backup run.";
    };
    firstRunAfterBoot = lib.mkOption {
      type = lib.types.str;
      default = "10min";
      description = "When calendar is null: systemd OnBootSec for the first run after boot.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.timers.jellyfin-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig =
        {
          Persistent = true;
          Unit = "jellyfin-backup.service";
        }
        // (
          if cfg.calendar != null then
            { OnCalendar = cfg.calendar; }
          else
            {
              OnBootSec = cfg.firstRunAfterBoot;
              OnUnitActiveSec = cfg.interval;
            }
        );
    };

    systemd.services.jellyfin-backup = {
      description = "Backup Jellyfin data directory to zip";
      after = [ "network.target" ];
      unitConfig.RequiresMountsFor = [
        (toString cfg.sourceDir)
        cfg.destinationDir
      ];
      path = with pkgs; [ coreutils ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = lib.getExe backupScript;
      };
    };
  };
}
