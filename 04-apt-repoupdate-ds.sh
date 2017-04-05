#!/bin/bash
# Apt repository updater script for Ubuntu, or really, anything reachable via rsync.
# Currently syncs Ubuntu Trusty and Xenial, as well as Debian Wheezy and Jessie.
# Version 1.2 updated 20170224 by <AfroThundr>

# Declare some variables (modify as necessary)
arch=amd64
upath=ubuntu
dpath=debian
spath=debian-security
repodir=/srv/repository
ubunturepo=$repodir/$upath
debianrepo=$repodir/$dpath
debsecrepo=$repodir/$spath
mirror=apt.dmz.lab.local
ubuntuhost=$mirror::$upath
debianhost=$mirror::$dpath
debsechost=$mirror::$spath
lockfile=/var/lock/subsys/yum_rsync
logfile=/var/log/yum_rsync.log
progfile=/var/log/yum_rsync_prog.log

# Build the commands, with more variables
rsync="rsync -ahmzHS --stats --no-motd --del --delete-excluded --log-file=$progfile"
teelog="tee -a $logfile $progfile"

# Here we go...
printf "$(date): Started synchronization of Ubuntu and Debian repositories.\n" | $teelog
printf "$(date): Use tail -f $progfile to view progress.\n\n"

# Check if the rsync script is already running
if [ -f $lockfile ]; then
    printf "$(date): Error: Repository updates are already running.\n\n" | $teelog
    exit 10

# Check that we can reach the public mirror
elif ! ping -c 5 $mirror &> /dev/null; then
    printf "$(date): Error: Cannot reach the $mirror mirror server.\n\n" | $teelog
    exit 20

# Check that the repository is mounted
elif ! mount | grep $repodir &> /dev/null; then
    printf "$(date): Error: Directory $repodir is not mounted.\n\n" | $teelog
    exit 30
else

    # Just sync everything since we're downstream

    # Create lockfile, sync ubuntu repo, delete lockfile
    printf "$(date): Beginning rsync of Ubuntu repo from $centoshost.\n" | $teelog
    touch $lockfile
    $rsync $ubuntuhost/ $ubunturepo/ | $teelog
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # Create lockfile, sync debian repo, delete lockfile
    printf "$(date): Beginning rsync of Debian repo from $epelhost.\n" | $teelog
    touch $lockfile
    $rsync $debianhost/ $debianrepo/ | $teelog
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # Create lockfile, sync debian security repo, delete lockfile
    printf "$(date): Beginning rsync of Debian Security repo from $epelhost.\n" | $teelog
    touch $lockfile
    $rsync $debsechost/ $debsecrepo/ | $teelog
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

fi

# Now we're done
printf "$(date): Completed synchronization of Ubuntu and Debian repositories.\n\n" | $teelog
exit 0