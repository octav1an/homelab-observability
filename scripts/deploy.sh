#!/usr/bin/env bash
# Deploys app file from deploy.list to the target server

set -euo pipefail

DEPLOYMENT_TYPE=""
CHECK_STATUS=false
ROLLBACK=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        dev|prod)
            DEPLOYMENT_TYPE=$1
            shift
            ;;
        --check)
            CHECK_STATUS=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
            shift
            ;;
        *)
            echo "error: unknown argument $1"
            exit 1
            ;;
    esac
done

if [ "${DEPLOYMENT_TYPE}" == "dev" ]; then
    source .deploy.dev.env
elif [ "${DEPLOYMENT_TYPE}" == "prod" ]; then
    source .deploy.env
else
    echo "error: deployment type unset or unknown (allowed: dev or prod)"
    exit 1
fi

: "${HOST:?HOST must be set in .deploy.env}"
: "${USER:?USER must be set in .deploy.env}"
: "${COMPOSE_PROJECT_NAME:?COMPOSE_PROJECT_NAME must be set in .deploy.env}"

if [ ! -e "deploy.list" ]; then 
    echo "error: 'deploy.list' file doesn't exist"
    exit 1
fi

DEST_DIR=services/$COMPOSE_PROJECT_NAME
DEST=$USER@$HOST:$DEST_DIR

# Check service status
if [[ "$CHECK_STATUS" == true ]]; then
    ssh $USER@$HOST "cd '$DEST_DIR' && docker compose ps"
    exit 0
fi

if [[ "$ROLLBACK" == true ]]; then
    echo "Rolling back the release..."
    ssh $USER@$HOST "cd '$DEST_DIR' && ./scripts/server/release.sh rollback"
    exit 0
fi

# Create the service folder on the target server, if it doesn't exist
ssh $USER@$HOST 'mkdir -p $HOME/$DEST_DIR'

RSYNC_OPTS="-avz --progress --delete --relative"  # --delete: to remove deleted files on server

while read -r item; do
    if [ -e "$item" ]; then
        echo "copying ${item} to remote..."
        rsync ${RSYNC_OPTS} "$item" "$DEST/"
    else
        echo "warning: '$item' does not exist locally, skipping."
    fi
done < deploy.list

echo "Successfully copied app files"

# Rune the release script to restart the services
ssh $USER@$HOST "cd '$DEST_DIR' && ./scripts/server/release.sh"

