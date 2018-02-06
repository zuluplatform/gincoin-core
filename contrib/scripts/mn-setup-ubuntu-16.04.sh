#!/bin/bash
chmod +x autogen.sh
sudo apt-get update
sudo apt-get install -y build-essential autoconf libtool libboost-all-dev libevent-dev libssl-doc zlib1g-dev
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
sudo ufw enable

#ban
sudo apt -y install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban