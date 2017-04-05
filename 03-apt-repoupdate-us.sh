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
mirror=mirrors.mit.edu
smirror=security.debian.org
ubuntuhost=$mirror/$upath
debianhost=$mirror/$dpath
debsechost=$smirror/
lockfile=/var/lock/subsys/apt_mirror
logfile=/var/log/apt_mirror.log
progfile=/var/log/apt_mirror_prog.log

# Declare some more vars (don't break these)
ubuntusects="main,restricted,universe,multiverse"
debiansects="main,contrib,non-free"
ubunturel1="trusty,trusty-backports,trusty-proposed,trusty-security,trusty-updates"
ubunturel2="xenial,xenial-backports,xenial-proposed,xenial-security,xenial-updates"
debianrel1="wheezy,wheezy-backports,wheezy-updates,wheezy-proposed-updates"
debianrel2="jessie,jessie-backports,jessie-updates,jessie-proposed-updates"
debsecrel="wheezy/updates,jessie/updates"

# Build the commands, with more variables
ubuntuopts="-s $ubuntusects -d $ubunturel1 -d $ubunturel2 -h $mirror -r /$upath"
debianopts="-s $debiansects -d $debianrel1 -d $debianrel2 -h $mirror -r /$dpath"
debsecopts="-s $debiansects -d $debsecrel -h $smirror -r /"
ropts="-ahmzHS --stats --no-motd --del --delete-excluded --log-file=$progfile"
dmirror="debmirror -a $arch --no-source --ignore-small-errors --method=rsync --retry-rsync-packages=5 -p"
dmirror2="debmirror -a $arch --no-source --ignore-small-errors --method=http --checksums -p"
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
    printf "$(date): Error: Cannot reach the $mirror servers.\n\n" | $teelog
    exit 20

# Check that the repository is mounted
elif ! mount | grep $repodir &> /dev/null; then
    printf "$(date): Error: Directory $repodir is not mounted.\n\n" | $teelog
    exit 30
else

    export GNUPGHOME=$repodir

    # Create lockfile, sync ubuntu repo, delete lockfile
    printf "$(date): Beginning rsync of Ubuntu repo from $ubuntuhost.\n" | $teelog
    touch $lockfile
    $dmirror $ubuntuopts $ubunturepo | $teelog
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # Create lockfile, sync debian repo, delete lockfile
    printf "$(date): Beginning rsync of Debian repo from $debianhost.\n" | $teelog
    touch $lockfile
    $dmirror $debianopts $debianrepo | $teelog
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # Create lockfile, sync debian security repo, delete lockfile
    printf "$(date): Beginning rsync of Debian Security repo from $debsechost.\n" | $teelog
    touch $lockfile
    $dmirror2 $debsecopts $debsecrepo | $teelog
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    export GNUPGHOME=

fi

# Now we're done
printf "$(date): Completed synchronization of Ubuntu and Debian repositories.\n\n" | $teelog
exit 0