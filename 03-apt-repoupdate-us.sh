#!/bin/bash
# Apt repository updater script for Ubuntu (upstream)
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
arch=amd64
repodir=/srv/repository
ubunturepo=$repodir/ubuntu
debianrepo=$repodir/debian
debsecrepo=$repodir/debian-security
mirror=mirrors.mit.edu
smirror=security.debian.org
ubuntuhost=$mirror::ubuntu
debianhost=$mirror::debian
debsechost=$smirror/
lockfile=/var/lock/subsys/apt_mirror
logfile=/var/log/apt_mirror.log
progfile=/var/log/apt_mirror_prog.log

# Declare some more vars (modify as necessary)
ubuntucomps="main,restricted,universe,multiverse"
debiancomps="main,contrib,non-free"
ubunturel1="trusty,trusty-backports,trusty-proposed,trusty-security,trusty-updates"
ubunturel2="xenial,xenial-backports,xenial-proposed,xenial-security,xenial-updates"
debianrel1="wheezy,wheezy-backports,wheezy-updates,wheezy-proposed-updates"
debianrel2="jessie,jessie-backports,jessie-updates,jessie-proposed-updates"
debsecrel="wheezy/updates,jessie/updates"

# Build the commands, with more variables
ubuntuopts="-s $ubuntucomps -d $ubunturel1 -d $ubunturel2 -h $mirror -r /ubuntu"
debianopts="-s $debiancomps -d $debianrel1 -d $debianrel2 -h $mirror -r /debian"
debsecopts="-s $debiancomps -d $debsecrel -h $smirror -r /"
ropts="-ahmzHS --stats --no-motd --del --delete-excluded --log-file=$progfile"
dmirror="debmirror -a $arch --no-source --ignore-small-errors --method=rsync --retry-rsync-packages=5 -p --rsync-options="
dmirror2="debmirror -a $arch --no-source --ignore-small-errors --method=http --checksums -p"
teelog="tee -a $logfile $progfile"

# Here we go...
printf '%s: Started synchronization of Ubuntu and Debian repositories.\n' "$(date -u +%FT%TZ)" | $teelog
printf '%s: Use tail -f %s to view progress.\n\n' "$(date -u +%FT%TZ)" "$progfile"

# Check if the rsync script is already running
if [ -f $lockfile ]; then
    printf '%s: Error: Repository updates are already running.\n\n' "$(date -u +%FT%TZ)" | $teelog
    exit 10

# Check that we can reach the public mirror
elif ! ping -c 5 $mirror &> /dev/null; then
    printf '%s: Error: Cannot reach the %s servers.\n\n' "$(date -u +%FT%TZ)" "$mirror" | $teelog
    exit 20

# Check that the repository is mounted
elif ! mount | grep $repodir &> /dev/null; then
    printf '%s: Error: Directory %s is not mounted.\n\n' "$(date -u +%FT%TZ)" "$repodir" | $teelog
    exit 30
else

    export GNUPGHOME=$repodir

    # Create lockfile, sync ubuntu repo, delete lockfile
    printf '%s: Beginning rsync of Ubuntu repo from %s.\n' "$(date -u +%FT%TZ)" "$ubuntuhost" | $teelog
    touch $lockfile
    $dmirror"$ropts" $ubuntuopts $ubunturepo
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

    # Create lockfile, sync debian repo, delete lockfile
    printf '%s: Beginning rsync of Debian repo from %s.\n' "$(date -u +%FT%TZ)" "$debianhost" | $teelog
    touch $lockfile
    $dmirror"$ropts" $debianopts $debianrepo
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

    # Create lockfile, sync debian security repo, delete lockfile
    printf '%s: Beginning rsync of Debian Security repo from %s.\n' "$(date -u +%FT%TZ)" "$debsechost" | $teelog
    touch $lockfile
    $dmirror2 $debsecopts $debsecrepo
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

    unset GNUPGHOME

fi

# Now we're done
printf '%s: Completed synchronization of Ubuntu and Debian repositories.\n\n' "$(date -u +%FT%TZ)" | $teelog
exit 0