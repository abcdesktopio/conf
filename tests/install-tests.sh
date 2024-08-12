#!/bin/bash

echo "apt-get update"
sudo apt-get update
echo "apt-get install -y apt-transport-https ca-certificates curl software-properties-common gpg openssl sed"
sudo apt-get install -y --no-install-recommends curl gnupg ca-certificates openssl apt-transport-https software-properties-common sed

echo "install yarn npm nodejs "
mkdir -p /etc/apt/keyrings 
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list 
sudo apt-get update
sudo apt-get install -y --no-install-recommends nodejs
sudo npm -g install yarn  

echo "install tests packages for conf"
cd tests
sudo yarn install --productuon=false 
sudo npm i --package-lock-only 
sudo npm audit fix

echo "install chrome"
sh -c 'echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list' 
wget -O- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo tee /etc/apt/trusted.gpg.d/linux_signing_key.pub 
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 78BD65473CB3BD13 
sudo apt-get update 
sudo apt-key export D38B4796 | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/chrome.gpg 
sudo apt-get install -y --no-install-recommends google-chrome-stable 