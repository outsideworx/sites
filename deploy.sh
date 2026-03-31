#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
DEST="/home/outsideworx/sites"

if [ "$1" == "--letsencrypt" ]; then
    # WARNING: For this section to work, port 80 has to be open and accessible via the below mentioned address.
    apt update
    apt install -y certbot
    certbot certonly --standalone --noninteractive --agree-tos --email info@outsideworx.net -d sites.outsideworx.net
fi

echo "Copying project files to: $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"
cp "$SCRIPT_DIR/.env" \
   "$SCRIPT_DIR/blacklist.conf" \
   "$SCRIPT_DIR/compose.yaml" \
   "$SCRIPT_DIR/Dockerfile" \
   "$DEST"

echo "Deployment starts"
cd "$DEST"
docker compose build --no-cache --pull
docker compose up --force-recreate --no-deps -d
docker system prune -af
docker stats
