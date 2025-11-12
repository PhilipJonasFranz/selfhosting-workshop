# 5 - Pi-hole

The Domain Name System (DNS) is an integral part of the Internet and almost any network. While public DNS servers are responsible for resolving names to IP addresses for Internet users, private DNS servers can also be set up to resolve internal names and domains.

What a DNS server effectively does is to resolve and answer DNS queries, which, given a resolvable DNS name, return one or more resource records. The client can then use the address returned by the DNS server to make a request over the network to the entity the name was resolved to. There are various types of records; the most important ones for us are the following:

- A record: maps a name to an IPv4 address
- AAAA: maps a name to an IPv6 address
- CNAME: points one name to another name
- TXT: can store arbitrary additional data, useful for verification purposes and metadata

# Why should I run my own DNS server?

With public DNS servers existing, why should you host your own DNS server? As previously mentioned, private DNS servers can be used to manage records for internal names and private domains. They can also be used to implement something called DNS split-horizon, which means that DNS queries get resolved to different records based on where the query is coming from. For example, if you are connected to the Internet somewhere, such as in a Café, a public DNS server will resolve your domain to the public IP address of your home network. However, if you are at home, your private DNS server will resolve the same domain name to the private IP address, allowing you to communicate with your server directly and locally.

If your server is accessible from the outside anyway, this is not a significant issue, especially if your FRITZ!Box/Router supports hairpin-NAT, which enables the router to detect that a packet is addressed to its own public IP and route it correctly within the local network. However, if your server is not publicly accessible and/or no public DNS records exist, you will need a private DNS to inform your clients where to find your server.

With the why out of the way, let us discuss the how. There are many DNS servers available that you can self-host, such as BIND9 and PowerDNS. We will be using Pi-hole, as it integrates the capability to add local DNS records with ad-blocking lists. However, Pi-hole requires an upstream DNS server, as it effectively just blocks DNS queries by filtering them. One can either use public DNS servers to resolve all records that cannot be resolved by Pi-hole locally or use a private resolver.

# Recursive and Iterative Resolvers

We will be using Unbound as our private resolver. Using Unbound increases your privacy, as it is a **recursive** resolver. But what does that mean?

Assume we want to query the domain `abc.def.de`. There are two ways to resolve the query:

- recursive resolution: We ask Unbound to resolve `abc.def.de`. Unbound takes full responsibility for finding the answer. It starts at the root DNS servers, asking “Who handles `.de`?” Then it queries one of the `.de` top-level domain servers for “Who handles `def.de`?”, and finally it asks the authoritative `def.de` server for the record for `abc.def.de`. Once Unbound has the answer, it returns it to the client.

- iterative resolution: In this mode, each DNS server only gives a referral instead of resolving the query. For example, if we ask the root server for `abc.def.de`, it responds, “I don’t know, but here are the `.de` servers.” We then ask the `.de` server to resolve `abc.def.de`, which points us to the `def.de` server, which finally gives us the record for `abc.def.de`. The client itself performs all these steps.

Note that in both recursive and iterative resolution, each DNS query is made using the full domain name (e.g., `abc.def.de`). However, each DNS server in the chain is only authoritative for its own zone. The root only knows `.de`, the `.de` server only knows about `def.de`, and only the authoritative server for `def.de` knows the record for `abc.def.de`.

**How does Unbound improve my privacy?**

The privacy advantage of using a local recursive resolver like Unbound is that you no longer rely on a single third-party DNS provider that sees all your lookups. For example, if you use the Google DNS server, Google, as a central entity, could collect all of your queries and pool them together to track you. When using a private resolver, your resolver communicates directly with the decentralized DNS hierarchy, and no single public server has a complete view of your DNS activity. Using a private resolver does not hide your queries; it simply distributes the information to different entities.

# Pi-hole Setup

The following instructions are based on [this](https://ronamosa.io/docs/engineer/LAB/Pi-hole-docker-unbound/) blog article.

To start, copy over all of the files for Pi-hole to the server. Run the setup script with `bash setup.sh`. This script also downloads a file `root.hints`, which lists the IP addresses of the root servers that Unbound should use.

Since our Pi-hole has to resolve DNS queries for our domain, we create a custom `dnsmasq` configuration. For the following chapter, we will be using `vlab.local` as the domain. Later, we will update this to a public domain name. In the file `03-wildcard-record.conf`, edit the Placeholder IP address to the IP address of your Docker server where Traefik is running. The contents of the file should look like this:

```
address=/.vlab.local/192.168.178.123
```

This entry creates a wildcard DNS record for `*.vlab.local`, which resolves to the associated IP address. When Pi-hole has to resolve a DNS query, it first queries its local DNS records, which can be created in the web UI. If no match is found, the custom configurations of `dnsmasq` are checked. If still no match can be found, Unbound will be queried.

The wildcard record we created above will result in all queries for our domain being resolved to the IP address of the Docker server running Traefik. If we need to override the wildcard, we can still create a local DNS entry in the Pi-hole web UI.

Now we are ready to start the compose stack:

```bash
sudo docker compose up -d
```

Open the web UI at `http://<server ip>/admin` and log in.

Next, we need to disable the DNS server that is running as part of Ubuntu, `systemd-resolved`. If you run the `dig` command in your terminal, systemd-resolved will respond with a list of the root servers, **not** Pi-hole. Because this service binds to port `53`, which is the default port for DNS, we have to stop the service so that Pi-hole can use the port, instead of the currently used port `5353`. This temporarily breaks DNS resolution on the host.

```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

After the service has been stopped, try the `dig` command again. You should now see a message that no servers could be reached. To let Pi-hole use port `53`, edit the compose file and change the published ports:

```diff
 ports:
- - "5353:53/tcp"
- - "5353:53/udp"
+ - "53:53/tcp"
+ - "53:53/udp"
```

Restart the stack with `sudo docker compose up -d --force-recreate`. After the stack has restarted, run `dig` again. The response should again be the root servers. We can also test that it is now indeed Pi-hole and, by extension, Unbound that answers our queries:

```bash
dig hey.it.works
sudo docker logs unbound 2>&1 | grep "hey.it.works"
```

Should result in:

```
[1762205727] unbound[1:0] info: resolving hey.it.works. A IN
[1762205727] unbound[1:0] info: response for hey.it.works. A IN
[1762205728] unbound[1:0] info: response for hey.it.works. A IN
[1762205728] unbound[1:0] info: response for hey.it.works. A IN
```

Also, ensure that DNS resolution for `*.vlab.local` is working:

```bash
dig vlab.local
dig wildcard-record.vlab.local
```

Both queries should return the IP address of the Docker server.

Now that the base of the stack is working, we need to make some modifications on the host itself to prevent interference from systemd-resolved and/or DHCP. First, replace the `/etc/resolv.conf` file, which tells Linux where to send DNS queries. `systemd-resolved` creates a symlink to manage the actual configuration file somewhere else dynamically. Hence, we have to break the symlink and replace the file with our custom configuration:

```bash
# Remove symlink from systemd-resolved
sudo rm /etc/resolv.conf

# Write new resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# Make it immutable to prevent DHCP from changing it
sudo chattr +i /etc/resolv.conf
```

Edit `/etc/dhcp/dhclient.conf` and add the following line. This prevents DHCP from overwriting the DNS settings, causing a DNS leak:

```bash
supersede domain-name-servers 127.0.0.1;
```

Edit `/etc/docker/daemon.json` and add the following content. This is very important, as otherwise Pi-hole itself cannot resolve DNS queries within its container.

```bash
{
  "dns": ["127.0.0.1"]
}
```

Afterwards, restart Docker:

```bash
sudo systemctl restart docker
```

# Setting DNS Server in FritzOS

Now that our own DNS server is up and running, we can utilize it in our entire network. To configure devices in our network to use Pi-hole as the DNS server, we need to set it as the DHCP DNS Server in the FRITZ!Box.

To do this, head to `Heimnetz > Netzwerk > Netzwerkeinstellungen > Weitere Einstellungen > IP Addressen > IPv4 Einstellungen`, and set the `Lokaler DNS Server` to the IP of your Pi-hole. Apply the changes and reconnect all devices in your network such that they request an IP via DHCP again. You can verify that Pi-hole is being used by inspecting the query log in the Pi-hole web UI. For example, if you visit `youtube.de`, you should see many DNS queries for YouTube and Google-related domains.

Of course, setting the DNS server via DHCP only takes care of devices that use DHCP to get an IP address. For devices with static configurations, such as servers, you may need to manually set the DNS server.

Finally, you also need to set the DNS for the FRITZ!Box itself. To do this, navigate to `Internet > Zugangsdaten > DNS Server > DNSv4-Server > Andere DNSv4-Server verwenden`, and enter the IP address of the Pi-hole server twice. The FRITZ!Box requires a backup DNS server, which we don't have. Finally, hit apply.

# Loading Ad-Lists for Ad-Blocking

We previously mentioned the Ad-Blocking capabilities of Pi-hole. Pi-hole can load Lists that contain domains. A selection of Ad-Blocking lists can be found below. These lists contain domains known to serve ads, trackers, malware, or telemetry. When a device on the network loads a website that contains embedded ads and trackers, the browser must determine where to load the content from. It sends a DNS request to Pi-hole, which filters the request through its loaded blocklists. If a match is found, Pi-hole returns `NXDOMAIN`, which stands for non-existent domain. With this, the device does not know from where to load the ads, hence, no ads can be displayed.

Selection of Blocklists:

- [https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt](https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt)
- [https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts](https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts)
- [https://v.firebog.net/hosts/static/w3kbl.txt](https://v.firebog.net/hosts/static/w3kbl.txt)
- [https://adaway.org/hosts.txt](https://adaway.org/hosts.txt)
- [https://v.firebog.net/hosts/AdguardDNS.txt](https://v.firebog.net/hosts/AdguardDNS.txt)
- [https://v.firebog.net/hosts/Admiral.txt](https://v.firebog.net/hosts/Admiral.txt)
- [https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt](https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt)
- [https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt](https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt)
- [https://v.firebog.net/hosts/Easylist.txt](https://v.firebog.net/hosts/Easylist.txt)
- [https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&amp;amp;showintro=0&amp;amp;mimetype=plaintext](https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&amp;amp;showintro=0&amp;amp;mimetype=plaintext)
- [https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts](https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts)
- [https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts](https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts)
- [https://v.firebog.net/hosts/Easyprivacy.txt](https://v.firebog.net/hosts/Easyprivacy.txt)
- [https://v.firebog.net/hosts/Prigent-Ads.txt](https://v.firebog.net/hosts/Prigent-Ads.txt)
- [https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts](https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts)
- [https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt](https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt)
- [https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt](https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt)
- [https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt](https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt)
- [https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt](https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt)
- [https://v.firebog.net/hosts/Prigent-Crypto.txt](https://v.firebog.net/hosts/Prigent-Crypto.txt)
- [https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts](https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts)
- [https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt](https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt)
- [https://phishing.army/download/phishing_army_blocklist_extended.txt](https://phishing.army/download/phishing_army_blocklist_extended.txt)
- [https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt](https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt)
- [https://v.firebog.net/hosts/RPiList-Malware.txt](https://v.firebog.net/hosts/RPiList-Malware.txt)
- [https://v.firebog.net/hosts/RPiList-Phishing.txt](https://v.firebog.net/hosts/RPiList-Phishing.txt)
- [https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt](https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt)
- [https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts](https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts)
- [https://urlhaus.abuse.ch/downloads/hostfile/](https://urlhaus.abuse.ch/downloads/hostfile/)

To load the lists, head to the `Lists` tab in the Pi-hole Web UI. For your convenience, all URLs are listed comma-separated in the `containers/Pi-hole/adlists.txt` file. Copy its contents into the text field and click `Add blocklist`. You should see the lists being added below. Next, Pi-hole has to update its domain list. To do this, head to `Tools > Update Gravity` and click update. After some time, you should get a success confirmation. If you now head to the dashboard, you should see approximately 1.4 million domains on the ad list being loaded and actively blocked.