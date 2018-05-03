#!/bin/bash
# Yum repository updater script for CentOS, or really, anything reachable via rsync.
# Currently syncs CentOS 6 and 7, as well as EPEL 6 and 7.
# Version 1.3 updated 20180503 by <AfroThundr>

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
epellist=$(rsync $epelhost | awk '/^d/ && /[0-9]$/ {print $5}')
centossync=$(eval echo --include={$(echo $centoslist | tr ' ' ',')})
epelsync=$(eval echo --include={$(echo $epellist | tr ' ' ',')})
release=$(echo $centoslist | tr ' ' '\n' | tail -1)
majorver=${release%%.*}
oldmajorver=$((majorver-1))
oldrelease=$(echo $centoslist | tr ' ' '\n' | awk "/^$oldmajorver\./" | tail -1)
prevrelease=$(echo $centoslist | tr ' ' '\n' | awk "/^$majorver\./" | tail -2 | head -1)
oldprevrelease=$(echo $centoslist | tr ' ' '\n' | awk "/^$oldmajorver\./" | tail -2 | head -1)

# Build the commands, with more variables
centosexclude=$(echo --include={os,extras,updates,centosplus,readme} --exclude=i386 --exclude="/*")
epelexclude=$(echo --exclude={SRPMS,aarch64,i386,ppc64,ppc64le,$arch/debug})
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

    # Check for older centos release directory
    if [ ! -d $centosrepo/$oldrelease ]; then
        # Make directory if it doesn't exist
        printf "$(date): Directory for CentOS $oldrelease doesn't exist. Creating..\n" | $teelog
        cd $centosrepo; mkdir $oldrelease; rm -f $oldmajorver; ln -s $oldrelease $oldmajorver
    fi

    # Create lockfile, sync older centos repo, delete lockfile
    printf "$(date): Beginning rsync of Legacy CentOS $oldrelease repo from $centoshost.\n" | $teelog
    touch $lockfile
    $rsync $centosexclude $centoshost/$oldrelease/ $centosrepo/$oldrelease/
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # Check for centos release directory
    if [ ! -d $centosrepo/$release ]; then
        # Make directory if it doesn't exist
        printf "$(date): Directory for CentOS $release doesn't exist. Creating..\n" | $teelog
        cd $centosrepo; mkdir $release; rm -f $majorver; ln -s $release $majorver
    fi

    # Create lockfile, sync centos repo, delete lockfile
    printf "$(date): Beginning rsync of CentOS $release repo from $centoshost.\n" | $teelog
    touch $lockfile
    $rsync $centosexclude $centoshost/$release/ $centosrepo/$release/
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # Check for older epel release directory
    if [ ! -d $epelrepo/$oldmajorver ]; then
        # Make directory if it doesn't exist
        printf "$(date): Directory for EPEL $oldmajorver doesn't exist. Creating..\n" | $teelog
        mkdir $epelrepo/$oldmajorver
    fi

    # Create lockfile, sync older epel repo, delete lockfile
    printf "$(date): Beginning rsync of Legacy EPEL $oldmajorver repo from $epelhost.\n" | $teelog
    touch $lockfile
    $rsync $epelexclude $epelhost/$oldmajorver/ $epelrepo/$oldmajorver/
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # Check for older epel-testing release directory
    if [ ! -d $epelrepo/testing/$oldmajorver ]; then
        # Make directory if it doesn't exist
        printf "$(date): Directory for EPEL $oldmajorver Testing doesn't exist. Creating..\n" | $teelog
        mkdir $epelrepo/testing/$oldmajorver
    fi

    # Create lockfile, sync older epel-testing repo, delete lockfile
    printf "$(date): Beginning rsync of Legacy EPEL $oldmajorver Testing repo from $epelhost.\n" | $teelog
    touch $lockfile
    $rsync $epelexclude $epelhost/testing/$oldmajorver/ $epelrepo/testing/$oldmajorver/
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog
    
    # Check for epel release directory
    if [ ! -d $epelrepo/$majorver ]; then
        # Make directory if it doesn't exist
        printf "$(date): Directory for EPEL $majorver doesn't exist. Creating..\n" | $teelog
        mkdir $epelrepo/$majorver
    fi

    # Create lockfile, sync epel repo, delete lockfile
    printf "$(date): Beginning rsync of EPEL $majorver repo from $epelhost.\n" | $teelog
    touch $lockfile
    $rsync $epelexclude $epelhost/$majorver/ $epelrepo/$majorver/
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # Check for epel-testing release directory
    if [ ! -d $epelrepo/testing/$majorver ]; then
        # Make directory if it doesn't exist
        printf "$(date): Directory for EPEL $majorver Testing doesn't exist. Creating..\n" | $teelog
        mkdir $epelrepo/testing/$majorver
    fi

    # Create lockfile, sync epel-testing repo, delete lockfile
    printf "$(date): Beginning rsync of EPEL $majorver Testing repo from $epelhost.\n" | $teelog
    touch $lockfile
    $rsync $epelexclude $epelhost/testing/$majorver/ $epelrepo/testing/$majorver/
    rm -f $lockfile
    printf "$(date): Done.\n\n" | $teelog

    # We ain't out of the woods yet, continue to sync previous point release til its empty
    # Check for older previous centos point release placeholder
    if [ ! -f $centosrepo/$oldprevrelease/readme ]; then

        # Check for older previous centos release directory
        if [ ! -d $centosrepo/$oldprevrelease ]; then
            # Make directory if it doesn't exist
            printf "$(date): Directory for CentOS $oldprevrelease doesn't exist. Creating..\n" | $teelog
            cd $centosrepo; mkdir $oldprevrelease
        fi

        # Create lockfile, sync older previous centos repo, delete lockfile
        printf "$(date): Beginning rsync of CentOS $oldprevrelease repo from $centoshost.\n" | $teelog
        touch $lockfile
        $rsync $centosexclude $centoshost/$oldprevrelease/ $centosrepo/$oldprevrelease/
        rm -f $lockfile
        printf "$(date): Done.\n\n" | $teelog
    fi

    # Check for previous centos point release placeholder
    if [ ! -f $centosrepo/$prevrelease/readme ]; then

        # Check for previous centos release directory
        if [ ! -d $centosrepo/$prevrelease ]; then
            # Make directory if it doesn't exist
            printf "$(date): Directory for CentOS $prevrelease doesn't exist. Creating..\n" | $teelog
            cd $centosrepo; mkdir $prevrelease
        fi

        # Create lockfile, sync previous centos repo, delete lockfile
        printf "$(date): Beginning rsync of CentOS $prevrelease repo from $centoshost.\n" | $teelog
        touch $lockfile
        $rsync $centosexclude $centoshost/$prevrelease/ $centosrepo/$prevrelease/
        rm -f $lockfile
        printf "$(date): Done.\n\n" | $teelog
    fi

fi

# Now we're done
printf "$(date): Completed synchronization of CentOS and EPEL repositories.\n\n" | $teelog
exit 0