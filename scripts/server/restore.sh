#!/bin/bash
# This script restores Syncthing server data from a backup archive
# Usage: ./restore.sh [<file>]

set -euo pipefail

source .env

BACKUP_FILE_PATH=$1 # Absolute path to the backup file
SYNCTHING_VOLUME_NAME="${COMPOSE_PROJECT_NAME}_${VOLUME_NAME}"

if [ ! -e "$BACKUP_FILE_PATH" ]; then
  echo "error: $BACKUP_FILE_PATH backup file doesn't exist"
  exit 1
fi

# Validate the backup file
if ! file "$BACKUP_FILE_PATH" | grep -q "gzip compressed data"; then
  echo "error: backup file is not a compressed tar archive $(file "$BACKUP_FILE_PATH")"
  exit 1
fi

docker compose down

docker run \
  -v "${SYNCTHING_VOLUME_NAME}":/data \
  -v "$(dirname "$BACKUP_FILE_PATH")":/backup \
  --rm \
  busybox \
  tar -xzvf "/backup/$(basename "$BACKUP_FILE_PATH")" -C /data .

docker compose up -d
