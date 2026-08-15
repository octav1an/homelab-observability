#!/bin/bash
# Release the new version of the service (script should be copied on remote)
# To rollback: './release.sh rollback'

set -xeuo pipefail

BACKUP_DIR=release.old
DEPLOY_LIST_FILE=deploy.list

rollback() {
  docker compose down

  if [ ! -d $BACKUP_DIR ]; then
    echo "error: '$BACKUP_DIR' folder with backup artifacts doesn't exist"
    exit 1
  fi

  echo "starting rollback..."
  cp -r $BACKUP_DIR/. .
  echo "ended rollback"
  
  docker compose up -d
}

if [ "${1:-}" = "rollback" ]; then
  rollback
  exit 0
fi

echo "stopping app..."
docker compose down || true

# make a backup of the existing images for a rollback
[ ! -d "$BACKUP_DIR" ] && mkdir $BACKUP_DIR

# Backup all current configs before unzipping the archive
while read -r item; do
  if [ -e "${item}" ]; then
    cp -R "${item}" $BACKUP_DIR
  fi
done < "${DEPLOY_LIST_FILE}"

echo "starting app..."
docker compose up -d
