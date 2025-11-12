#!/usr/bin/env bash

set -a
source "/home/user/.restic.env"
set +a

for STACK in /home/user/containers/*; do
    [ -f "$STACK/docker-compose.yml" ] || continue
    NAME=$(basename "$STACK")

    RUNNING=$(docker compose -f "$STACK/docker-compose.yml" ps --status running --services)
    if [ -n "$RUNNING" ]; then
        docker compose -f "$STACK/docker-compose.yml" down
        STOPPED=true
    else
        STOPPED=false
    fi

    restic backup "$STACK" --tag "$NAME"

    if [ "$STOPPED" = true ]; then
        docker compose -f "$STACK/docker-compose.yml" up -d
    fi

    restic forget --tag $NAME --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
done