#!/bin/bash

address=`ip route get 1 | awk '{print $NF;exit}'`

# install Docker
wget -qO - https://get.docker.com | sh -
systemctl stop docker
sed -i "s,-H fd://,-H fd:// -H tcp://0.0.0.0:2375," /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl start docker

set -x

# setup consul
docker run -d -p 8500:8500 --name=consul progrium/consul -server -bootstrap
