#!/bin/bash

# THIS IS FOR UBUNTU + NGINX ONLY!

apt-get update
apt-get install software-properties-common
add-apt-repository ppa:certbot/certbot
apt-get update
apt-get install python-certbot-nginx

certbot --nginx certonly

echo "30 0 * * * certbot renew" | crontab -

echo "Certificate installed."
echo
echo "You have to edit your nginx live-config manually or "
echo "update your buildout nginx template accordingly!"
