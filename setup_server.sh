#!/bin/bash
HOME="/home"

# necessary libaries
apt-get install -y nano pkg-config bash-completion nginx awstats build-essential ntpdate net-tools rename lynx

# python dependencies
apt-get install -y libjpeg8-dev libssl-dev libpcre++-dev libpng-dev libxslt1-dev libxml2-dev zlib1g-dev libmemcached-dev libreadline-dev libncurses5-dev libyaml-dev libsqlite3-dev poppler-utils libffi-dev
apt-get install -y php-fpm

# varnish
apt-get install -y python3-docutils

read -p "Install MySQL? [y/N]" -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt-get install -y mysql-server
    apt-get install -y libmysqlclient-dev
fi

read -p "Install Postfix? [y/N]" -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt-get -y install mailutils
    echo
    echo "You may want to configure postfix as readonly SMTP relay with"
    echo " > inet_interfaces = localhost"
    echo "in /etc/postfix/main.cf"
fi

# set timezone (selection list for berlin coordinates)
dpkg-reconfigure tzdata
# get actual time from ntp.org
ntpdate de.pool.ntp.org

read -p "Enter hostname: " -r
HOSTNAME=$REPLY

hostname $HOSTNAME
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 $HOSTNAME" >> /etc/hosts
echo "Set hostname to $HOSTNAME: done"

# install logrotate
echo
echo "Installing logrotage to /etc/logrotate/$HOSTNAME"
[ ! -f "/etc/logrotate.d/$HOSTNAME" ] && cp logrotate.conf /etc/logrotate.d/$HOSTNAME

# install cgi-bin.php for fastcgi (awstats support)
echo
echo "Installing cgi-bin.php to /etc/nginx for php support"
cp cgi-bin.php /etc/nginx/
