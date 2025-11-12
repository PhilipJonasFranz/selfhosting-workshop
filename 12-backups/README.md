# 12 - Backups

In this section, we’ll explore how to back up our Docker Compose stacks. Backups are essential to keep your data safe, to protect from hardware failure, human error, or ransomware. 

A commonly used rule is the **3-2-1 rule**: keep three copies of your data, on two different storage types, with one copy off-site. 

We will explore Restic to create backups, learn how to restore them, understand how to make backups to a remote host, and discover how to automate the process. By the end, you’ll have a practical, self-hosted backup setup that you can trust.

# Restic

In the previous sections, we introduced a standardized scheme for managing and deploying compose stacks. The stacks are all organized in directories with a consistent naming scheme: `containers/<stack name>/{docker-compose.yml, data, config}`. We now use this standardization to our advantage and build a backup solution around it. We will be using [Restic](https://github.com/restic/restic).

To get started, install the restic package:

```bash
sudo apt install restic
```

Create an environment file with the restic credentials `.restic.env`:

```bash
export RESTIC_REPOSITORY=/home/user/backup
export RESTIC_PASSWORD="CHANGE_ME"
```

Load the environment variables with `source .restic.env`. Next, initialize the restic repository, which will store the backup data for all compose stacks:

```bash
restic init
```

To back up a compose stack, we will back up its directory, i.e., `containers/<stack>/*`. Before we can back up a stack, we must stop it in case databases or other processes are active, to ensure a consistent backup. Then we back up the folder, and tag the backup with the stack name. Afterwards, we restart the compose stack if it was running. Finally, we delete old backups to ensure our backup storage does not fill up. 

This can be automated with a `bash` script. Create a file `backup.sh` in the same directory as the env file with the content:

```bash
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
```

Run the script with `sudo -E bash backup.sh`. After it completes, you should be able to inspect the snapshots:

```bash
source ".restic.env"
sudo -E restic snapshots
```

## Restoring a Backup

To restore a backup, either a full backup or a selective backup can be restored. See the commands below for some examples:

```bash
source .restic.env

# List all snapshots
sudo -E restic snapshots

# List all snapshots for tag/stack
sudo -E restic snapshots --tag authelia

# Restore latest backups for all stacks
# Note: --target / will restore all files to original location, as backup contains absolute path
sudo -E restic restore latest --target /

# Restore latest backups for specific label/stack
sudo -E restic restore latest --tag authelia --target /

# Restore specific backup for specific label/stack
# Step 1: get snapshot ID: restic snapshots --tag authelia
# Example output:
# 
# repository 45ac7224 opened (version 2, compression level auto)
# ID        Time                 Host         Tags        Paths
# --------------------------------------------------------------------------------------
# 68df310f  2025-10-28 19:19:16  vlab-docker  authelia    /home/user/containers/authelia
# 43dabc58  2025-10-28 19:20:23  vlab-docker  authelia    /home/user/containers/authelia
# --------------------------------------------------------------------------------------
# 2 snapshots
#
# Step 2: restore backup, e.g. snapshot 68df310f
sudo -E restic restore 68df310f --tag authelia --target /
```

## Backup Push Notifications

To prevent failing backups going unnoticed, we can integrate a push-notification service into the `backup.sh` script. It will send a notification whenever a backup fails. This step is optional, but highly recommended.

Push notifications can be quite complicated to set up on mobile devices due to their tight integration with the operating system. It's thus best to rely on a third party for that. [Pushover](https://pushover.net/) is a service that comes with Client applications for Android, iOS, Desktop, and a web application. The service is not free, but it has a one-time fee of only 5€ to unlock Push notifications for **one** of the aforementioned platforms. For example, if you are an exclusive Apple user, you pay 5€ once to receive push notifications across the entire Apple ecosystem for the rest of your life. If you also want Android support, you pay an additional € 5. If you are unsure, a 30-day free trial period is available.

After you have signed up, create a new Application and name it, e.g., `Restic Backups`. You will be presented with an application key. Keep it safe! We also need the user key. Create a new `.pushover.env` file in the same directory as the Restic env file and backup script:

```bash
export PUSHOVER_USER="CHANGE_ME"
export PUSHOVER_TOKEN="CHANGE_ME"
```

Download the mobile app for either iOS or Android and log in with your email and password for the Pushover account. You will be prompted to register the device, after which the 30-day trial period will start.

To integrate push notifications, we extend the `backup.sh`. Pushover messages can be sent by calling a URL with specific parameters. This makes it easy to integrate push notifications into any service, as only minimal dependencies, in this case `curl`, are required:

```bash
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
```

The full updated backup script can be found in `configurations/backup-with-push.sh`. Copy its contents and overwrite the existing `backup.sh` file. To verify that push notifications are working, uncomment the first line after the `send_notification` function in the updated script and run with `sudo -E bash backup.sh`.

## Backups to S3

Simple Storage Service (S3) is a REST API-based protocol that enables interaction with object storage services. It was originally created by Amazon, but open source implementations are available. A popular implementation is MinIO. However, the company behind this product decided several months ago to effectively discontinue the community edition of MinIO by removing most of its features. As it is not clear how this project will evolve in the coming months, we will use [Garage](https://github.com/deuxfleurs-org/garage), [project website](https://garagehq.deuxfleurs.fr/).

To deploy Garage, copy the configuration files to the backup server. The structure of this compose stack is a little different than what we have seen before:

```yaml
services:
  garage:
    image: dxflrs/garage:v2.0.0
    container_name: garage
    volumes:
      - ./config/garage.toml:/etc/garage.toml
      - ./data/meta:/var/lib/garage/meta
      - ./data/data:/var/lib/garage/data
    restart: unless-stopped
    networks:
      - internal
      - proxy
    labels:
      - "traefik.enable=true"

      - "traefik.http.routers.garage-s3.entrypoints=https"
      - "traefik.http.routers.garage-s3.rule=Host(`s3.$MY_DOMAIN`)"
      - "traefik.http.routers.garage-s3.priority=1000"
      - "traefik.http.routers.garage-s3.tls=true"
      - "traefik.http.routers.garage-s3.service=garage"
      - "traefik.http.routers.garage-s3.middlewares=default-headers@file"
      - "traefik.http.services.garage.loadbalancer.server.port=3900"
      
      - "traefik.docker.network=proxy"

  webui:
    image: khairul169/garage-webui:latest
    container_name: garage-webui
    restart: unless-stopped
    volumes:
      - ./config/garage.toml:/etc/garage.toml:ro
    networks:
      - internal
      - proxy
    environment:
      API_BASE_URL: "http://garage:3903"
      S3_ENDPOINT_URL: "http://garage:3900"
      AUTH_USER_PASS: "CHANGE_ME"
    labels:
      - "traefik.enable=true"

      - "traefik.http.routers.Garage.entrypoints=https"
      - "traefik.http.routers.Garage.rule=Host(`garage.$MY_DOMAIN`)"
      - "traefik.http.routers.Garage.priority=1000"
      - "traefik.http.routers.Garage.tls=true"
      - "traefik.http.routers.Pi-hole.tls.certresolver=cloudflare"
      - "traefik.http.routers.Pi-hole.tls.domains[0].main=$MY_DOMAIN"
      - "traefik.http.routers.Pi-hole.tls.domains[0].sans=*.$MY_DOMAIN"
      - "traefik.http.routers.Garage.service=garage-webui"
      - "traefik.http.routers.Garage.middlewares=default-headers@file"
      - "traefik.http.services.garage-webui.loadbalancer.server.port=3909"
      
      - "traefik.docker.network=proxy"

networks:
  internal:
  proxy:
    external: true
```

The definition for the garage service is pretty standard; however, the container has two networks: `internal` and `proxy`. Looking at the webui service, we can see the value `http://garage:3903` in the environment variables. This is a Docker DNS name that gets resolved to the IP address of the garage container in the `internal` subnet. As the containers are both part of the `internal` network, they can communicate directly through this subnet. The web UI has its own set of Traefik labels to expose the management UI on its respective port. Hence, requests to the garage API will be proxied through traffic, as well as requests to the web UI.

The web UI expects a password hash as an environment variable, which can be obtained with:

```bash
sudo apt install apache2-utils
htpasswd -nbBC 10 "<USERNAME>" "<PASSWORD>" | sed 's/\$/\$\$/g'
```

Before bringing up the stack, head to your Pi-hole Web-UI and create local DNS records for `garage.$MY_DOMAIN` and `s3.$MY_DOMAIN`, pointing to the IP address of the backup server.

Bring up the stack and head to `https://garage.$MY_DOMAIN`. Log in to the web UI and head over to `Cluster` and select the existing entry with the three dots and hit `Assign`. Create a new zone name, e.g., `backup`, enter a capacity, and click `Save` and `Apply`. Afterwards, create a new Key and give it a name, e.g., `backup-user`. Copy the Key ID and Secret Key for later use.

Next, create a bucket named `backup`. Select `Manage > Permissions` on the bucket and add the key with Read, Write, and Owner permissions.

Back on the Docker host, we need to supply Restic with the S3 credentials. Replace the content of the `.restic.env` file with:

```bash
export AWS_ACCESS_KEY_ID="<Key-ID from Garage>"
export AWS_SECRET_ACCESS_KEY="<Secret-Key from Garage>"
export RESTIC_PASSWORD="CHANGE_ME"
export RESTIC_REPOSITORY="s3:s3.$MY_DOMAIN/backup"
```

Ensure that the bucket name equals the part behind the domain in the `RESTIC_REPOSITORY` variable!

The environment file can be loaded with `source .restic.env`. Next, run `restic init` again to create the repository in the S3 bucket. From here, the `backup.sh` will automatically load the new credentials and write the data to the S3 endpoint. You can verify that everything works by browsing the `backup` bucket in the Garage web UI.

## Scheduled Backups with Cron

For automated backups, we will be using cron. Assuming you have the `backup.sh` and `.restic.env` files in your user's home directory, create the new cron job:

```bash
sudo crontab -e
```

Add the following line at the bottom of the file:

```bash
0 3 * * * /home/user/backup.sh >> /var/log/backup.log 2>&1
```

This will make a backup every day at 3:00 am. A helpful tool to generate the cron schedule can be found at [crontab.guru](https://crontab.guru/).