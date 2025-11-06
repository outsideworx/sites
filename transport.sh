#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
if [ -z "$2" ]; then
    echo "Error: IP address is required as the second parameter!"
    exit 1
fi
SERVER_IP="$2"

if [ "$1" == "--deploy" ]; then
    echo "Uploading project: $SERVER_IP"
    rsync -rvh --delete \
        "$SCRIPT_DIR/.env" \
        "$SCRIPT_DIR/compose.yaml" \
        "$SCRIPT_DIR/Dockerfile" \
        root@"$SERVER_IP":/home/outsideworx/sites
    echo "Deployment starts: $SERVER_IP"
    ssh root@"$SERVER_IP" "
        cd /home/outsideworx/sites;
        docker compose build --no-cache --pull
        docker compose up --force-recreate --no-deps -d;
        docker system prune -af;
        docker logs oauth -f"
else
    echo "Error: Only deploy mode is supported!"
    exit 1
fi
