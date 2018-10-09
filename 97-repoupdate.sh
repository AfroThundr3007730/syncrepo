#!/bin/bash
# Repository updater script for CentOS & Debian distros (upstream)
# Currently syncs: CentOS, EPEL, Debian, Ubuntu, and ClamAV
# Version 1.5.3 updated 20181004 by <AfroThundr>

# TODO: Document all the things.

# Version handler
for i in "$@"; do
    if [ "$i" = "-v" ]; then
        v=$(head -4 "$0" | tail -1)
        printf '%s\n' "$v"
        exit 0
    fi
done

# Declare some variables (modify as necessary)
CENTOS_SYNC=true
EPEL_SYNC=true
DEBIAN_SYNC=true
DEBSEC_SYNC=true
UBUNTU_SYNC=true
CLAMAV_SYNC=true

centarch=x86_64
repodir=/srv/repository
centosrepo=$repodir/centos
epelrepo=$repodir/fedora-epel
clamrepo=$repodir/clamav
mirror=mirrors.mit.edu
smirror=security.debian.org
cmirror=database.clamav.net
centoshost=$mirror::centos
epelhost=$mirror::fedora-epel

debarch=amd64
ubunturepo=$repodir/ubuntu
debianrepo=$repodir/debian
debsecrepo=$repodir/debian-security
ubuntuhost=$mirror::ubuntu
debianhost=$mirror::debian
debsechost=$smirror/

lockfile=/var/lock/subsys/reposync
logfile=/var/log/reposync.log
progfile=/var/log/reposync_progress.log

prodlist=$(head -3 "$0" | tail -1 | cut -d: -f2)

# Declare some more vars (don't break these)
centoslist=$(rsync $centoshost | awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}')
release=$(echo "$centoslist" | tr ' ' '\n' | sort -V | tail -1)
majorver=${release%%.*}
oldmajorver=$((majorver - 1))
oldrelease=$(echo "$centoslist" | tr ' ' '\n' | awk "/^$oldmajorver\\./" | sort -V | tail -1)
prevrelease=$(echo "$centoslist" | tr ' ' '\n' | awk "/^$majorver\\./" | sort -V | tail -2 | head -1)
oldprevrelease=$(echo "$centoslist" | tr ' ' '\n' | awk "/^$oldmajorver\\./" | sort -V | tail -2 | head -1)

ubuntucomps="main,restricted,universe,multiverse"
debiancomps="main,contrib,non-free"
ubunturel1="trusty,trusty-backports,trusty-proposed,trusty-security,trusty-updates"
ubunturel2="xenial,xenial-backports,xenial-proposed,xenial-security,xenial-updates"
debianrel1="wheezy,wheezy-backports,wheezy-updates,wheezy-proposed-updates"
debianrel2="jessie,jessie-backports,jessie-updates,jessie-proposed-updates"
debsecrel1="wheezy/updates"
debsecrel2="jessie/updates"

# Build the commands, with more variables
centosexclude=$(echo --include={os,extras,updates,centosplus,readme,os/$centarch/{repodata,Packages}} --exclude={i386,"os/$centarch/*"} --exclude="/*")
epelexclude=$(echo --exclude={SRPMS,aarch64,i386,ppc64,ppc64le,$centarch/debug})
rsync="rsync -hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file=$progfile"
clamsync="clamavmirror -a $cmirror -d $clamrepo -u root -g www-data"
teelog="tee -a $logfile $progfile"

ubuntuopts1="-s $ubuntucomps -d $ubunturel1 -h $mirror -r /ubuntu"
ubuntuopts2="-s $ubuntucomps -d $ubunturel2 -h $mirror -r /ubuntu"
debianopts1="-s $debiancomps -d $debianrel1 -h $mirror -r /debian"
debianopts2="-s $debiancomps -d $debianrel2 -h $mirror -r /debian"
debsecopts1="-s $debiancomps -d $debsecrel1 -h $smirror -r /"
debsecopts2="-s $debiancomps -d $debsecrel2 -h $smirror -r /"
ropts="-hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file=$progfile"
dmirror="debmirror -a $debarch --no-source --ignore-small-errors --method=rsync --retry-rsync-packages=5 -p --rsync-options="
dmirror2="debmirror -a $debarch --no-source --ignore-small-errors --method=http --checksums -p"

# Here we go...
printf '%s: Progress log reset.\n' "$(date -u +%FT%TZ)" > $progfile
printf '%s: Started synchronization of %s repositories.\n' "$(date -u +%FT%TZ)" "$prodlist" | $teelog
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

    if [ $CENTOS_SYNC == "true" ]; then
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

    if [ $EPEL_SYNC == "true" ]; then
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
    fi

    if [ $UBUNTU_SYNC == "true" ]; then
        export GNUPGHOME=$repodir/.gpg

        # Create lockfile, sync older ubuntu repo, delete lockfile
        printf '%s: Beginning rsync of Legacy Ubuntu %s repo from %s.\n' "$(date -u +%FT%TZ)" "$(cut -d',' -f1 <<< ${ubunturel1^})" "$ubuntuhost" | $teelog
        touch $lockfile
        $dmirror"$ropts" $ubuntuopts1 $ubunturepo | tee -a $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Create lockfile, sync ubuntu repo, delete lockfile
        printf '%s: Beginning rsync of Ubuntu %s repo from %s.\n' "$(date -u +%FT%TZ)" "$(cut -d',' -f1 <<< ${ubunturel2^})" "$ubuntuhost" | $teelog
        touch $lockfile
        $dmirror"$ropts" $ubuntuopts2 $ubunturepo | tee -a $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi

    if [ $DEBIAN_SYNC == "true" ]; then
        # Create lockfile, sync older debian repo, delete lockfile
        printf '%s: Beginning rsync of Legacy Debian %s repo from %s.\n' "$(date -u +%FT%TZ)" "$(cut -d',' -f1 <<< ${debianrel1^})" "$debianhost" | $teelog
        touch $lockfile
        $dmirror"$ropts" $debianopts1 $debianrepo | tee -a $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Create lockfile, sync debian repo, delete lockfile
        printf '%s: Beginning rsync of Debian %s repo from %s.\n' "$(date -u +%FT%TZ)" "$(cut -d',' -f1 <<< ${debianrel2^})" "$debianhost" | $teelog
        touch $lockfile
        $dmirror"$ropts" $debianopts2 $debianrepo | tee -a $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi

    if [ $DEBSEC_SYNC == "true" ]; then
        # Create lockfile, sync older debian security repo, delete lockfile
        printf '%s: Beginning rsync of Legacy Debian %s Security repo from %s.\n' "$(date -u +%FT%TZ)" "$(cut -d',' -f1 <<< ${debianrel1^})" "$debsechost" | $teelog
        touch $lockfile
        $dmirror2 $debsecopts1 $debsecrepo &>> $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Create lockfile, sync debian security repo, delete lockfile
        printf '%s: Beginning rsync of Debian %s Security repo from %s.\n' "$(date -u +%FT%TZ)" "$(cut -d',' -f1 <<< ${debianrel2^})" "$debsechost" | $teelog
        touch $lockfile
        $dmirror2 $debsecopts2 $debsecrepo &>> $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        unset GNUPGHOME
    fi

    if [ $CLAMAV_SYNC == "true" ]; then
        # Create lockfile, sync clamav repo, delete lockfile
        printf '%s: Beginning sync of ClamAV repo from %s.\n' "$(date -u +%FT%TZ)" "$cmirror" | $teelog
        touch $lockfile
        $clamsync &>> $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi
fi

# Now we're done
printf '%s: Completed synchronization of %s repositories.\n\n' "$(date -u +%FT%TZ)" "$prodlist" | $teelog
exit 0