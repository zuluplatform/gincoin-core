#!/bin/bash
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get update
sudo apt-get install -y htop libboost-all-dev libzmq3-dev libdb4.8-dev libdb4.8++-dev libevent-dev libssl-doc zlib1g-dev

#setup firewall
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow ssh/tcp
sudo ufw limit ssh/tcp
sudo ufw allow 10111/tcp
sudo ufw logging on
sudo ufw --force enable

#ban
sudo apt -y install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
