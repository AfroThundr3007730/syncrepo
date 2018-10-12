#!/bin/bash
# Repository updater script for CentOS & Debian distros (upstream)
# Currently, this script can sync the following packages:
SOFTWARE='CentOS, EPEL, Debian, Ubuntu, and ClamAV'

AUTHOR='AfroThundr'
UPDATED='20181012'
VERSION='1.6.3'

# TODO: Document all the things, implement best practices.

# Argument handler
# if [[ $# -eq 0 ]]; then
#     printf 'No arguments specified, use -h for help.\n'
#     exit 0
# fi

for i in "$@"; do
    if [[ $i == -v ]]; then
        printf '%s: Version %s, updated %s by %s\n' \
            "${0##*/}" "$VERSION" "$UPDATED" "$AUTHOR"
        # ver=true
        shift
    elif [[ $i == -h ]]; then
        printf 'Software repository updater script for linux distros.\n'
        printf 'Can curently sync the following repositories:\n'
        printf '%s\n\n' "$SOFTWARE"
        printf 'Usage: %s [-v] (-h | -y)\n\n' "${0##*/}"
        printf 'Options:\n'
        printf '  -h  Display help text.\n'
        printf '  -v  Emit version info.\n'
        printf '  -y  Confirm repo sync.\n'
        exit 0
    # elif [[ $i == -y ]]; then
    #     CONFIRM=true
    #     shift
    else
        printf 'Invalid argument specified, use -h for help.\n'
        exit 0
    fi
done

# if [[ ! $CONFIRM == true && ! $ver == true ]]; then
#     printf 'Confirm with -y to start the sync.\n'
#     exit 10
# else
#     exit 0
# fi

# Declare global config variables (modify as necessary)
CENTOS_SYNC=true
EPEL_SYNC=true
DEBIAN_SYNC=true
DEBSEC_SYNC=true
UBUNTU_SYNC=true
CLAMAV_SYNC=true

REPODIR=/srv/repository
LOCKFILE=/var/lock/subsys/reposync
LOGFILE=/var/log/reposync.log
PROGFILE=/var/log/reposync_progress.log

# More internal config variables
centarch=x86_64
mirror=mirrors.mit.edu
centrepo=$REPODIR/centos
epelrepo=$REPODIR/fedora-epel
centhost=$mirror::centos
epelhost=$mirror::fedora-epel

debarch=amd64
smirror=security.debian.org
ubunturepo=$REPODIR/ubuntu
debianrepo=$REPODIR/debian
debsecrepo=$REPODIR/debian-security
ubuntuhost=$mirror::ubuntu
debianhost=$mirror::debian
debsechost=$smirror/

ropts="-hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file=$PROGFILE"
teelog="tee -a $LOGFILE $PROGFILE"

# Declare more variables (CentOS/EPEL)
if [[ $CENTOS_SYNC == true || $EPEL_SYNC == true ]]; then
    mapfile -t allrels <<< "$(
        rsync $centhost | \
        awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}' | \
        sort -V
    )"
    mapfile -t oldrels <<< "$(
        for i in "${allrels[@]}"; do
            if [[ ${i%%.*} -eq "(${allrels[-1]%%.*} - 1)" ]]; then
                echo "$i";
            fi;
        done
    )"
    currel=${allrels[-1]}
    curmaj=${currel%%.*}
    cprerel=${allrels[-2]}
    oldrel=${oldrels[-1]}
    oldmaj=${oldrel%%.*}
    oprerel=${oldrels[-2]}

    centex=$(echo --include={os,extras,updates,centosplus,readme,os/$centarch/{repodata,Packages}} --exclude={i386,"os/$centarch/*"} --exclude="/*")
    epelex=$(echo --exclude={SRPMS,aarch64,i386,ppc64,ppc64le,$centarch/debug})
fi

# Declare more variables (Debian/Ubuntu)
if [[ $UBUNTU_SYNC == true ]]; then
    mapfile -t uburels <<< "$(
        curl -s http://releases.ubuntu.com | \
        awk -F '[() ]' '/<li>/ && /LTS/ {print $6}'
    )"
    ubucur=${uburels[1],}
    ubupre=${uburels[2],}

    ubuntucomps="main,restricted,universe,multiverse"
    ubunturel1="$ubupre,$ubupre-backports,$ubupre-updates,$ubupre-proposed,$ubupre-security"
    ubunturel2="$ubucur,$ubucur-backports,$ubucur-updates,$ubucur-proposed,$ubucur-security"
    ubuntuopts1="-s $ubuntucomps -d $ubunturel1 -h $mirror -r /ubuntu"
    ubuntuopts2="-s $ubuntucomps -d $ubunturel2 -h $mirror -r /ubuntu"
fi

if [[ $DEBIAN_SYNC == true || $DEBSEC_SYNC == true ]]; then
    mapfile -t debrels <<< "$(
        curl -s https://www.debian.org/releases/ | \
        awk -F '[<>]' '/<li>/ && /<q>/ {print $7}'
    )"
    debcur=${debrels[0]}
    debpre=${debrels[1]}

    debiancomps="main,contrib,non-free"
    debianrel1="$debpre,$debpre-backports,$debpre-updates,$debpre-proposed-updates"
    debianrel2="$debcur,$debcur-backports,$debcur-updates,$debcur-proposed-updates"
    debianopts1="-s $debiancomps -d $debianrel1 -h $mirror -r /debian"
    debianopts2="-s $debiancomps -d $debianrel2 -h $mirror -r /debian"

    debsecrel1="$debpre/updates"
    debsecrel2="$debcur/updates"
    debsecopts1="-s $debiancomps -d $debsecrel1 -h $smirror -r /"
    debsecopts2="-s $debiancomps -d $debsecrel2 -h $smirror -r /"
fi

if [[ $UBUNTU_SYNC == true || $DEBIAN_SYNC == true || $DEBSEC_SYNC == true ]]; then
    dmirror="debmirror -a $debarch --no-source --ignore-small-errors --method=rsync --retry-rsync-packages=5 -p --rsync-options="
    dmirror2="debmirror -a $debarch --no-source --ignore-small-errors --method=http --checksums -p"
fi

# And a few more (ClamAV)
if [[ $CLAMAV_SYNC == true ]]; then
    cmirror=database.clamav.net
    clamrepo=$REPODIR/clamav
    clamsync="clamavmirror -a $cmirror -d $clamrepo -u root -g www-data"
fi

# Here we go...
printf '%s: Progress log reset.\n' "$(date -u +%FT%TZ)" > $PROGFILE
printf '%s: Started synchronization of %s repositories.\n' \
    "$(date -u +%FT%TZ)" "$SOFTWARE" | $teelog
printf '%s: Use tail -f %s to view progress.\n\n' \
    "$(date -u +%FT%TZ)" "$PROGFILE"

# Check if the rsync script is already running
if [[ -f $LOCKFILE ]]; then
    printf '%s: Error: Repository updates are already running.\n\n' \
        "$(date -u +%FT%TZ)" | $teelog
    exit 10

# Check that we can reach the public mirror
elif ! ping -c 5 $mirror &> /dev/null; then
    printf '%s: Error: Cannot reach the %s mirror server.\n\n' \
        "$(date -u +%FT%TZ)" "$mirror" | $teelog
    exit 20

# Check that the repository is mounted
elif ! mount | grep $REPODIR &> /dev/null; then
    printf '%s: Error: Directory %s is not mounted.\n\n' \
        "$(date -u +%FT%TZ)" "$REPODIR" | $teelog
    exit 30

else
    # There can be only one...
    touch $LOCKFILE

    if [[ $CENTOS_SYNC == true ]]; then
        # Check for older centos release directory
        if [[ ! -d $centrepo/$oldrel ]]; then
            mkdir -p "$centrepo/$oldrel"
            ln -frs "$centrepo/$oldrel" "$centrepo/$oldmaj"
        fi

        # Sync older centos repository
        printf '%s: Beginning sync of legacy CentOS %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$oldrel" "$centhost" | $teelog
        rsync $ropts $centex "$centhost/$oldrel/" "$centrepo/$oldrel/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Check for centos release directory
        if [[ ! -d $centrepo/$currel ]]; then
            mkdir -p "$centrepo/$currel"
            ln -frs "$centrepo/$currel" "$centrepo/$curmaj"
        fi

        # Sync current centos repository
        printf '%s: Beginning sync of current CentOS %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$currel" "$centhost" | $teelog
        rsync $ropts $centex "$centhost/$currel/" "$centrepo/$currel/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Continue to sync previous point releases til they're empty
        # Check for older previous centos point release placeholder
        if [[ ! -f $centrepo/$oprerel/readme ]]; then

            # Check for older previous centos release directory
            if [[ ! -d $centrepo/$oprerel ]]; then
                mkdir -p "$centrepo/$oprerel"
            fi

            # Sync older previous centos repository
            printf '%s: Beginning sync of legacy CentOS %s repository from %s.\n' \
                "$(date -u +%FT%TZ)" "$oprerel" "$centhost" | $teelog
            rsync $ropts $centex "$centhost/$oprerel/" "$centrepo/$oprerel/"
            printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
        fi

        # Check for previous centos point release placeholder
        if [[ ! -f $centrepo/$cprerel/readme ]]; then

            # Check for previous centos release directory
            if [[ ! -d $centrepo/$cprerel ]]; then
                mkdir -p "$centrepo/$cprerel"
            fi

            # Sync current previous centos repository
            printf '%s: Beginning sync of current CentOS %s repository from %s.\n' \
                "$(date -u +%FT%TZ)" "$cprerel" "$centhost" | $teelog
            rsync $ropts $centex "$centhost/$cprerel/" "$centrepo/$cprerel/"
            printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
        fi
    fi

    if [[ $EPEL_SYNC == true ]]; then
        # Check for older epel release directory
        if [[ ! -d $epelrepo/$oldmaj ]]; then
            mkdir -p "$epelrepo/$oldmaj"
        fi

        # Sync older epel repository
        printf '%s: Beginning sync of legacy EPEL %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$oldmaj" "$epelhost" | $teelog
        rsync $ropts $epelex "$epelhost/$oldmaj/" "$epelrepo/$oldmaj/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Check for older epel-testing release directory
        if [[ ! -d $epelrepo/testing/$oldmaj ]]; then
            mkdir -p "$epelrepo/testing/$oldmaj"
        fi

        # Sync older epel-testing repository
        printf '%s: Beginning sync of legacy EPEL %s Testing repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$oldmaj" "$epelhost" | $teelog
        rsync $ropts $epelex "$epelhost/testing/$oldmaj/" "$epelrepo/testing/$oldmaj/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Check for current epel release directory
        if [[ ! -d $epelrepo/$curmaj ]]; then
            mkdir -p "$epelrepo/$curmaj"
        fi

        # Sync current epel repository
        printf '%s: Beginning sync of current EPEL %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$curmaj" "$epelhost" | $teelog
        rsync $ropts $epelex "$epelhost/$curmaj/" "$epelrepo/$curmaj/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Check for current epel-testing release directory
        if [[ ! -d $epelrepo/testing/$curmaj ]]; then
            mkdir -p "$epelrepo/testing/$curmaj"
        fi

        # Sync current epel-testing repository
        printf '%s: Beginning sync of current EPEL %s Testing repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$curmaj" "$epelhost" | $teelog
        rsync $ropts $epelex "$epelhost/testing/$curmaj/" "$epelrepo/testing/$curmaj/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi

    if [[ $UBUNTU_SYNC == true ]]; then
        export GNUPGHOME=$REPODIR/.gpg

        # Check for ubuntu release directory
        if [[ ! -d $ubunturepo ]]; then
            mkdir -p "$ubunturepo"
        fi

        # Sync older ubuntu repository
        printf '%s: Beginning sync of legacy Ubuntu %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${ubupre^}" "$ubuntuhost" | $teelog
        $dmirror"$ropts" $ubuntuopts1 $ubunturepo | tee -a $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Sync current ubuntu repository
        printf '%s: Beginning sync of current Ubuntu %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${ubucur^}" "$ubuntuhost" | $teelog
        $dmirror"$ropts" $ubuntuopts2 $ubunturepo | tee -a $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        unset GNUPGHOME
    fi

    if [[ $DEBIAN_SYNC == true ]]; then
        export GNUPGHOME=$REPODIR/.gpg

        # Check for debian release directory
        if [[ ! -d $debianrepo ]]; then
            mkdir -p "$debianrepo"
        fi

        # Sync older debian repository
        printf '%s: Beginning sync of legacy Debian %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${debpre^}" "$debianhost" | $teelog
        $dmirror"$ropts" $debianopts1 $debianrepo | tee -a $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Sync current debian repository
        printf '%s: Beginning sync of current Debian %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${debcur^}" "$debianhost" | $teelog
        $dmirror"$ropts" $debianopts2 $debianrepo | tee -a $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        unset GNUPGHOME
    fi

    if [[ $DEBSEC_SYNC == true ]]; then
        export GNUPGHOME=$REPODIR/.gpg

        # Check for ubuntu release directory
        if [[ ! -d $debianrepo ]]; then
            mkdir -p "$debianrepo"
        fi

        # Sync older debian security repository
        printf '%s: Beginning sync of legacy Debian %s Security repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${debpre^}" "$debsechost" | $teelog
        $dmirror2 $debsecopts1 $debsecrepo &>> $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        # Sync current debian security repository
        printf '%s: Beginning sync of current Debian %s Security repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${debcur^}" "$debsechost" | $teelog
        $dmirror2 $debsecopts2 $debsecrepo &>> $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog

        unset GNUPGHOME
    fi

    if [[ $CLAMAV_SYNC == true ]]; then
        # Check for clamav release directory
        if [[ ! -d $clamrepo ]]; then
            mkdir -p "$clamrepo"
        fi

        # Sync clamav repository
        printf '%s: Beginning sync of ClamAV repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$cmirror" | $teelog
        $clamsync &>> $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $teelog
    fi

    # Clear the lockfile
    rm -f $LOCKFILE
fi

# Now we're done
printf '%s: Completed synchronization of %s repositories.\n\n' \
    "$(date -u +%FT%TZ)" "$SOFTWARE" | $teelog
exit 0