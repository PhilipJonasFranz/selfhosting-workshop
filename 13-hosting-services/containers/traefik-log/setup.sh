mkdir -p data
mkdir -p data/{logs,geoip,positions,dashboard}
sudo chmod 755 data/*
sudo chown -R 1001:1001 ./data/dashboard