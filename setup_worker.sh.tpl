#!/bin/bash

address=`ip route get 1 | awk '{print $NF;exit}'`

# install Docker
mkdir -p /etc/systemd/system/docker.service.d
cat - > /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --cluster-advertise=$address:2375 --cluster-store=consul://${consul_address}:8500
EOF
wget -qO - https://get.docker.com | sh -

# setup swarm worker
docker run -d --name swarm-agent swarm join --advertise=$address:2375 \
	consul://${consul_address}:8500
