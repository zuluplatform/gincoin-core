#!/bin/bash
sudo apt-get update
sudo apt-get install -y build-essential autoconf libtool libboost-all-dev libevent-dev libssl-doc zlib1g-dev pkg-config libssl-dev
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get update
sudo apt-get install -y libdb4.8-dev libdb4.8++-dev libzmq3-dev

#setup firewall
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow ssh/tcp
sudo ufw limit ssh/tcp
sudo ufw allow 10111/tcp
sudo ufw logging on
sudo ufw enable -y

#ban
sudo apt -y install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

#compile
chmod +x autogen.sh
autogen.sh
export PKG_CONFIG=/usr/bin/pkg-config
configure && make -j$(nproc --all)