# 11 - Wireguard VPN

As an alternative to port forwarding, a VPN is a secure way to access your home network while you are on the go. Good options are WireGuard and OpenVPN. In this section, we will focus on WireGuard, as it is simpler to manage and more performant than OpenVPN.

# FritzOS Setup

To configure WireGuard in FritzOS, head to `Internet > Freigaben > VPN (WireGuard)`.

Click `Verbindung hinzufügen`, and select `Einzelgerät verbinden`. Enter a name for the connection, e.g., the device name. You are then presented with a QR code, which you need to scan with your mobile phone in the WireGuard app to add the tunnel.

As an alternative, we will explore a dockerized WireGuard server with a minimalistic web UI below.

# Docker Setup

If you do not have a FRITZ!Box, you can also set up a VPN server on a host in your internal network. We will use [wg-easy](https://github.com/wg-easy/wg-easy) for a containerized version, which also includes a simple web UI to manage clients.

This requires a port forward on the router for the corresponding WireGuard port. Follow the steps from the port-forwarding section to create a new port forward. By default, WireGuard will use port `51820` and `UDP`.

To set up the WireGuard server, copy the files at `containers/wg-easy` to your host. Ensure Traefik is also running on the host, as we will add SSL to the web UI.

The `docker-compose.yml` file for wg-easy has some elements we have not seen before. Let's work through them. First, we define a custom WireGuard bridge network and give it a specific subnet:

```yaml
networks:
  proxy:
    external: true
  wg:
    driver: bridge
    enable_ipv6: false
    ipam:
      driver: default
      config:
        - subnet: 172.16.5.0/24
```

Next, the `proxy` and `wg` networks are attached to the container. For the `wg` network, we specify a static IP address. By default, containers will pick an available IP in a network. We also expose port `51820/udp` to the host, so the port-forwarded traffic from the FRITZ!Box is allowed to pass into the host and container.

```yaml
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:15
    container_name: wg-easy
    ports:
      - "51820:51820/udp"
    networks:
      wg:
        ipv4_address: 172.16.5.2
      proxy:
```

Next, we give the container read-only access to the WireGuard kernel module on the host:

```yaml
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:15
    container_name: wg-easy
    volumes:
      - /lib/modules:/lib/modules:ro
```

Next, we configure some environment variables. The most interesting settings here are `WG_ALLOWED_IPS` and `WG_PRE_UP`. The `WG_ALLOWED_IPS` setting specifies the subnet for which traffic should be routed through the VPN. Setting this to `0.0.0.0/0` results in everything being routed through the VPN tunnel. This effectively lets your device appear as if it were at home. This can be helpful if you are travelling and are connected to an insecure hotel WiFi, and want a secure connection to a trusted network. This is called a "full-tunnel".

You can also set the setting only to the subnet of your home network, e.g., `192.168.178.0/24`. This is called a "split-tunnel", and will only route requests for your home network through the VPN tunnel. This allows your device to appear to be wherever you are, while still enabling you to communicate with your services at home.

The `WG_PRE_UP` variable specifies commands that are run before the `wg0` interface in the container is brought up. It modifies IP routes and `iptable` settings to ensure the container can route traffic to and from your home network. Ensure to adjust the subnet if your home network uses a different IP range!

```yaml
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:15
    container_name: wg-easy
    environment:
      - WG_ALLOWED_IPS=0.0.0.0/0 # full tunnel, change to home network subnet for split tunnel
      # ⚠️ adjust the subnet to the subnet of your home network below, e.g. 192.168.178.0/24 -> 10.0.0.0/8
      - |
        WG_PRE_UP=
          # Tells the container how to reach your home network subnet (192.168.178.0/24).
          # Traffic is sent to the 'wg' Docker network gateway (172.16.5.1) via eth1.
          ip route add 192.168.178.0/24 via 172.16.5.1 dev eth1;
          
          # Masquerades (NATs) all traffic from the VPN client subnet (10.42.0.0/24).
          # This makes outgoing packets appear to come from the container's IP.
          iptables -t nat -A POSTROUTING -s 10.42.0.0/24 -j MASQUERADE;
          
          # Allows all new and existing traffic from the VPN subnet to be forwarded.
          iptables -I FORWARD -s 10.42.0.0/24 -j ACCEPT;
          
          # Allows established and related traffic to the VPN subnet.
          iptables -I FORWARD -d 10.42.0.0/24 -m state --state ESTABLISHED,RELATED -j ACCEPT;
```

There are three subnets to look out for, which are listed below, alongside the currently configured IP range:

- `192.168.178.0/24`, your home network
- `172.16.5.0/24`, the Docker bridge between your home network and the wg-easy container
- `10.42.0.0/24`, the internal Wireguard VPN subnet

Next, we grant the container some capabilities and allow it to modify runtime kernel parameters:

- `NET_ADMIN`: allows the container to manage its own networking interfaces, like adding routes, which we do in the `WG_PRE_UP` variable above
- `SYS_MODULE`: allows the container to load/unload kernel modules, which is required to load the mounted WireGuard kernel module from `/lib/modules:/lib/modules:ro`
- `net.ipv4.ip_forward=1`: enables IPv4 forwarding, which is required to forward traffic through the VPN
- `net.ipv4.conf.all.src_valid_mark=1`: makes the kernel accept packets with non-local source addresses marked by iptables
- `net.ipv6.conf.all.disable_ipv6=1`: disables IPv6 globally in the container

```yaml
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:15
    container_name: wg-easy
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=1
```

Finally, we add the labels for Traefik to access the web UI with SSL.

**Warning**: If you deploy wg-easy on the same host where your other services are running, you need to modify the Docker networks. If not, you can skip the next step. The traffic gets blocked due to the trafficjam deployment. It blocks all traffic that is routed from a client to the VPN and targets the Docker host. Because of this, you won't be able to access the services on the Docker host. To fix it, change the network `proxy` to e.g. `wg-access` in the wg-easy Compose file, both in the `networks` section of the container, and at the end of the file. Also, ensure that you update the network in the Traefik labels on the container: `- "traefik.docker."network=wg-access"`. Create the network with `sudo docker network create wg-access`. Finally, modify the Traefik Compose file and add the network to the containers network section, as well as the files network section, and restart Traefik:

```yaml
services:
  traefik:
    # other configuration
    networks:
      - wg-access
      - proxy

# other configuration 

networks:
  proxy:
    external: true
  wg-access:
    external: true
```

Bring up the stack and visit the dashboard at `https://vpn.$MY_DOMAIN`. It might take some time before you can visit the page, as Traefik only adds the route once a container is running and healthy. If you run `sudo docker ps`, you can inspect the status of your containers (simplified for readability):

```
CONTAINER ID   IMAGE                        STATUS                           NAMES
87454b1a9dea   ghcr.io/wg-easy/wg-easy:15   Up 1 second (health: starting)   wg-easy
439bc11d626e   kaysond/trafficjam           Up About an hour (healthy)       trafficjam
cc7f6d13395f   traefik                      Up About an hour                 traefik
```

While `wg-easy` is still in the status `starting`, Traefik will not add the routes. Be patient, it takes a few seconds.

After you have accessed the dashboard, you should be greeted with a login screen. The credentials are set in the compose files in the `INIT_USERNAME` and `INIT_PASSWORD` variables. You can also turn off the automatic initialization to set up these settings manually. After logging in, add a new client and assign it a name and an expiration date. You can then click the QR code symbol and scan it using the WireGuard app on your phone, or download the configuration file.

Assuming you use a mobile app, disconnect from the WiFi and use cellular data to test that everything works. When activating the tunnel, both in the web UI and on your phone, you should see the date being sent and received. If not, something has gone wrong.

From here, test if you can ping IP addresses in your home network, or try to access services that are only reachable from within your home network.