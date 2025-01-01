#!/usr/bin/env bash

# Define variables
SOURCE_DIR="/var/lib/jellyfin"
BACKUP_DIR="/var/lib/plex/mount/DJ/backups/scheduled"
DATE=$(date +"%Y-%m-%d")
BACKUP_FILE="$BACKUP_DIR/jellyfin-backup-$DATE.zip"

# Do
mkdir -p "$BACKUP_DIR"
zip -r "$BACKUP_FILE" "$SOURCE_DIR" \
    -x "$SOURCE_DIR/cache/*" \
    -x "$SOURCE_DIR/log/*" \
    -x "$SOURCE_DIR/metadata/*" \
    -x "$SOURCE_DIR/data/subtitles/*"
echo "Jellyfin backup completed: $BACKUP_FILE"
