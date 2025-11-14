# 10 - Dynamic DNS (DDNS)

Dynamic DNS, or DDNS, is a method for updating a DNS server's record contents. For self-hosting, DDNS is required if the internet provider does not provide a static public IP address, but instead a dynamic one, which can change periodically, such as with DSL. In that case, the DNS records that point to your home network must be updated so that you can still access your services from the internet after the IP address has changed.

There are multiple ways to set up DDNS. We will demonstrate two in this section.

# Docker Container

The first method is to use a small program that updates the IP address for you, like the `oznu/cloudflare-ddns` Docker container. This container is specific to Cloudflare; if you have a different public DNS provider, you will have to look for alternatives.

The container must be configured with a few variables:

- `API_KEY`: Cloudflare API key that has write permissions on the domains DNS zone
- `ZONE`: the DNS zone in which the domain resides you want to use. This should be the domain that you have registered/purchased, e.g. `mydomain.tld`
- `SUBDOMAIN`: optionally, use a subdomain. To use e.g. `test.mydomain.tld`, set this to `test`. For the wildcard container, set this to `*.test`, ensure that the `*` is still present!
- `PROXIED`: enable proxied DNS records. See notes below.

When the proxy is enabled, Cloudflare acts as a cloud-based reverse proxy; the public DNS records resolve to a public Cloudflare IP address, rather than your home network's public IP. Requests are then sent to Cloudflare rather than your home network. Cloudflare then terminates the TLS connection for you, before re-encrypting the requests and sending them to your reverse proxy. 

The benefit of this is that from the outside, Cloudflare appears as the main web server, as the DNS records will resolve to an IP address of Cloudflare. Hence, traffic will not directly hit your reverse proxy and home network. This can be helpful in defending against Bots and DDoS attacks. However, because Cloudflare terminates and re-encrypts traffic, Cloudflare can read everything; hence, Cloudflare acts like a man-in-the-middle. For more information, visit the [Cloudflare Docs](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/).

One additional benefit of proxying DNS records via Cloudflare is that we can implement stricter access rules in Traefik. Because Cloudflare creates a new request, the request that arrives at Traefik originates from a Cloudflare IP address. Cloudflare publishes a list of IP ranges [here](https://www.cloudflare.com/ips/), which we can use as an access list filter for Traefik:

```yaml
http:
  middlewares:
    external-whitelist:
      ipAllowList:
        sourceRange:
        # Local IP Ranges, update according to local subnet
        - "192.168.178.0/24"
        # Cloudflare IP Ranges
        - "173.245.48.0/20"
        - "103.21.244.0/22"
        - "103.22.200.0/22"
        - "103.31.4.0/22"
        - "141.101.64.0/18"
        - "108.162.192.0/18"
        - "190.93.240.0/20"
        - "188.114.96.0/20"
        - "197.234.240.0/22"
        - "198.41.128.0/17"
        - "162.158.0.0/15"
        - "104.16.0.0/13"
        - "104.24.0.0/14"
        - "172.64.0.0/13"
        - "131.0.72.0/22"
        - "2400:cb00::/32"
        - "2606:4700::/32"
        - "2803:f800::/32"
        - "2405:b500::/32"
        - "2405:8100::/32"
        - "2a06:98c0::/29"
        - "2c0f:f248::/32"
```

This middleware can then be added to exposed services to limit the IP ranges that are allowed to access the services to Cloudflare only. This ensures that requests are proxied through Cloudflare, eliminating the possibility that an attacker uncovers the actual public IP address where Traefik is reachable and bypasses Cloudflare.

**⚠️ Note**: If you enable the DNS proxy feature, the DNS entries will, by design, not point to your home network anymore. This is fine for web services, but we will later set up a WireGuard VPN, which requires direct access to the public IP of the home network. Hence, if you do enable the DNS proxy feature, you need an **additional** public hostname / DNS record that points to your actual IP address. Personally, I manage my DNS records as proxied records at Cloudflare, and my non-proxied records at an external DDNS provider called [No-IP](https://www.noip.com/), with a different hostname. This means that you need two update mechanisms, one for Cloudflare and one for No-IP. The latter will be shown in the next section. But it is also possible to buy a second Cloudflare domain and host non-proxied DNS records there, or to turn off the DNS proxy feature entirely and use the same domain for web services and VPN access.

# FRITZ!Box Integrated DDNS

Some FRITZ!Box models have a built-in DDNS function to send their current IP address to a remote DDNS provider. We will be using [No-IP](https://www.noip.com/), which is free to use; however, there are many other providers available. Sign up for an account, and choose your hostname. After confirming your account, you should see the hostname under `DDNS & Remote Access > DNS Records` being created.

You will need a DDNS Key to update the DNS record from the FRITZ!Box. Go to `DDNS & Remote Access > DDNS Keys` and create a new one. Write down the username and password that were generated.

Now head to `Internet > Freigaben > DynDNS` in your FRITZ!Box management UI. If you need to enter an update URL, paste the following string:

```
https://dynupdate.no-ip.com/nic/update?hostname=<domain>&myip=<ipaddr>,<ip6addr>
```

For the domain, enter the hostname you have created. Also, enter the credentials you previously obtained.

For more information, see:

- [No-IP docs](https://www.noip.com/support/knowledgebase/configuring-ddns-FRITZ!Box)
- [AVM docs](https://fritz.com/en/apps/knowledge-base/FRITZ-Box-7590/30_Setting-up-dynamic-DNS-in-the-FRITZ-Box)