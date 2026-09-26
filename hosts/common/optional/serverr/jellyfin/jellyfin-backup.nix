{ config, lib, pkgs, ... }:
let
  cfg = config.services.jellyfin-backup;
  src = toString cfg.sourceDir;
  # Paths inside the zip (leading slash stripped) so zip -x matches stored names.
  sourceRel = lib.removePrefix "/" src;
  sqliteDataDbs = [
    "jellyfin.db"
    "library.db"
    "playback_reporting.db"
  ];
  zipExcludeFlags = lib.concatStringsSep "" (
    map (sub: " -x " + lib.escapeShellArg (sourceRel + "/" + sub)) cfg.excludeSuffixes
  );
  # Live DB + WAL/SHM must not be zipped as-is (inconsistent while Jellyfin runs).
  zipExcludeSqliteLive = lib.concatStringsSep "" (
    map (p: " -x " + lib.escapeShellArg p) (
      lib.concatMap (name: [
        (sourceRel + "/data/" + name)
        (sourceRel + "/data/" + name + "-wal")
        (sourceRel + "/data/" + name + "-shm")
      ]) sqliteDataDbs
    )
  );
  ownershipLine =
    if cfg.fileUser == null then
      "chgrp ${lib.escapeShellArg cfg.fileGroup} \"$BACKUP_FILE\""
    else
      "chown ${lib.escapeShellArg cfg.fileUser}:${lib.escapeShellArg cfg.fileGroup} \"$BACKUP_FILE\"";
  backupScript = pkgs.writeShellScriptBin "jellyfin-backup" ''
    set -euo pipefail
    SOURCE_DIR=${lib.escapeShellArg src}
    SOURCE_REL=${lib.escapeShellArg sourceRel}
    BACKUP_DIR=${lib.escapeShellArg cfg.destinationDir}
    DATE=$(date +%Y-%m-%d)
    BACKUP_FILE="$BACKUP_DIR/jellyfin-backup-$DATE.zip"
    KEEP=${toString cfg.keep}
    SQLITE3=${lib.getExe pkgs.sqlite}

    mkdir -p "$BACKUP_DIR"
    # Start fresh on same-day re-runs (zip would otherwise append to the old archive)
    rm -f "$BACKUP_FILE"
    # Stage next to the backups, DB snapshots can be too big for a tmpfs /tmp
    STAGE="$(mktemp -d "$BACKUP_DIR/.jellyfin-backup-stage.XXXXXX")"
    cleanup() { rm -rf "$STAGE"; }
    trap cleanup EXIT

    # 1) Zip everything except live SQLite DBs + WAL/SHM (paths match archive: $SOURCE_REL/...).
    ( cd / && ${lib.getExe pkgs.zip} -rq "$BACKUP_FILE" "$SOURCE_REL"${zipExcludeFlags}${zipExcludeSqliteLive} )

    # 2) Consistent SQLite snapshots via .backup, then merge into the same zip.
    mkdir -p "$STAGE/$SOURCE_REL/data"
    db_snapped=0
    for db in ${lib.concatStringsSep " " sqliteDataDbs}; do
      if [[ -f "$SOURCE_DIR/data/$db" ]]; then
        dest="$STAGE/$SOURCE_REL/data/$db"
        printf '.timeout 120000\n.backup %s\n' "$dest" | "$SQLITE3" "$SOURCE_DIR/data/$db" \
          || { echo "jellyfin-backup: sqlite .backup failed for data/$db (is Jellyfin running and DB readable?)" >&2; exit 1; }
        db_snapped=1
      fi
    done
    if (( db_snapped )); then
      ( cd "$STAGE" && ${lib.getExe pkgs.zip} -rq "$BACKUP_FILE" "$SOURCE_REL/data" )
    fi

    ${ownershipLine}
    chmod 664 "$BACKUP_FILE"

    mapfile -t files < <(ls -t "$BACKUP_DIR"/jellyfin-backup-*.zip 2>/dev/null || true)
    if (( ''${#files[@]} > KEEP )); then
      for ((i = KEEP; i < ''${#files[@]}; i++)); do
        rm -f "''${files[i]}"
      done
    fi
  '';
  restoreScript = pkgs.writeShellScriptBin "jellyfin-backup-restore" ''
    set -euo pipefail

    BACKUP_DIR=${lib.escapeShellArg cfg.destinationDir}
    DEFAULT_TARGET=${lib.escapeShellArg src}

    usage() {
      cat <<'EOF'
Usage:
  jellyfin-backup-restore --list
  jellyfin-backup-restore <zip-file-or-date> [--target DIR] [--yes]

Examples:
  jellyfin-backup-restore --list
  jellyfin-backup-restore 2026-04-25
  jellyfin-backup-restore jellyfin-backup-2026-04-25.zip --target /tmp/jellyfin-restore --yes

Notes:
  - The date form maps to: jellyfin-backup-YYYY-MM-DD.zip
  - Without --target, files are restored to the configured sourceDir.
  - Existing files in target are overwritten by restored files.
EOF
    }

    list_backups() {
      shopt -s nullglob
      local files=("$BACKUP_DIR"/jellyfin-backup-*.zip)
      if (( ''${#files[@]} == 0 )); then
        echo "No backups found in $BACKUP_DIR"
        return 0
      fi
      printf "Available backups in %s:\n" "$BACKUP_DIR"
      ls -1t "$BACKUP_DIR"/jellyfin-backup-*.zip
    }

    if [[ "''${1-}" == "--list" ]]; then
      list_backups
      exit 0
    fi

    if [[ $# -lt 1 ]]; then
      usage
      exit 1
    fi

    selection="$1"
    shift

    TARGET_DIR="$DEFAULT_TARGET"
    ASSUME_YES=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --target)
          [[ $# -ge 2 ]] || { echo "--target requires a value" >&2; exit 1; }
          TARGET_DIR="$2"
          shift 2
          ;;
        --yes)
          ASSUME_YES=1
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          echo "Unknown argument: $1" >&2
          usage
          exit 1
          ;;
      esac
    done

    if [[ "$selection" == */* || "$selection" == *.zip ]]; then
      BACKUP_FILE="$selection"
    else
      BACKUP_FILE="$BACKUP_DIR/jellyfin-backup-$selection.zip"
    fi

    if [[ ! -f "$BACKUP_FILE" ]]; then
      echo "Backup file not found: $BACKUP_FILE" >&2
      echo "Tip: use --list to see available backups." >&2
      exit 1
    fi

    SOURCE_REL="''${DEFAULT_TARGET#/}"
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    echo "Selected backup: $BACKUP_FILE"
    echo "Restore target : $TARGET_DIR"

    if (( ASSUME_YES == 0 )); then
      read -r -p "Continue restore? [y/N] " reply
      if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        echo "Restore canceled."
        exit 0
      fi
    fi

    mkdir -p "$TARGET_DIR"
    ${lib.getExe pkgs.unzip} -q "$BACKUP_FILE" -d "$TMP_DIR"

    EXTRACTED_SOURCE="$TMP_DIR/$SOURCE_REL"
    if [[ ! -d "$EXTRACTED_SOURCE" ]]; then
      echo "Expected restored source path not found in archive: $EXTRACTED_SOURCE" >&2
      echo "Archive may not match current sourceDir ($DEFAULT_TARGET)." >&2
      exit 1
    fi

    # Copy restored content over target while preserving metadata when possible.
    ${lib.getExe pkgs.rsync} -a --info=progress2 "$EXTRACTED_SOURCE"/ "$TARGET_DIR"/
    echo "Restore complete: $BACKUP_FILE -> $TARGET_DIR"
  '';
  itemMetadataScript = pkgs.writeShellScriptBin "jellyfin-item-metadata" ''
    set -euo pipefail

    SOURCE_DIR=${lib.escapeShellArg src}
    BACKUP_DIR=${lib.escapeShellArg cfg.destinationDir}
    LIBRARY_DIR="$SOURCE_DIR/metadata/library"
    DB_PATH="$SOURCE_DIR/data/library.db"

    usage() {
      cat <<'EOF'
Usage:
  jellyfin-item-metadata search "<title>"
  jellyfin-item-metadata backup "<title>" [--output /path/file.zip]
  jellyfin-item-metadata restore <item-backup.zip> [--yes]

What it does:
  - Searches Jellyfin DB by title text and resolves metadata/library image folders.
  - Backs up matching metadata folders (custom metadata + images) into one zip.
  - Restores those folders back into sourceDir.

Examples:
  jellyfin-item-metadata search "The Office"
  jellyfin-item-metadata backup "The Office"
  jellyfin-item-metadata restore /mnt/mediapool/mainet/_bk/scheduled/jellyfin-item-the-office-2026-04-25.zip
EOF
    }

    slugify() {
      local in="$1"
      in="$(printf '%s' "$in" | tr '[:upper:]' '[:lower:]')"
      in="$(printf '%s' "$in" | tr -cs 'a-z0-9' '-')"
      in="''${in#-}"
      in="''${in%-}"
      printf '%s' "''${in:-item}"
    }

    collect_matches() {
      local query="$1"
      local query_sql
      local sql
      local line
      local table_name
      local id_col
      local name_col
      local type_col
      local images_col
      local type_select
      local images_select
      local col_exists
      local id_raw
      local name
      local type
      local id_hex
      local images_path
      local metadata_dir
      local matched_rows
      local resolved_rows

      if [[ ! -d "$LIBRARY_DIR" ]]; then
        echo "Jellyfin metadata/library not found: $LIBRARY_DIR" >&2
        return 1
      fi

      if [[ ! -f "$DB_PATH" ]]; then
        echo "Jellyfin DB not found: $DB_PATH" >&2
        return 1
      fi

      table_name="$(${lib.getExe pkgs.sqlite} -noheader "$DB_PATH" "
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name IN ('TypedBaseItems', 'BaseItems')
        ORDER BY CASE name WHEN 'TypedBaseItems' THEN 0 ELSE 1 END
        LIMIT 1;
      ")"
      if [[ -z "$table_name" ]]; then
        echo "Could not find TypedBaseItems/BaseItems in $DB_PATH" >&2
        return 1
      fi

      pick_col() {
        local tbl="$1"
        shift
        local candidate
        local found=""
        for candidate in "$@"; do
          col_exists="$(${lib.getExe pkgs.sqlite} -noheader "$DB_PATH" "
            SELECT 1
            FROM pragma_table_info('$tbl')
            WHERE name = '$candidate'
            LIMIT 1;
          ")"
          if [[ "$col_exists" == "1" ]]; then
            found="$candidate"
            break
          fi
        done
        printf '%s' "$found"
      }

      id_col="$(pick_col "$table_name" Id ItemId Guid guid PresentationUniqueKey)"
      name_col="$(pick_col "$table_name" Name)"
      type_col="$(pick_col "$table_name" Type MediaType)"
      images_col="$(pick_col "$table_name" ImagesPath)"
      if [[ -z "$id_col" || -z "$name_col" ]]; then
        echo "Unsupported Jellyfin schema in table $table_name (missing id/name columns)." >&2
        return 1
      fi

      if [[ -n "$type_col" ]]; then
        type_select="$type_col AS item_type"
      else
        type_select="NULL AS item_type"
      fi

      if [[ -n "$images_col" ]]; then
        images_select="$images_col AS item_images_path"
      else
        images_select="NULL AS item_images_path"
      fi

      query_sql="''${query//\'/\'\'}"
      sql="
        SELECT
          $id_col AS item_id,
          $name_col AS item_name,
          $type_select,
          $images_select
        FROM $table_name
        WHERE $name_col LIKE '%$query_sql%'
        ORDER BY $name_col;
      "
      mapfile -t rows < <(${lib.getExe pkgs.sqlite} -noheader -separator $'\t' "$DB_PATH" "$sql" || true)
      if (( ''${#rows[@]} == 0 )); then
        LAST_DB_MATCH_COUNT=0
        LAST_RESOLVED_COUNT=0
        return 0
      fi

      matched_rows=''${#rows[@]}
      resolved_rows=0
      declare -A seen=()
      MATCH_DIRS=()
      MATCH_INFO=()
      for line in "''${rows[@]}"; do
        IFS=$'\t' read -r id_raw name type images_path <<< "$line"
        metadata_dir=""

        if [[ -n "$images_path" ]]; then
          if [[ "$images_path" == /* ]]; then
            metadata_dir="$images_path"
          else
            metadata_dir="$SOURCE_DIR/''${images_path#/}"
          fi
        else
          id_hex="$(printf '%s' "$id_raw" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-f0-9')"
          if [[ "$id_hex" =~ ^[a-f0-9]{32}$ ]]; then
            metadata_dir="$LIBRARY_DIR/''${id_hex:0:2}/$id_hex"
          fi
        fi

        if [[ -n "$metadata_dir" && -z "''${seen[$metadata_dir]+x}" ]]; then
          seen["$metadata_dir"]=1
          MATCH_DIRS+=("$metadata_dir")
          if [[ -d "$metadata_dir" ]]; then
            MATCH_INFO+=("$name|$type|$metadata_dir")
            resolved_rows=$((resolved_rows + 1))
          else
            MATCH_INFO+=("$name|$type|$metadata_dir|unverified-path")
          fi
        fi
      done
      LAST_DB_MATCH_COUNT=$matched_rows
      LAST_RESOLVED_COUNT=$resolved_rows
    }

    [[ $# -ge 1 ]] || {
      usage
      exit 1
    }

    cmd="$1"
    shift

    case "$cmd" in
      search)
        [[ $# -eq 1 ]] || { usage; exit 1; }
        query="$1"
        MATCH_DIRS=()
        collect_matches "$query"
        if (( ''${#MATCH_DIRS[@]} == 0 )); then
          echo "No metadata matches for: $query"
          exit 0
        fi
        if (( LAST_DB_MATCH_COUNT > 0 && LAST_RESOLVED_COUNT == 0 )); then
          echo "DB matched $LAST_DB_MATCH_COUNT item(s), but no metadata paths were confirmed."
          echo "If Jellyfin metadata dirs are permission-restricted, run with sudo."
        fi
        echo "Matches for \"$query\":"
        printf '  %s\n' "''${MATCH_INFO[@]}"
        ;;

      backup)
        [[ $# -ge 1 ]] || { usage; exit 1; }
        query="$1"
        shift

        out_file=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --output)
              [[ $# -ge 2 ]] || { echo "--output requires a value" >&2; exit 1; }
              out_file="$2"
              shift 2
              ;;
            *)
              echo "Unknown argument: $1" >&2
              usage
              exit 1
              ;;
          esac
        done

        MATCH_DIRS=()
        collect_matches "$query"
        if (( ''${#MATCH_DIRS[@]} == 0 )); then
          echo "No metadata matches for: $query"
          exit 1
        fi
        if (( LAST_DB_MATCH_COUNT > 0 && LAST_RESOLVED_COUNT == 0 )); then
          echo "DB matched $LAST_DB_MATCH_COUNT item(s), but no metadata paths were confirmed."
          echo "Likely permissions. Try running backup with sudo."
        fi

        mkdir -p "$BACKUP_DIR"
        if [[ -z "$out_file" ]]; then
          stamp="$(date +%Y-%m-%d)"
          out_file="$BACKUP_DIR/jellyfin-item-$(slugify "$query")-$stamp.zip"
        fi

        tmp_list="$(mktemp)"
        trap 'rm -f "$tmp_list"' EXIT
        for dir in "''${MATCH_DIRS[@]}"; do
          printf '%s\n' "''${dir#"$SOURCE_DIR"/}" >> "$tmp_list"
        done

        (
          cd "$SOURCE_DIR"
          ${lib.getExe pkgs.zip} -q -r "$out_file" -@ < "$tmp_list"
        )
        echo "Item metadata backup written: $out_file"
        echo "Included items:"
        printf '  %s\n' "''${MATCH_INFO[@]}"
        ;;

      restore)
        [[ $# -ge 1 ]] || { usage; exit 1; }
        in_file="$1"
        shift
        assume_yes=0
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --yes)
              assume_yes=1
              shift
              ;;
            *)
              echo "Unknown argument: $1" >&2
              usage
              exit 1
              ;;
          esac
        done

        [[ -f "$in_file" ]] || { echo "Backup zip not found: $in_file" >&2; exit 1; }
        if (( assume_yes == 0 )); then
          echo "Restore source: $in_file"
          echo "Restore target: $SOURCE_DIR"
          read -r -p "Continue restore of item metadata/images? [y/N] " reply
          [[ "$reply" =~ ^[Yy]$ ]] || { echo "Restore canceled."; exit 0; }
        fi

        ${lib.getExe pkgs.unzip} -o -q "$in_file" -d "$SOURCE_DIR"
        echo "Restore complete: $in_file -> $SOURCE_DIR"
        ;;

      -h|--help|help)
        usage
        ;;

      *)
        echo "Unknown command: $cmd" >&2
        usage
        exit 1
        ;;
    esac
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
        Path suffixes under sourceDir passed to zip -x (relative to the archive root, same as
        sourceDir without leading slash, e.g. `var/lib/jellyfin/cache/*`).
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
    environment.systemPackages = [
      restoreScript
      itemMetadataScript
    ];

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
