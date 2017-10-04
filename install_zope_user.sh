#!/bin/bash
HOME="/home"

# necessary libaries
apt-get install -y nano pkg-config bash-completion awstats build-essential
apt-get install -y libjpeg8-dev libssl-dev libpcre++-dev libpng-dev libxslt1-dev libxml2-dev zlib1g-dev libmemcached-dev libreadline-dev libncurses5-dev libyaml-dev nginx
[ -z "`apt-cache search php-fpm`" ] && apt-get install -y php5-fpm || apt-get install -y php-fpm

read -p "Install MySQL? [y/N]" -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt-get install -y mysql-server
    apt-get install -y libmysqlclient-dev
fi

# fix library symlinks for python 2.6
[ ! -f "/usr/lib/libssl.so" ] && ln -s /usr/lib/x86_64-linux-gnu/libssl.so /usr/lib/libssl.so
[ ! -f "/usr/lib/libjpeg.so" ] && ln -s /usr/lib/x86_64-linux-gnu/libjpeg.so /usr/lib/libjpeg.so
[ ! -f "/usr/lib/libz.so" ] && ln -s /usr/lib/x86_64-linux-gnu/libz.so /usr/lib/libz.so

# set timezone (selection list for berlin coordinates)
tzselect -c +52.52+13.0

read -p "Enter username: " -r
USER=$REPLY

[ -z "$USER" ] && echo "please provide a username!" && exit

if [ ! -d "$HOME/$USER" ]; then
    echo "Creating user $USER"
    useradd -m -s /bin/bash $USER
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

py_versions=("2.6.9" "2.7.14")
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

read -p "Enter Buildout Git repository: " -r
BUILDOUT_REPO=$REPLY
su - $USER -c "git clone $BUILDOUT_REPO zope_buildout"

buildout_versions=("1.4.4" "2.9.4")
PS3="Choose zc.buildout version: "
echo
select b_version in "${buildout_versions[@]}"
do
    [ "$b_version" = "1.4.4" ] && setuptools_version="0.6c11" || setuptools_version="33.1.1"
    su - $USER -c "cd zope_buildout && ../python-$py_version/bin/python bootstrap.py -v $b_version --setuptools-version=$setuptools_version && bin/buildout -N"
    break
done

[ ! -d "$HOME/$USER/log" ] && su - $USER -c "mkdir log"
# copy nginx config to system nginx
cp $HOME/$USER/zope_buildout/production/nginx.conf /etc/nginx/sites-enabled/$USER.conf
nginx -t

echo
echo "Installing SysV init script"
cp supervisor.sh /etc/init.d/supervisor
sed -i -e "s/<user>/$USER/g" /etc/init.d/supervisor
chmod +x /etc/init.d/supervisor
update-rc.d supervisor defaults

exit 0
