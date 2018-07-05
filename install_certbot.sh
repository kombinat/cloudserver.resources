#!/bin/bash

# THIS IS FOR UBUNTU ONLY!

apt-get update
apt-get install software-properties-common
add-apt-repository ppa:certbot/certbot
apt-get update
apt-get install python-certbot-nginx

certbot --nginx certonly

echo "00 30 * * * certbot renew" | crontab -
