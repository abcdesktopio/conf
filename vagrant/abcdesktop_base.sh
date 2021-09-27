#!/bin/bash
# update package 
apt-get update
sudo apt-get install -y curl
#
# install docker 
echo 'install docker'
curl -fsSL https://get.docker.com -o get-docker.sh
sudo bash ./get-docker.sh
# 
# install docker compose
echo 'install docker compose'
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
# 
# install npm
echo 'install npm'
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get update
# To be able to compile native addons from npm you’ll need to install the development tools
sudo apt-get install -y git build-essential nodejs
#
# install newman 
echo 'install newman'
sudo npm install -g newman@^5.1.2
sudo npm install -g newman-reporter-htmlextra
#
#
# clone git conf to run install and newman collections
echo 'cloning abcdesktopio/conf'
git clone https://github.com/abcdesktopio/conf.git
