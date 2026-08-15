#!/bin/bash
# This script creates a backup archive of Syncthing server data from a Docker volume
# Usage: ./backup.sh [--no-downtime]

set -euo pipefail

if [ ! -f ".env" ]; then
  echo "error: missing .env file. Exiting." >&2
  exit 1
fi
source .env

BACKUP_DIR=backup
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:?"Must set COMPOSE_PROJECT_NAME in .env"}
VOLUME_NAME=${VOLUME_NAME:?"Must set VOLUME_NAME in .env"}
FULL_VOLUME="${COMPOSE_PROJECT_NAME}_${VOLUME_NAME}"

[ ! -d ${BACKUP_DIR} ] && mkdir ${BACKUP_DIR}

NO_DOWNTIME=false
if [ "${1:-}" = "--no-downtime" ];then
  NO_DOWNTIME=true
fi

log () { printf "[%s] %s\n" "$(date +%H:%M:%S.%3N)" "$*"; }

stop_containers () {
  $NO_DOWNTIME || { log "stopping containers..."; docker compose down; }
}

start_containers () {
  $NO_DOWNTIME || { log "starting containers..."; docker compose up -d; }
}

main() {
  stop_containers

  backup_name="data-$(date +%Y-%m-%d-%H-%M-%S).tar.gz"

  log "backing up volume $FULL_VOLUME..."
  docker run \
    -v "${FULL_VOLUME}":/data \
    -v "$(pwd)/${BACKUP_DIR}":/${BACKUP_DIR} \
    --rm \
    busybox \
    tar -czvf "/$BACKUP_DIR/$backup_name" -C /data .
  log "backup completed: $BACKUP_DIR/$backup_name"

  start_containers
}

main "$@"
