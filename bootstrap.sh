#!/usr/bin/env bash

apt-get update
apt-get install -y ruby1.9.3 unzip curl

mkdir -p /data/serverside && chown vagrant:vagrant /data/serverside
mkdir -p /engineyard/bin

echo "echo hello" > /engineyard/bin/app_serverside
chmod +x /engineyard/bin/app_serverside
