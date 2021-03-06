#!/bin/bash

# THIS IS FOR UBUNTU + NGINX ONLY!

apt-get update
apt-get install -y software-properties-common
add-apt-repository ppa:certbot/certbot
apt-get update
apt-get install -y python-certbot-nginx

certbot certonly --nginx

echo "Certificate installed."
echo
echo "You have to edit your nginx live-config manually or "
echo "update your buildout nginx template accordingly!"
