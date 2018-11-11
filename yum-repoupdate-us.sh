#!/bin/bash
# Yum repository updater script for CentOS (upstream)
# Currently syncs CentOS, EPEL, and EPEL Testing
# Version 1.4.2 updated 20181003 by <AfroThundr>

# Version handler
for i in "$@"; do
    if [ "$i" = "-v" ]; then
        v=$(head -4 "$0" | tail -1)
        printf '%s\n' "$v"
        exit 0
    fi
done

# Declare some variables (modify as necessary)
arch=x86_64
repodir=/srv/repository
centosrepo=$repodir/centos
epelrepo=$repodir/epel
mirror=mirrors.mit.edu
centoshost=$mirror::centos
epelhost=$mirror::fedora-epel
lockfile=/var/lock/subsys/yum_rsync
logfile=/var/log/yum_rsync.log
progfile=/var/log/yum_rsync_prog.log

# Declare some more vars (don't break these)
centoslist=$(rsync $centoshost | awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}')
release=$(echo "$centoslist" | tr ' ' '\n' | tail -1)
majorver=${release%%.*}
oldmajorver=$((majorver-1))
oldrelease=$(echo "$centoslist" | tr ' ' '\n' | awk "/^$oldmajorver\\./" | tail -1)
prevrelease=$(echo "$centoslist" | tr ' ' '\n' | awk "/^$majorver\\./" | tail -2 | head -1)
oldprevrelease=$(echo "$centoslist" | tr ' ' '\n' | awk "/^$oldmajorver\\./" | tail -2 | head -1)

# Build the commands, with more variables
centosexclude=$(echo --include={os,extras,updates,centosplus,readme} --exclude=i386 --exclude="/*")
epelexclude=$(echo --exclude={SRPMS,aarch64,i386,ppc64,ppc64le,$arch/debug})
rsync="rsync -hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file=$progfile"
teelog="tee -a $logfile $progfile"

# Here we go...
printf '%s: Progress log reset.\n' "$(date -u +%FT%TZ)" > $progfile
printf '%s: Started synchronization of CentOS and EPEL repositories.\n' "$(date -u +%FT%TZ)" | $teelog
printf '%s: Use tail -f %s to view progress.\n\n' "$(date -u +%FT%TZ)" "$progfile"

# Check if the rsync script is already running
if [ -f $lockfile ]; then
    printf '%s: Error: Repository updates are already running.\n\n' "$(date -u +%FT%TZ)" | $teelog
    exit 10

# Check that we can reach the public mirror
elif ! ping -c 5 $mirror &> /dev/null; then
    printf '%s: Error: Cannot reach the %s mirror server.\n\n' "$(date -u +%FT%TZ)" "$mirror" | $teelog
    exit 20

# Check that the repository is mounted
elif ! mount | grep $repodir &> /dev/null; then
    printf '%s: Error: Directory %s is not mounted.\n\n' "$(date -u +%FT%TZ)" "$repodir" | $teelog
    exit 30

else

    # Check for older centos release directory
    if [ ! -d "$centosrepo/$oldrelease" ]; then
        # Make directory if it doesn't exist
        printf '%s: Directory for CentOS %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$oldrelease" | $teelog
        cd "$centosrepo" || exit 40; mkdir -p "$oldrelease"; rm -f "$oldmajorver"; ln -s "$oldrelease" "$oldmajorver"
    fi

    # Create lockfile, sync older centos repo, delete lockfile
    printf '%s: Beginning rsync of Legacy CentOS %s repo from %s.\n' "$(date -u +%FT%TZ)" "$oldrelease" "$centoshost" | $teelog
    touch $lockfile
    $rsync $centosexclude "$centoshost/$oldrelease/" "$centosrepo/$oldrelease/"
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

    # Check for centos release directory
    if [ ! -d "$centosrepo/$release" ]; then
        # Make directory if it doesn't exist
        printf '%s: Directory for CentOS %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$release" | $teelog
        cd "$centosrepo" || exit 40; mkdir -p "$release"; rm -f "$majorver"; ln -s "$release" "$majorver"
    fi

    # Create lockfile, sync centos repo, delete lockfile
    printf '%s: Beginning rsync of CentOS %s repo from %s.\n' "$(date -u +%FT%TZ)" "$release" "$centoshost" | $teelog
    touch $lockfile
    $rsync $centosexclude "$centoshost/$release/" "$centosrepo/$release/"
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

    # Check for older epel release directory
    if [ ! -d "$epelrepo/$oldmajorver" ]; then
        # Make directory if it doesn't exist
        printf '%s: Directory for EPEL %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$oldmajorver" | $teelog
        mkdir -p "$epelrepo/$oldmajorver"
    fi

    # Create lockfile, sync older epel repo, delete lockfile
    printf '%s: Beginning rsync of Legacy EPEL %s repo from %s.\n' "$(date -u +%FT%TZ)" "$oldmajorver" "$epelhost" | $teelog
    touch $lockfile
    $rsync $epelexclude "$epelhost/$oldmajorver/" "$epelrepo/$oldmajorver/"
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

    # Check for older epel-testing release directory
    if [ ! -d "$epelrepo/testing/$oldmajorver" ]; then
        # Make directory if it doesn't exist
        printf '%s: Directory for EPEL %s Testing does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$oldmajorver" | $teelog
        mkdir -p "$epelrepo/testing/$oldmajorver"
    fi

    # Create lockfile, sync older epel-testing repo, delete lockfile
    printf '%s: Beginning rsync of Legacy EPEL %s Testing repo from %s.\n' "$(date -u +%FT%TZ)" "$oldmajorver" "$epelhost" | $teelog
    touch $lockfile
    $rsync $epelexclude "$epelhost/testing/$oldmajorver/" "$epelrepo/testing/$oldmajorver/"
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

    # Check for epel release directory
    if [ ! -d "$epelrepo/$majorver" ]; then
        # Make directory if it doesn't exist
        printf '%s: Directory for EPEL %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$majorver" | $teelog
        mkdir -p "$epelrepo/$majorver"
    fi

    # Create lockfile, sync epel repo, delete lockfile
    printf '%s: Beginning rsync of EPEL %s repo from %s.\n' "$(date -u +%FT%TZ)" "$majorver" "$epelhost" | $teelog
    touch $lockfile
    $rsync $epelexclude "$epelhost/$majorver/" "$epelrepo/$majorver/"
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

    # Check for epel-testing release directory
    if [ ! -d "$epelrepo/testing/$majorver" ]; then
        # Make directory if it doesn't exist
        printf '%s: Directory for EPEL %s Testing does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$majorver" | $teelog
        mkdir -p "$epelrepo/testing/$majorver"
    fi

    # Create lockfile, sync epel-testing repo, delete lockfile
    printf '%s: Beginning rsync of EPEL %s Testing repo from %s.\n' "$(date -u +%FT%TZ)" "$majorver" "$epelhost" | $teelog
    touch $lockfile
    $rsync $epelexclude "$epelhost/testing/$majorver/" "$epelrepo/testing/$majorver/"
    rm -f $lockfile
    printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

    # We ain't out of the woods yet, continue to sync previous point release til its empty
    # Check for older previous centos point release placeholder
    if [ ! -f "$centosrepo/$oldprevrelease/readme" ]; then

        # Check for older previous centos release directory
        if [ ! -d "$centosrepo/$oldprevrelease" ]; then
            # Make directory if it doesn't exist
            printf '%s: Directory for CentOS %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$oldprevrelease" | $teelog
            cd "$centosrepo" || exit 40; mkdir -p "$oldprevrelease"
        fi

        # Create lockfile, sync older previous centos repo, delete lockfile
        printf '%s: Beginning rsync of CentOS %s repo from %s.\n' "$(date -u +%FT%TZ)" "$oldprevrelease" "$centoshost" | $teelog
        touch $lockfile
        $rsync $centosexclude "$centoshost/$oldprevrelease/" "$centosrepo/$oldprevrelease/"
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi

    # Check for previous centos point release placeholder
    if [ ! -f "$centosrepo/$prevrelease/readme" ]; then

        # Check for previous centos release directory
        if [ ! -d "$centosrepo/$prevrelease" ]; then
            # Make directory if it doesn't exist
            printf '%s: Directory for CentOS %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$prevrelease" | $teelog
            cd "$centosrepo" || exit 40; mkdir -p "$prevrelease"
        fi

        # Create lockfile, sync previous centos repo, delete lockfile
        printf '%s: Beginning rsync of CentOS %s repo from %s.\n' "$(date -u +%FT%TZ)" "$prevrelease" "$centoshost" | $teelog
        touch $lockfile
        $rsync $centosexclude "$centoshost/$prevrelease/" "$centosrepo/$prevrelease/"
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi

fi

# Now we're done
printf '%s: Completed synchronization of CentOS and EPEL repositories.\n\n' "$(date -u +%FT%TZ)" | $teelog
exit 0