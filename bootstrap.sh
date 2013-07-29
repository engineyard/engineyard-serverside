#!/usr/bin/env bash

apt-get update
apt-get install -y ruby1.9.3 unzip curl

mkdir -p /data/serverside && chown vagrant:vagrant /data/serverside
