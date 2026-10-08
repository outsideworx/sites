#!/bin/bash

set -e
set -a; source .env; set +a
docker compose pull
docker stack deploy -c compose.yaml sites --detach=false --resolve-image=always
docker stack services sites --format '{{.Name}}' | xargs -rn1 docker service update --force
