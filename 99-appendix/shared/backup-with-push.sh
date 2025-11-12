#!/usr/bin/env bash

set -a
source "/home/user/.restic.env"
source "/home/user/.pushover.env"
set +a

send_notification() {
    local MESSAGE="$1"
    local HOSTNAME
    HOSTNAME=$(hostname)
    local TIME
    TIME=$(date '+%Y-%m-%d %H:%M:%S')

    curl -s \
        -F "token=${PUSHOVER_TOKEN}" \
        -F "user=${PUSHOVER_USER}" \
        -F "message=[${TIME}] [${HOSTNAME}] ${MESSAGE}" \
        https://api.pushover.net/1/messages.json
}

# Uncomment to verify push notifications are working
# send_notification "Push notifications are working!"

for STACK in /home/user/containers/*; do
    [ -f "$STACK/docker-compose.yml" ] || continue
    NAME=$(basename "$STACK")

    # Check if stack has to be stopped
    RUNNING=$(docker compose -f "$STACK/docker-compose.yml" ps --status running --services)
    if [ -n "$RUNNING" ]; then
        docker compose -f "$STACK/docker-compose.yml" down
        STOPPED=true
    else
        STOPPED=false
    fi

    # Run backup
    if ! restic backup "$STACK" --tag "$NAME"; then
        send_notification "Backup failed for $NAME"
        [ "$STOPPED" = true ] && docker compose -f "$STACK/docker-compose.yml" up -d
        continue
    fi

    # Prune old snapshots
    if ! restic forget --tag "$NAME" --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune; then
        send_notification "Prune failed for $NAME"
    fi

    # Restart stack if it was stopped
    [ "$STOPPED" = true ] && docker compose -f "$STACK/docker-compose.yml" up -d
done