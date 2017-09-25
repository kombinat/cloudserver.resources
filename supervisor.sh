#! /bin/sh
### BEGIN INIT INFO
# Provides:          supervisor
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: supervisor init script
# Description:       This file should be used to construct scripts to be
#                    placed in /etc/init.d.
### END INIT INFO

# Author: Peter Mathis <peter.mathis@kombinat.at>
#

# Do NOT "set -e"

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
HOME="/home/<user>/zope_buildout"
DESC="Supervisor"
NAME=supervisord
DAEMON=$HOME/bin/$NAME
CONTROL=$HOME/bin/supervisorctl
DAEMON_ARGS=""
PIDFILE=$HOME/var/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

case "$1" in
  start)
	$DAEMON
	;;
  stop)
	$CONTROL shutdown
	;;
  status)
	$CONTROL status
	;;
  restart|force-reload)
	$CONTROL reload
	;;
  *)
	echo "Usage: $SCRIPTNAME {start|stop|status|restart|force-reload}" >&2
	exit 3
	;;
esac

:
