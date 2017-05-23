#!/bin/bash

address=`ip route get 1 | awk '{print $NF;exit}'`

# install Docker
wget -qO - https://get.docker.com | sh -
set -x
systemctl stop docker
sed -i "s,-H fd://,-H fd:// -H tcp://0.0.0.0:2375 --cluster-advertise=$address:2375 --cluster-store=consul://${consul_address}:8500," \
	/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl start docker

# setup swarm worker
docker run -d --name swarm-agent swarm join --advertise=$address:2375 \
	consul://${consul_address}:8500
