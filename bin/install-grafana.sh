#!/usr/bin/env bash

set -euo pipefail

# Install dependencies
sudo apt-get update
sudo apt-get install -y software-properties-common wget apt-transport-https

# Add Grafana GPG key and repository
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# Install Grafana
sudo apt-get update
sudo apt-get install -y grafana

# Enable and start Grafana service
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "Grafana installation complete. Access it on http://<VM_IP>:3000"