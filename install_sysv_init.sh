#!/bin/bash
echo
echo "Installing SysV init script"
cp supervisor.sh /etc/init.d/supervisor
sed -i -e "s/<user>/$USER/g" /etc/init.d/supervisor
chmod +x /etc/init.d/supervisor
update-rc.d supervisor defaults

exit 0
