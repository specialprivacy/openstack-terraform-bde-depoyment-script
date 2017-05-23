#!/bin/bash

address=`ip route get 1 | awk '{print $NF;exit}'`

# install Docker
wget -qO - https://get.docker.com | sh -
apt-get install -y --no-install-recommends docker-compose git
systemctl stop docker
sed -i "s,-H fd://,-H fd:// -H tcp://0.0.0.0:2375 --cluster-advertise=$address:2375 --cluster-store=consul://${consul_address}:8500," \
	/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl start docker


# setup swarm manager
set -x
docker run -d -p 4000:4000 --name=swarm-master swarm manage -H :4000 \
	--replication --advertise $address:4000 consul://${consul_address}:8500
docker run -d --name swarm-agent swarm join --advertise=$address:2375 \
	consul://${consul_address}:8500

# install swarm UI
set +x
git clone https://github.com/big-data-europe/app-swarm-ui.git
cd app-swarm-ui
cat - > docker-compose.custom.yml <<EOF
version: "2"
services:

  swarm-admin:
    environment:
      - DOCKER_HOST=tcp://$address:4000
EOF
echo "COMPOSE_FILE=docker-compose.yml:docker-compose.custom.yml" >> .env
docker-compose up -d
