#!/bin/bash
HOME="/home"

# List of system-related dependencies
SYSTEM_DEPENDENCIES=(
    nano
    pkg-config
    bash-completion
    nginx
    awstats
    build-essential
    ntpdate
    net-tools
    rename
    lynx
    libwww-perl
    munin-node
    certbot
    python3-certbot-nginx
)

echo "Starting installation of system dependencies..."

for pkg in "${SYSTEM_DEPENDENCIES[@]}"; do
    echo "Checking package: $pkg ..."
    if apt-cache show "$pkg" > /dev/null 2>&1; then
        if dpkg -s "$pkg" > /dev/null 2>&1; then
            echo "✔️  $pkg is already installed – skipping."
        else
            sudo apt-get install -y "$pkg"
        fi
    else
        echo "⚠️  Package '$pkg' is not available – skipping."
    fi
done

# List of Python-related dependencies
PYTHON_DEPENDENCIES=(
    libjpeg8-dev
    libssl-dev
    libpcre++-dev
    libpcre3-dev
    libpng-dev
    libxslt1-dev
    libxml2-dev
    zlib1g-dev
    libmemcached-dev
    libreadline-dev
    libncurses5-dev
    libyaml-dev
    libsqlite3-dev
    poppler-utils
    libffi-dev
    liblzma-dev
    libbz2-dev
    libcrypt-dev
    libfreetype-dev
)

echo "Starting installation of Python dependencies..."

for pkg in "${PYTHON_DEPENDENCIES[@]}"; do
    echo "Checking package: $pkg ..."
    if apt-cache show "$pkg" > /dev/null 2>&1; then
        if dpkg -s "$pkg" > /dev/null 2>&1; then
            echo "✔️  $pkg is already installed – skipping."
        else
            sudo apt-get install -y "$pkg"
        fi
    else
        echo "⚠️  Package '$pkg' is not available – skipping."
    fi
done

# varnish
apt-get install -y python3-docutils

# certbot
if dpkg -s certbot > /dev/null 2>&1; then
    echo "✔️  certbot is already installed – skipping."
else
    read -p "Install Certbot? [y/N]" -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        snap install --classic certbot
    fi
fi

#mysql
if dpkg -s mysql-server > /dev/null 2>&1; then
    echo "✔️  mysql is already installed – skipping."
else
    read -p "Install MySQL? [y/N]" -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt-get install -y mysql-server
        apt-get install -y libmysqlclient-dev
    fi
fi

# postfix
if dpkg -s mailutils > /dev/null 2>&1; then
    echo "✔️  postfix is already installed – skipping."
else
    read -p "Install Postfix? [y/N]" -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt-get -y install mailutils
        echo
        echo "You may want to configure postfix as readonly SMTP relay with"
        echo " > inet_interfaces = localhost"
        echo "in /etc/postfix/main.cf"
    fi
fi

# timezone
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

# php-fpm
if dpkg -s php-fpm > /dev/null 2>&1; then
    echo "✔️  php-fpm is already installed – skipping."
else
    read -p "Install php-fpm? [y/N]" -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # install cgi-bin.php for fastcgi (awstats support)
        echo
        echo "Installing cgi-bin.php to /etc/nginx for php support"
        apt-get install -y php-fpm
        cp cgi-bin.php /etc/nginx/
    fi
fi

echo "Done setting up your server."
