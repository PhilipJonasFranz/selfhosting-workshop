# 13 - Hosting Services

Now that the foundation of our infrastructure is complete, you can add additional services to it! Of course, there is an endless number of services one could self-host, and it's up to you to choose which you want to run. Some great resources to find self-hosted software are given below:

- [selfh.st/apps](https://selfh.st/apps/)
- [Awesome selfhosted list](https://github.com/awesome-selfhosted/awesome-selfhosted)

For this section, we have prepared a set of services that you can spin up to get familiar with how to add services to your infrastructure. However, if you want to experiment and deploy a service that's not on the list, feel free to ask us for help or experiment on your own!

# Selected Services

There are two services I would like to highlight as they integrate well with Traefik and the existing infrastructure:

- Trala, [GitHub repo](https://github.com/dannybouwers/trala): Dynamic Dashboard based on Traefik Routers
- Traefik Log Dashboard, [GitHub repo](https://github.com/hhftechnology/traefik-log-dashboard): Traefik Access Log Dashboard

I also want to highlight a few services I use personally and can recommend:

- [Portainer](https://www.portainer.io/), [GitHub repo](https://github.com/portainer/portainer): Visual container management tool
- [Docmost](https://docmost.com/), [GitHub repo](https://github.com/docmost/docmost): Collaborative Wiki Platform
- [Immich](https://immich.app/), [GitHub repo](https://github.com/immich-app/immich): Google Images alternative with mobile apps and automatic photo upload
- [Nextcloud](https://nextcloud.com/), [GitHub repo](https://github.com/nextcloud/server): Google Drive / Dropbox alternative, with extensive plugin ecosystem
- [Forgejo](https://forgejo.org/), [Codeberg repo](https://codeberg.org/forgejo/forgejo): Self-hosted Git Server

## Trala

Trala is a neat piece of software that pulls the route lists from the Traefik API, extracts the URLs and Service names, matches them against an icon database, and renders all active services into a dashboard. This eliminates the need to manually update the dashboard each time you add or remove a service.

To start setting up Trala, first edit the `traefik.yml` configuration file. Add a new entry point for internal communication between Traefik and Trala:

```diff
 entryPoints:
   http:
     address: ":80"
     http:
       redirections:
         entryPoint:
           to: https
           scheme: https
   https:
     address: ":443"
+  traefik-internal:
+    address: ":8081"
```

Next, we amend the `docker-compose.yml` file of the Traefik stack:

```diff
 services:
+  trala:
+    image: ghcr.io/dannybouwers/trala:latest
+    container_name: trala
+    restart: unless-stopped
+    networks:
+      - internal
+    volumes:
+    - ./config/trala.yml:/config/configuration.yml:ro
+    labels:
+      - "traefik.enable=true"
+
+      - "traefik.http.routers.trala.entrypoints=https"
+      - "traefik.http.routers.trala.rule=Host(`$MY_DOMAIN`)"
+      - "traefik.http.routers.trala.priority=1000"
+      - "traefik.http.routers.trala.tls=true"
+      - "traefik.http.routers.trala.service=trala"
+      - "traefik.http.routers.trala.middlewares=default-headers@file"
+
+      - "traefik.http.services.trala.loadbalancer.server.port=8080"
 
   traefik:
     image: traefik
     networks:
+      - internal
       - proxy
     labels:
       - "traefik.enable=true"
 
       - "traefik.http.routers.Traefik.entrypoints=https"
       - "traefik.http.routers.Traefik.rule=Host(`traefik.$MY_DOMAIN`)"
       - "traefik.http.routers.Traefik.priority=1000"
       - "traefik.http.routers.Traefik.middlewares=secured-internal@file"
       - "traefik.http.routers.Traefik.tls=true"
       - "traefik.http.routers.Traefik.tls.certresolver=cloudflare"
       - "traefik.http.routers.Traefik.tls.domains[0].main=$MY_DOMAIN"
       - "traefik.http.routers.Traefik.tls.domains[0].sans=*.$MY_DOMAIN"
       - "traefik.http.routers.Traefik.service=api@internal"
       
+      # Internal API HTTP route
+      - "traefik.http.routers.internal-api.entrypoints=traefik-internal"
+      - "traefik.http.routers.internal-api.rule=PathPrefix(`/api`)"
+      - "traefik.http.routers.internal-api.service=api@internal"
+      - "traefik.http.routers.internal-api.middlewares=auth"
+      - "traefik.http.middlewares.auth.basicauth.users=CHANGE_ME"
 
 networks:
+  internal:
   proxy:
     external: true
```

Note how we use the `traefik-internal` entrypoint here. Because we automatically redirect from HTTP to HTTPS for the `http` entrypoint, we make use of the additional entrypoint without this function. We then make the API accessible with the `api@internal` service, and match all requests to `/api` for the route. We also specify a basic-auth middleware. This middleware requires a hashed username and password.

To generate the password hash for the basic auth middleware for the Traefik API, use the following command. You might have to install the `apache2-utils` package on Ubuntu:

```bash
echo $(htpasswd -nB user) | sed -e s/\\$/\\$\\$/g
```

Also set the same credentials in the `trala.yml` configuration file. Trala will use the credentials to authenticate itself at the Traefik API. You can also specify additional manual services there, which is required to display services that are not running on the same Docker host where the Traefik instance is located.

Bring up the stack and head to `https://$MY_DOMAIN`. You should be greeted with a dashboard showing your running services. 

**How does this work?**
Trala works by querying the Traefik API for routers and extracts the domain from the Host rule. It also extracts the Name of the router. For example, for the label below:

```yaml
labels:
 - "traefik.http.routers.Traefik.rule=Host(`traefik.$MY_DOMAIN`)"
```

Trala will create a new entry on the dashboard with the service name `Traefik` (note that the capitalization also follows the router name; you are allowed to insert `-` and spaces into the router name), with the URL `https://traefik.$MY_DOMAIN`. Trala will automatically detect if SSL is enabled and format the URL correctly. To obtain the service icon, Trala queries the [selfh.st Icon Database](selfh.st/icons). On startup, Trala pulls the full list of all available icons, which is then used to match router names to icons with a fuzzy search.

Trala will also display manually specified routers in Traefik's `config.yml` file.

## Traefik Log Dashboard

This project visualizes Traefik metrics and provides detailed views of requests hitting your Traefik instance. It can be useful to monitor Traefik, as well as to detect malicious requests.

Start by enabling access logs in your Traefik instance by editing the `traefik.yml` file:

```diff
 log:
   #filePath: "/var/log/traefik/access.log"
   level: INFO

+accessLog:
+  filePath: "/var/log/traefik/access.log"
+  format: json
```

Restart your Traefik instance to apply the changes. After restarting, visit some hosted services. Afterwards, you should see requests being logged in a file `data/logs/access.log`.

Next, copy the configuration files from `containers/traefik-log` over to your server. Run the setup script with:

```bash
bash setup.sh
```

The stack consists of two components: the agent and the dashboard. The agent is responsible for reading the logs and correlating the data, e.g., geographic location based on the IP address. The dashboard queries the data from the agent and displays it. A single dashboard instance can support multiple agents, running either as part of the same stack or as an external instance. Additional agents can be configured later in the dashboard settings.

To match IP addresses to geographic locations, the service requires a Geo-IP database, which can be obtained with a free account at [MaxMind](https://www.maxmind.com/en/geolite2/signup?utm_source=kb&utm_medium=kb-link&utm_campaign=kb-create-account).

After registration, navigate to My Account > Manage License Keys and create a new license key. Copy and write it down for later reference. Also, write down your Account-ID from the Account Information tab.

Next, copy the files from `containers/traefik-log` over to your server. Update the `GEOIPUPDATE_ACCOUNT_ID` and `GEOIPUPDATE_LICENSE_KEY` variables with the obtained credentials. Also, update the agent volume path to point to the location on your host where Traefik writes its logs:

```yaml
services:
  # Traefik Log Dashboard Agent
  traefik-agent:
    volumes:
      - /path/to/containers/traefik/data/logs:/logs:ro # Change path on left
```

Generate a token with `openssl rand -hex 32` and replace the values for `TRAEFIK_LOG_DASHBOARD_AUTH_TOKEN` and `AGENT_API_TOKEN` with it.

Bring up the stack and visit `https://traefik-log.$MY_DOMAIN` to view the dashboard. On the dashboard, enter the settings and select filters. Create a new custom filter condition:

- Name: `Exclude Self Requests`
- Field: `Request Host`
- Operator: `Contains`
- Value: `traefik-log.$MY_DOMAIN`
- Filter Mode: `Exclude`

This condition will filter out all requests from the dashboard itself, preventing falsification of statistics while viewing the dashboard, as it will continue to generate additional requests that are then logged on the same dashboard.

To check if everything is working, visit a few services from both the internal network and from the outside (e.g., via Cellular data). In the latter case, you should see in the Geographic analysis section that requests are seen from (most likely) Germany. Note that this only works if port forwarding is active. If you have a VPN on your phone, you can also experiment with activating it and requesting the pages. The request should originate from the country to which your VPN is connected.

Finally, we need to perform some maintenance work to prevent the `access.log` file from becoming too large. We use `logrotate`, which should already be installed.

Create a new config file: `sudo nano /etc/logrotate.d/traefik`; ensure to update the path to the Traefik log file!

```
/path/to/containers/traefik/data/logs/access.log {
    daily
    maxsize 100M
    rotate 5
    compress
    missingok
    notifempty
    postrotate
      docker exec traefik kill -USR1 1
    endscript
}
```

This will rotate the file either daily or once it reaches 100Mb in size. It will keep the last five rotated logs before deleting them. Update the path to the actual file on your host. It also notifies Traefik that the log files have been rotated, which causes it to reopen them. Restart logrotate:

```bash
sudo systemctl restart logrotate
```

To verify that it worked, run `sudo logrotate -d /etc/logrotate.conf`. You should see something like:

```
rotating pattern: /path/to/containers/traefik/data/logs/access.log  after 1 days (5 rotations)
empty log files are not rotated, log files >= 104857600 are rotated earlier, old logs are removed
switching euid from 0 to 0 and egid from 0 to 4 (pid 1186418)
considering log /path/to/containers/traefik/data/logs/access.log
  Now: 2025-11-01 13:43
  Last rotated at 2025-11-01 12:00
  log does not need rotating (log has been rotated at 2025-11-01 12:00, which is less than a day ago)
switching euid from 0 to 0 and egid from 4 to 0 (pid 1186418)
```

![get rotated](images/log-rotation.jpg)

# Portainer

Portainer is a container management platform that enables you to inspect your running Docker containers via a web UI, rather than using terminal commands. It is not advisable to expose a Portainer instance to the internet; however, for internal use, it can be very helpful.

To deploy Portainer, copy the files in `containers/portainer` and bring the stack up.

There is one interesting snippet worth taking a look at:

```bash
services:
  portainer:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

This bind mount provides Portainer with read-only access (see the `:ro` postfix) to the Docker socket, allowing it to read logs, container information, etc. Portainer **can** manage and create compose stacks and containers. This requires the removal of the `:ro` postfix to give Portainer write-access to the Docker socket.

After starting Portainer, you have to create an admin user. Afterwards, skip the wizard to add an environment and instead click on `Home`, where you should see the `local` environment. Clicking it presents an overview of running compose stacks, containers, images, volumes, and networks. The quick actions for containers can be helpful, as they allow you to quickly read the logs of a container or open a shell within the container, which is particularly useful for debugging.

**Managing Multiple Docker Servers**

To make Portainer even more helpful, you can manage multiple Docker servers from the same web UI. In Portainer, a Docker server is referred to as an "environment". To add another environment, head to `Environment related > Environments` and click `+ Add Environment`. Portainer supports multiple environments, including Docker, Docker Swarm, Podman, and Kubernetes clusters. For our use case, select `Docker Standalone` and click `Start Wizard`.

You are presented with a `docker run` command, which can be translated into a Docker Compose file for reproducibility and readability. You can find it in `containers/portainer-agent`. Copy it to both your DNS server and Backup server, and bring up the stacks.

Then, in the wizard, enter a name for the Docker server you want to connect to, and the IP address and port where the Portainer agent is reachable, e.g., `192.168.178.<server ip>:9001`. Finally, click connect. You should now be able to see both environments when you view the `Home` view. From here, you can select the remote Docker server environment, view stacks, running containers, and view their logs, exactly as you would for the local Docker server.

A note about security: The Portainer agent can only be used by one Portainer instance, as once it connects to a Portainer instance, it will be locked to it and only communicate with that instance. It also uses self-signed SSL certificates for communication.

# Docmost

Docmost is a collaborative wiki and documentation platform. To run the service, copy the files at `containers/docmost` to your server. Run the setup script to create the data directories and set the correct permissions.

Generate a set of credentials with the `openssl` commands listed in the `docker-compose.yml` file. Ensure to set the database password in the connection string. It should look like this:

```
postgresql://docmost:examplepassword@db:5432/docmost?schema=public
```

Bring up the stack and visit your wiki at `https://docmost.$MY_DOMAIN`. There, you can create a new space and an initial admin user.

# Immich

Immich is a photo and video management solution that draws inspiration from Google Photos and others. It ships with mobile apps that come with automatic camera roll upload.

To run Immich, copy the files at `containers/immich` to your server. Update the database password in the `.env` file.

Bring up the stack and head to `https://photos.$MY_DOMAIN` and follow the setup guide.

After completing the setup, you can pair your mobile device or manually upload photos. Immich ships with machine learning models that enable OCR, ML-assisted search, and facial recognition. And the best part: all machine learning models run locally on your server, and nothing is sent to the cloud!

# Nextcloud

Nextcloud is a suite of tools designed to create file hosting services. If you are using Dropbox or Google Drive, you'll feel right at home with Nextcloud. Most participants of this workshop will likely have used Nextcloud, so I'll skip a more in-depth presentation of the app.

To run Nextcloud in Docker, copy the configuration files at `containers/nextcloud` to your server. You need to change some environment variables:

- generate a database password with `openssl rand -hex 64` and set the `POSTGRES_PASSWORD` variable for both the database and nextcloud container
- optionally create the admin user with environment variables

One important setting you should check is the `TRUSTED_PROXIES` environment variable. Nextcloud must be configured to trust the IP address or subnet from which Traefik will send requests. The configured subnet must match the `proxy` network subnet. You can check the subnet of the network by running:

```bash
sudo docker network inspect proxy
```

One important thing to note is that we are not using Authelia for Nextcloud, as Nextcloud implements its own Authentication, but also to not break access with native apps. Whenever Authelia is added to a service, requests are automatically redirected to Authelia before hitting the service itself. If you want to use, e.g., a Mobile App for a self-hosted service, you cannot use Authelia for the service, as the mobile app will be redirected to Authelia, where it cannot authenticate.

```bash
labels:
  - "traefik.http.routers.Nextcloud.middlewares=default-headers@file"
```

Bring up the stack and visit your Nextcloud instance at `https://files.$MY_DOMAIN`. You can download the desktop and mobile clients for Nextcloud and try to sync some files.

# Forgejo

Forgejo is a software development and productivity platform based on git. It is a lightweight alternative to other self-hostable platforms, such as GitLab or GitHub. It is based on a fork of the Gitea project. I chose Forgejo over Gitea as it is more independent, and the developers are faster to respond with security fixes. For more details, see [here](https://forgejo.org/compare-to-gitea/).

To get started, copy over the files at `containers/forgejo` to your server.

Forgejo supports managing repositories with SSH. For this, a port must be exposed where we can reach the SSH server of Forgejo. However, an SSH server is also running on the Docker server itself. So one of the two options has to be chosen:

- Should Forgejo be available on port `22`, while SSH on the host moves to a different port?
- Or should the SSH service be available on port `22`, while Forgejo uses a different port?

I recommend changing the SSH port on the host, as it is less painful than working with a Git remote that uses a non-standard port. To change the port, edit the `sudo nano /etc/ssh/sshd_config` file and uncomment the line `Port 22`. Then, change it to a different port, such as `Port 2222`. Afterwards, reload the systemd-daemon with `sudo systemctl daemon-reload`, and restart the SSH service with `sudo systemctl restart ssh`. Close the terminal. If you now attempt to connect with SSH, you should see a `Connection refused` message. To connect to the host, specify the `-p` flag in the SSH command, followed by the new port, for example:

```bash
ssh user@1.2.3.4 -p 2222
```

If you want to change the SSH port of Forgejo, update the exposed port in the Docker Compose file, as well as in the environment variables of the Forgejo container.

With that out of the way, edit the compose file and set the database password. Also, ensure that the same password is set in the environment variables of the Forgejo container.

Bring up the stack, and head to `https://git.$MY_DOMAIN`. You will be greeted with an installer page. Here, all values should already be filled in. Self-registration is turned off by default; to enable it, uncheck the `Disable self-registration` checkbox. Expand the `Server and third-party service settings`. Here, you can decide whether to allow users to sign up via OpenID. I personally keep this disabled. Finally, expand the `Administrator account settings` and enter credentials. Hit `Install Forgejo` to proceed.

Once you are on the dashboard, you should feel right at home if you are familiar with platforms like GitHub and GitLab. Click your user profile and enter the settings to add an SSH key or to generate an access token under `Applications`.