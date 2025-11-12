mkdir -p config
mkdir -p config/{pihole,dnsmasq,unbound}

curl -o config/unbound/root.hints https://www.internic.net/domain/named.root