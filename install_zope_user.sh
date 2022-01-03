#!/bin/bash
HOME="/home"

# necessary libaries
apt-get install -y nano pkg-config bash-completion nginx awstats build-essential ntpdate net-tools rename lynx

# python dependencies
apt-get install -y libjpeg8-dev libssl-dev libpcre++-dev libpng-dev libxslt1-dev libxml2-dev zlib1g-dev libmemcached-dev libreadline-dev libncurses5-dev libyaml-dev libsqlite3-dev python-docutils poppler-utils libffi-dev
[ -z "`apt-cache search php-fpm`" ] && apt-get install -y php5-fpm || apt-get install -y php-fpm

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

# fix library symlinks for python 2.6
[ ! -f "/usr/lib/libssl.so" ] && ln -s /usr/lib/x86_64-linux-gnu/libssl.so /usr/lib/libssl.so
[ ! -f "/usr/lib/libjpeg.so" ] && ln -s /usr/lib/x86_64-linux-gnu/libjpeg.so /usr/lib/libjpeg.so
[ ! -f "/usr/lib/libz.so" ] && ln -s /usr/lib/x86_64-linux-gnu/libz.so /usr/lib/libz.so

# set timezone (selection list for berlin coordinates)
dpkg-reconfigure tzdata
# get actual time from ntp.org
ntpdate de.pool.ntp.org

read -p "Enter username: " -r
USER=$REPLY

[ -z "$USER" ] && echo "please provide a username!" && exit

if [ ! -d "$HOME/$USER" ]; then
    echo "Creating user $USER"
    useradd -m -s /bin/bash $USER
    # prepare statistik output for awstats
    mkdir $HOME/$USER/stats
    chgrp www-data $HOME/$USER/stats
fi

read -p "Set Hostname of Server to '$USER'? [y/N]" -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    hostname $USER
    echo "$USER" > /etc/hostname
    echo "127.0.0.1 $USER" >> /etc/hosts
    echo "Done"
else
    echo "Skipped"
fi

# install logrotate
[ ! -f "/etc/logrotate.d/$USER" ] && cp logrotate.conf /etc/logrotate.d/$USER

# install cgi-bin.php for fastcgi (awstats support)
cp cgi-bin.php /etc/nginx/

if [ ! -f "$HOME/$USER/.ssh/id_rsa.pub" ]; then
    su - $USER -c "ssh-keygen -t rsa -b 4096"
    echo "Add this SSH key to gitlab deploy keys"
    echo "-------------------------"
    cat $HOME/$USER/.ssh/id_rsa.pub
    echo "-------------------------"
    # add gitlab.kombinat.at to known_hosts
    su - $USER -c "ssh-keyscan gitlab.kombinat.at > .ssh/known_hosts"
    # global gitignore
    su - $USER -c "git config --global core.excludesfile '~/.gitignore'"
    cp .gitignore $HOME/$USER/
    chown $USER $HOME/$USER/.gitignore
fi

exit 0
