#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
DEST="/home/outsideworx/sites"

set -e

if [ "$1" == "--install" ]; then
    apt update
    apt install -y openjdk-25-jdk maven docker.io
    exit 0
fi

if [ -n "$1" ]; then
    echo "Error: Unknown parameter '$1'"
    exit 1
fi

echo "Copying standalone project files to: $DEST."
rm -rf "$DEST"
mkdir -p "$DEST"
cp "$SCRIPT_DIR/.env" \
   "$SCRIPT_DIR/blacklist.conf" \
   "$SCRIPT_DIR/compose.yaml" \
   "$SCRIPT_DIR/Dockerfile" \
   "$DEST"

echo "Container deployment starts."
cd "$DEST"
docker compose build --no-cache --pull
docker compose up --force-recreate --no-deps -d
echo "Sleep, to make sure everything is running."
sleep 10
docker system prune -af
docker stats
