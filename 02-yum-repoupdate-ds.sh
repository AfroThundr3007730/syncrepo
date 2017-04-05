#!/bin/bash
# Yum repository updater script for CentOS, or really, anything reachable via rsync.
# Currently syncs CentOS 6 and 7, as well as EPEL 6 and 7.
# Version 1.2 updated 20170224 by <AfroThundr>

# Declare some variables (modify as necessary)
arch=x86_64
repodir=/srv/repository
centosrepo=$repodir/centos
epelrepo=$repodir/epel
mirror=yum.dmz.lab.local
centoshost=$mirror::centos
epelhost=$mirror::fedora-epel
lockfile=/var/lock/subsys/yum_rsync
logfile=/var/log/yum_rsync.log
progfile=/var/log/yum_rsync_prog.log

# Build the commands, with more variables
rsync="rsync -ahmzHS --stats --no-motd --del --delete-excluded --log-file=$progfile"
teelog="tee -a $logfile $progfile"

# Here we go...
printf "$(date): Started synchronization of CentOS and EPEL repositories.\n" | $teelog
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

    # Create lockfile, sync centos repo, delete lockfile
    printf "$(date): Beginning rsync of CentOS repo from $centoshost.\n" | $teelog
    touch $lockfile
    $rsync $centoshost/ $centosrepo/ | $teelog
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # Create lockfile, sync epel repo, delete lockfile
    printf "$(date): Beginning rsync of EPEL repo from $epelhost.\n" | $teelog
    touch $lockfile
    $rsync $epelhost/ $epelrepo/ | $teelog
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

fi

# Now we're done
printf "$(date): Completed synchronization of CentOS and EPEL repositories.\n\n" | $teelog
exit 0