#!/bin/bash
# Apt repository updater script for Ubuntu (downstream)
# Currently syncs Ubuntu, Debian, and Debian Security
# Version 1.4 updated 20180521 by <AfroThundr>

# Version handler
for i in "$@"; do
    if [ "$i" = "-v" ]; then
        v=$(head -4 "$0" | tail -1)
        printf '%s\n' "$v"
        exit 0
    fi
done

# Declare some variables (modify as necessary)
repodir=/srv/repository
ubunturepo=$repodir/ubuntu
debianrepo=$repodir/debian
debsecrepo=$repodir/debian-security
mirror=apt.dmz.lab.local
ubuntuhost=$mirror::ubuntu
debianhost=$mirror::debian
debsechost=$mirror::debian-security
lockfile=/var/lock/subsys/yum_rsync
logfile=/var/log/yum_rsync.log
progfile=/var/log/yum_rsync_prog.log

# Build the commands, with more variables
rsync="rsync -ahmzHS --stats --no-motd --del --delete-excluded --log-file=$progfile"
teelog="tee -a $logfile $progfile"

# Here we go...
printf '%s: Started synchronization of Ubuntu and Debian repositories.\n' "$(date)" | $teelog
printf '%s: Use tail -f %s to view progress.\n\n' "$(date)" "$progfile"

# Check if the rsync script is already running
if [ -f $lockfile ]; then
    printf '%s: Error: Repository updates are already running.\n\n' "$(date)" | $teelog
    exit 10

# Check that we can reach the public mirror
elif ! ping -c 5 $mirror &> /dev/null; then
    printf '%s: Error: Cannot reach the %s mirror server.\n\n' "$(date)" "$mirror" | $teelog
    exit 20

# Check that the repository is mounted
elif ! mount | grep $repodir &> /dev/null; then
    printf '%s: Error: Directory %s is not mounted.\n\n' "$(date)" "$repodir" | $teelog
    exit 30
else

    # Just sync everything since we're downstream

    # Create lockfile, sync ubuntu repo, delete lockfile
    printf '%s: Beginning rsync of Ubuntu repo from %s.\n' "$(date)" "$ubuntuhost" | $teelog
    touch $lockfile
    $rsync "$ubuntuhost/" "$ubunturepo/"
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date)" | $teelog

    # Create lockfile, sync debian repo, delete lockfile
    printf '%s: Beginning rsync of Debian repo from %s.\n' "$(date)" "$debianhost" | $teelog
    touch $lockfile
    $rsync "$debianhost/" "$debianrepo/"
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date)" | $teelog

    # Create lockfile, sync debian security repo, delete lockfile
    printf '%s: Beginning rsync of Debian Security repo from %s.\n' "$(date)" "$debsechost" | $teelog
    touch $lockfile
    $rsync "$debsechost/" "$debsecrepo/"
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date)" | $teelog

fi

# Now we're done
printf '%s: Completed synchronization of Ubuntu and Debian repositories.\n\n' "$(date)" | $teelog
exit 0