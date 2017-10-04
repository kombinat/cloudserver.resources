#!/bin/bash
BACKUPTOOL=/opt/1UND1EU/bin/ClientTool

[ -d /media/cdrom ] || mkdir /media/cdrom
mount -t auto /dev/cdrom /media/cdrom
BACKUPMANAGER=`ls /media/cdrom/linux/*x86_64.run`

if [ -z "$BACKUPMANAGER" ]; then
    echo "Backupmanager not found!"
    ls -l /media/cdrom/linux
    exit 1
fi

echo "Starting $BACKUPMANAGER"
sh $BACKUPMANAGER
umount /media/cdrom

$BACKUPTOOL control.schedule.list
echo
read -p "Do you want to install new schedule for /home? [y/N] " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    $BACKUPTOOL control.schedule.add -name home_directory -datasources FileSystem -days All -time 02:00
    $BACKUPTOOL control.schedule.list
fi

echo
$BACKUPTOOL control.selection.modify -datasource FileSystem -include /home
$BACKUPTOOL control.selection.modify -datasource FileSystem -include /etc
$BACKUPTOOL control.selection.list
