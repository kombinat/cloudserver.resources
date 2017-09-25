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

su - $USER -c "mkdir -p stats && mkdir log"
su - $USER -c "rsync -Prv --rsh 'sshpass -p $REMOTE_PWD ssh -l $REMOTE_USER' $REMOTE_USER@$HOST:/home/$REMOTE_USER/zope/buildout/var/filestorage/Data.fs ./zope_buildout/var/filestorage/"
su - $USER -c "rsync -Prv --rsh 'sshpass -p $REMOTE_PWD ssh -l $REMOTE_USER' $REMOTE_USER@$HOST:/home/$REMOTE_USER/zope/buildout/var/blobstorage ./zope_buildout/var/"
su - $USER -c "rsync -Prv --rsh 'sshpass -p $REMOTE_PWD ssh -l $REMOTE_USER' $REMOTE_USER@$HOST:/home/$REMOTE_USER/log/* ./log/"
su - $USER -c "rsync -Prv --rsh 'sshpass -p $REMOTE_PWD ssh -l $REMOTE_USER' $REMOTE_USER@$HOST:/home/$REMOTE_USER/stats/* ./stats/"
