#!/bin/bash

address=`ip route get 1 | awk '{print $NF;exit}'`

apt-get update
apt-get install -y --no-install-recommends unzip

cd /tmp
wget https://releases.hashicorp.com/consul/0.8.3/consul_0.8.3_linux_amd64.zip
unzip -d /usr/local/sbin consul_0.8.3_linux_amd64.zip
rm consul_0.8.3_linux_amd64.zip
echo "CONSUL_OPTS=-server -bootstrap -client=0.0.0.0" >> /etc/environment
wget -O /lib/systemd/system/consul.service https://gist.githubusercontent.com/cecton/52b08c398dbcc7e993052663adc78528/raw/15e3d42d9451e98486fb5040dc028104f5f9a003/consul.service
systemctl daemon-reload
systemctl enable consul
systemctl start consul
