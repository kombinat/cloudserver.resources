#!/bin/bash
apt-get install -y sshpass

read -p "Sync Stats/Logs/ZODB for Username: " -r
USER=$REPLY
read -p "Remote Username: " -r
REMOTE_USER=$REPLY
read -p "Remote Password: " -r
REMOTE_PWD=$REPLY
read -p "Remote Server: " -r
HOST=$REPLY
read -p "Remote Subbath in User directory: " -r
SUBPATH=$REPLY

if [ -z "`cat /home/$USER/.ssh/known_hosts | grep $HOST`" ]; then
    su - $USER -c "ssh-keyscan $HOST >> .ssh/known_hosts"
fi

su - $USER -c "mkdir -p stats && mkdir log"
su - $USER -c "rsync -Prv --rsh 'sshpass -p $REMOTE_PWD ssh -l $REMOTE_USER' $REMOTE_USER@$HOST:/home/$REMOTE_USER/$SUBPATH/var/filestorage/Data.fs ./zope_buildout/var/filestorage/"
su - $USER -c "rsync -Prv --rsh 'sshpass -p $REMOTE_PWD ssh -l $REMOTE_USER' $REMOTE_USER@$HOST:/home/$REMOTE_USER/$SUBPATH/var/blobstorage ./zope_buildout/var/"
su - $USER -c "rsync -Prv --rsh 'sshpass -p $REMOTE_PWD ssh -l $REMOTE_USER' $REMOTE_USER@$HOST:/home/$REMOTE_USER/log/* ./log/"
su - $USER -c "rsync -Prv --rsh 'sshpass -p $REMOTE_PWD ssh -l $REMOTE_USER' $REMOTE_USER@$HOST:/home/$REMOTE_USER/stats/* ./stats/"
