# 9 - Port Forwarding

There are two ways to make services accessible while you are not at home:

- you can either expose them to the Internet, making them accessible to everyone
- you can use a VPN to connect to your home network, thus making services accessible

Unless otherwise required, I recommend using a VPN. However, there are situations in which you would want an exposed service. For example to make services accessible to friends and family or to host a public website.

To expose a service, only one small change is required, which is to create port forwardings in the router/firewall or in our case FRITZ!Box. A port forward is an exception to the routers firewall that allows connections from the internet pass through if they target the specified port. The traffic is then forwarded to the same port on a host in the internal network.

**⚠️ Warning**: Port forwarding opens up the host to the Internet. The Internet is a dangerous place, and a vulnerability in e.g. Traefik could be exploited to gain access to services. Port forwarding should always be done with caution, and proper security mechanisms in place, like a Demilitarized Zone (DMZ), and host hardening. Keep forwarded ports to a minimum, there should be little reason to forward anything else than ports `80, 443`, and a VPN access port.

For our setup, we require ports `80, 443` to be forwarded to the IP address of the Docker server.

# Setup in FritzOS

To create a port forwarding on in the FRITZ!Box web-ui, head to `Internet > Freigaben > Portfreigaben`. In the option `Gerät`, selct `IP-Addresse manuell eingeben`, and enter the IP address of your server that hosts Traefik or Wireguard. We will only work with IPv4, but you can also enter the IPv6 address here.

After entering the IP, click `Neue Freigabe` near the bottom of the page. Here you can select `HTTP-Server` as application, and hit ok. Repeat the same for an `HTTPS-Server` entry.

Finally hit `Übernehmen` or apply.