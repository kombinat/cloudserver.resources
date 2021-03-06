#!/bin/bash
HOME="/home"

# necessary libaries
apt-get install -y nano pkg-config bash-completion nginx awstats build-essential ntpdate net-tools rename lynx
# python dependencies
apt-get install -y libjpeg8-dev libssl-dev libpcre++-dev libpng-dev libxslt1-dev libxml2-dev zlib1g-dev libmemcached-dev libreadline-dev libncurses5-dev libyaml-dev libsqlite3-dev python-docutils
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

py_versions=("2.6.9" "2.7.17")
PS3="Choose Python Version: "
echo
select py_version in "${py_versions[@]}"
do
    py_prefix="$HOME/$USER/python-$py_version"
    [ -x "$py_prefix" ] && break

    # install python
    su - $USER -c "wget https://www.python.org/ftp/python/$py_version/Python-$py_version.tgz"
    su - $USER -c "tar -xzvf Python-$py_version.tgz"
    su - $USER -c "cd Python-$py_version && ./configure --prefix $py_prefix && make && make install"
    su - $USER -c "rm -rf Python-$py_version*"
    # install pip and virtualenv
    su - $USER -c "wget https://bootstrap.pypa.io/get-pip.py"
    su - $USER -c "$py_prefix/bin/python get-pip.py"
    su - $USER -c "rm get-pip.py"
    su - $USER -c "$py_prefix/bin/pip install virtualenv"
    break
done

if [ -x "$HOME/$USER/zope_buildout" ]; then
    echo "Buildout already exists! Exiting ..."
    exit
fi

su - $USER -c "mkdir -p $HOME/$USER/.buildout/eggs"
su - $USER -c "mkdir -p $HOME/$USER/.buildout/dlcache"
su - $USER -c "echo '[buildout]' > $HOME/$USER/.buildout/default.cfg"
su - $USER -c "echo 'prefer-final = false' >> $HOME/$USER/.buildout/default.cfg"
su - $USER -c "echo 'unzip = true' >> $HOME/$USER/.buildout/default.cfg"
su - $USER -c "echo 'eggs-directory = $HOME/$USER/.buildout/eggs' >> $HOME/$USER/.buildout/default.cfg"
su - $USER -c "echo 'download-cache = $HOME/$USER/.buildout/dlcache' >> $HOME/$USER/.buildout/default.cfg"
su - $USER -c "echo 'index = https://pypi.org/simple/' >> $HOME/$USER/.buildout/default.cfg"

read -p "Enter Buildout Git repository: " -r
BUILDOUT_REPO=$REPLY
su - $USER -c "git clone $BUILDOUT_REPO zope_buildout"
su - $USER -c "cd zope_buildout && ../python-$py_version/bin/virtualenv . && ./bin/pip install -r requirements.txt && ./bin/buildout -N"

[ ! -d "$HOME/$USER/log" ] && su - $USER -c "mkdir log"
# copy nginx config to system nginx
cp $HOME/$USER/zope_buildout/production/nginx.conf /etc/nginx/sites-enabled/$USER.conf
nginx -t

. install_sysv_init.sh $USER

exit 0
