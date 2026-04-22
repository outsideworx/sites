#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
DEST="/home/outsideworx/sites"

set -e

if [ "$1" == "--install" ]; then
    apt update
    apt install -y docker-compose-v2
    exit 0
fi

if [ -n "$1" ]; then
    echo "Error: Unknown parameter '$1'"
    exit 1
fi

echo "Copying project files to: $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"
cp "$SCRIPT_DIR/.env" \
   "$SCRIPT_DIR/blacklist.conf" \
   "$SCRIPT_DIR/compose.yaml" \
   "$DEST"

echo "Container deployment starts"
cd "$DEST"
set -a; source .env; set +a
docker stack deploy -c compose.yaml sites --detach=false --resolve-image=always
