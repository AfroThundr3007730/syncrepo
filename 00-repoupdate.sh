#!/bin/bash
# Repository updater script for CentOS & Debian distros (upstream)
# Currently, this script can sync the following packages:
SOFTWARE='CentOS, EPEL, Debian, Ubuntu, and ClamAV'

AUTHOR='AfroThundr'
UPDATED='20181011'
VERSION='1.6.1'

# TODO: Document all the things.

# Version handler
for i in "$@"; do
    if [ "$i" = "-v" ]; then
        printf '%s: Version %s, updated %s by %s\n' "${0##*/}" "$VERSION" "$UPDATED" "$AUTHOR"
    fi
done

# Declare some config variables (modify as necessary)
CENTOS_SYNC=false
EPEL_SYNC=false
DEBIAN_SYNC=true
DEBSEC_SYNC=false
UBUNTU_SYNC=true
CLAMAV_SYNC=false

centarch=x86_64
repodir=/srv/repository
centrepo=$repodir/centos
epelrepo=$repodir/fedora-epel
clamrepo=$repodir/clamav
mirror=mirrors.mit.edu
smirror=security.debian.org
cmirror=database.clamav.net
centhost=$mirror::centos
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

# Declare some more vars. Lets use arrays, because reasons
read -r -a allrels <<< $( rsync $centhost | awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}' | sort -V )
read -r -a oldrels <<< $( for i in "${allrels[@]}"; do if [ "${i%%.*}" == "(${allrels[-1]%%.*} - 1)" ]; then echo "$i"; fi; done )
currel=${allrels[-1]}
curmaj=${currel%%.*}
cprerel=${allrels[-2]}
oldrel=${oldrels[-1]}
oldmaj=${oldrel%%.*}
oprerel=${oldrels[-2]}

read -r -a uburels <<< $( curl -s http://releases.ubuntu.com | awk -F '[() ]' '/<li>/ && /LTS/ {print $6}' )
read -r -a debrels <<< $( curl -s https://www.debian.org/releases/ | awk -F '[<>]' '/<li>/ && /<q>/ {print $7}' )
ubucur=${uburels[1],}
ubupre=${uburels[2],}
debcur=${debrels[0]}
debpre=${debrels[1]}

ubuntucomps="main,restricted,universe,multiverse"
debiancomps="main,contrib,non-free"
ubunturel1="$ubupre,$ubupre-backports,$ubupre-updates,$ubupre-proposed,$ubupre-security"
ubunturel2="$ubucur,$ubucur-backports,$ubupre-updates,$ubucur-proposed,$ubucur-security"
debianrel1="$debpre,$debpre-backports,$debpre-updates,$debpre-proposed-updates"
debianrel2="$debcur,$debcur-backports,$debcur-updates,$debcur-proposed-updates"
debsecrel1="$debpre/updates"
debsecrel2="$debcur/updates"

# Build the commands, with more variables
centex=$(echo --include={os,extras,updates,centosplus,readme,os/$centarch/{repodata,Packages}} --exclude={i386,"os/$centarch/*"} --exclude="/*")
epelex=$(echo --exclude={SRPMS,aarch64,i386,ppc64,ppc64le,$centarch/debug})
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
printf '%s: Started synchronization of %s repositories.\n' "$(date -u +%FT%TZ)" "$SOFTWARE" | $teelog
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
        if [ ! -d "$centrepo/$oldrel" ]; then
            # Make directory if it doesn't exist
            printf '%s: Directory for CentOS %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$oldrel" | $teelog
            cd "$centrepo" || exit 40; mkdir -p "$oldrel"; rm -f "$oldmaj"; ln -s "$oldrel" "$oldmaj"
        fi

        # Create lockfile, sync older centos repo, delete lockfile
        printf '%s: Beginning rsync of Legacy CentOS %s repo from %s.\n' "$(date -u +%FT%TZ)" "$oldrel" "$centhost" | $teelog
        touch $lockfile
        $rsync $centex "$centhost/$oldrel/" "$centrepo/$oldrel/"
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Check for centos release directory
        if [ ! -d "$centrepo/$currel" ]; then
            # Make directory if it doesn't exist
            printf '%s: Directory for CentOS %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$currel" | $teelog
            cd "$centrepo" || exit 40; mkdir -p "$currel"; rm -f "$curmaj"; ln -s "$currel" "$curmaj"
        fi

        # Create lockfile, sync centos repo, delete lockfile
        printf '%s: Beginning rsync of CentOS %s repo from %s.\n' "$(date -u +%FT%TZ)" "$currel" "$centhost" | $teelog
        touch $lockfile
        $rsync $centex "$centhost/$currel/" "$centrepo/$currel/"
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # We ain't out of the woods yet, continue to sync previous point release til its empty
        # Check for older previous centos point release placeholder
        if [ ! -f "$centrepo/$oprerel/readme" ]; then

            # Check for older previous centos release directory
            if [ ! -d "$centrepo/$oprerel" ]; then
                # Make directory if it doesn't exist
                printf '%s: Directory for CentOS %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$oprerel" | $teelog
                cd "$centrepo" || exit 40; mkdir -p "$oprerel"
            fi

            # Create lockfile, sync older previous centos repo, delete lockfile
            printf '%s: Beginning rsync of CentOS %s repo from %s.\n' "$(date -u +%FT%TZ)" "$oprerel" "$centhost" | $teelog
            touch $lockfile
            $rsync $centex "$centhost/$oprerel/" "$centrepo/$oprerel/"
            rm -f $lockfile
            printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
        fi

        # Check for previous centos point release placeholder
        if [ ! -f "$centrepo/$cprerel/readme" ]; then

            # Check for previous centos release directory
            if [ ! -d "$centrepo/$cprerel" ]; then
                # Make directory if it doesn't exist
                printf '%s: Directory for CentOS %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$cprerel" | $teelog
                cd "$centrepo" || exit 40; mkdir -p "$cprerel"
            fi

            # Create lockfile, sync previous centos repo, delete lockfile
            printf '%s: Beginning rsync of CentOS %s repo from %s.\n' "$(date -u +%FT%TZ)" "$cprerel" "$centhost" | $teelog
            touch $lockfile
            $rsync $centex "$centhost/$cprerel/" "$centrepo/$cprerel/"
            rm -f $lockfile
            printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
        fi
    fi

    if [ $EPEL_SYNC == "true" ]; then
        # Check for older epel release directory
        if [ ! -d "$epelrepo/$oldmaj" ]; then
            # Make directory if it doesn't exist
            printf '%s: Directory for EPEL %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$oldmaj" | $teelog
            mkdir -p "$epelrepo/$oldmaj"
        fi

        # Create lockfile, sync older epel repo, delete lockfile
        printf '%s: Beginning rsync of Legacy EPEL %s repo from %s.\n' "$(date -u +%FT%TZ)" "$oldmaj" "$epelhost" | $teelog
        touch $lockfile
        $rsync $epelex "$epelhost/$oldmaj/" "$epelrepo/$oldmaj/"
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Check for older epel-testing release directory
        if [ ! -d "$epelrepo/testing/$oldmaj" ]; then
            # Make directory if it doesn't exist
            printf '%s: Directory for EPEL %s Testing does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$oldmaj" | $teelog
            mkdir -p "$epelrepo/testing/$oldmaj"
        fi

        # Create lockfile, sync older epel-testing repo, delete lockfile
        printf '%s: Beginning rsync of Legacy EPEL %s Testing repo from %s.\n' "$(date -u +%FT%TZ)" "$oldmaj" "$epelhost" | $teelog
        touch $lockfile
        $rsync $epelex "$epelhost/testing/$oldmaj/" "$epelrepo/testing/$oldmaj/"
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Check for epel release directory
        if [ ! -d "$epelrepo/$curmaj" ]; then
            # Make directory if it doesn't exist
            printf '%s: Directory for EPEL %s does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$curmaj" | $teelog
            mkdir -p "$epelrepo/$curmaj"
        fi

        # Create lockfile, sync epel repo, delete lockfile
        printf '%s: Beginning rsync of EPEL %s repo from %s.\n' "$(date -u +%FT%TZ)" "$curmaj" "$epelhost" | $teelog
        touch $lockfile
        $rsync $epelex "$epelhost/$curmaj/" "$epelrepo/$curmaj/"
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Check for epel-testing release directory
        if [ ! -d "$epelrepo/testing/$curmaj" ]; then
            # Make directory if it doesn't exist
            printf '%s: Directory for EPEL %s Testing does not exist. Creating..\n' "$(date -u +%FT%TZ)" "$curmaj" | $teelog
            mkdir -p "$epelrepo/testing/$curmaj"
        fi

        # Create lockfile, sync epel-testing repo, delete lockfile
        printf '%s: Beginning rsync of EPEL %s Testing repo from %s.\n' "$(date -u +%FT%TZ)" "$curmaj" "$epelhost" | $teelog
        touch $lockfile
        $rsync $epelex "$epelhost/testing/$curmaj/" "$epelrepo/testing/$curmaj/"
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi

    if [ $UBUNTU_SYNC == "true" ]; then
        export GNUPGHOME=$repodir/.gpg

        # Create lockfile, sync older ubuntu repo, delete lockfile
        printf '%s: Beginning rsync of Legacy Ubuntu %s repo from %s.\n' "$(date -u +%FT%TZ)" "${ubupre^}" "$ubuntuhost" | $teelog
        touch $lockfile
        $dmirror"$ropts" $ubuntuopts1 $ubunturepo | tee -a $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Create lockfile, sync ubuntu repo, delete lockfile
        printf '%s: Beginning rsync of Ubuntu %s repo from %s.\n' "$(date -u +%FT%TZ)" "${ubucur^}" "$ubuntuhost" | $teelog
        touch $lockfile
        $dmirror"$ropts" $ubuntuopts2 $ubunturepo | tee -a $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi

    if [ $DEBIAN_SYNC == "true" ]; then
        # Create lockfile, sync older debian repo, delete lockfile
        printf '%s: Beginning rsync of Legacy Debian %s repo from %s.\n' "$(date -u +%FT%TZ)" "${debpre^}" "$debianhost" | $teelog
        touch $lockfile
        $dmirror"$ropts" $debianopts1 $debianrepo | tee -a $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Create lockfile, sync debian repo, delete lockfile
        printf '%s: Beginning rsync of Debian %s repo from %s.\n' "$(date -u +%FT%TZ)" "${debcur^}" "$debianhost" | $teelog
        touch $lockfile
        $dmirror"$ropts" $debianopts2 $debianrepo | tee -a $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi

    if [ $DEBSEC_SYNC == "true" ]; then
        # Create lockfile, sync older debian security repo, delete lockfile
        printf '%s: Beginning rsync of Legacy Debian %s Security repo from %s.\n' "$(date -u +%FT%TZ)" "${debpre^}" "$debsechost" | $teelog
        touch $lockfile
        $dmirror2 $debsecopts1 $debsecrepo &>> $progfile
        rm -f $lockfile
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Create lockfile, sync debian security repo, delete lockfile
        printf '%s: Beginning rsync of Debian %s Security repo from %s.\n' "$(date -u +%FT%TZ)" "${debcur^}" "$debsechost" | $teelog
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
printf '%s: Completed synchronization of %s repositories.\n\n' "$(date -u +%FT%TZ)" "$SOFTWARE" | $teelog
exit 0
