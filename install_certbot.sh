#!/bin/bash

# THIS IS FOR UBUNTU + NGINX ONLY!

apt-get update
apt-get install software-properties-common
add-apt-repository ppa:certbot/certbot
apt-get update
apt-get install python-certbot-nginx

certbot certonly --manual --preferred-challenges=dns

echo "Certificate installed."
echo
echo "You have to edit your nginx live-config manually or "
echo "update your buildout nginx template accordingly!"
