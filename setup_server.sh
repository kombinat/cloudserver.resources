#!/bin/bash
HOME="/home"

# necessary libaries
apt-get install -y nano pkg-config bash-completion nginx awstats build-essential ntpdate net-tools rename lynx libwww-perl munin-node

# python dependencies
apt-get install -y libjpeg8-dev libssl-dev libpcre++-dev libpng-dev libxslt1-dev libxml2-dev zlib1g-dev libmemcached-dev libreadline-dev libncurses5-dev libyaml-dev libsqlite3-dev poppler-utils libffi-dev liblzma-dev libbz2-dev

# varnish
apt-get install -y python3-docutils

# certbot
read -p "Install Certbot? [y/N]" -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    snap install --classic certbot
fi

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

read -p "Set timezone? [y/N]" -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # set timezone (selection list for berlin coordinates)
    dpkg-reconfigure tzdata
    # get actual time from ntp.org
    ntpdate de.pool.ntp.org
fi

read -p "Set hostname? [y/N]" -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter hostname: " -r
    HOSTNAME=$REPLY

    hostname $HOSTNAME
    echo "$HOSTNAME" > /etc/hostname
    echo "127.0.0.1 $HOSTNAME" >> /etc/hosts
    echo "Set hostname to $HOSTNAME: done"
fi

read -p "Install logrotate? [y/N]" -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # install logrotate
    echo
    echo "Installing logrotage to /etc/logrotate/$HOSTNAME"
    [ ! -f "/etc/logrotate.d/$HOSTNAME" ] && cp logrotate.conf /etc/logrotate.d/$HOSTNAME
fi

read -p "Install php-fpm? [y/N]" -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # install cgi-bin.php for fastcgi (awstats support)
    echo
    echo "Installing cgi-bin.php to /etc/nginx for php support"
    apt-get install -y php-fpm
    cp cgi-bin.php /etc/nginx/
fi

echo "Done setting up your server."
