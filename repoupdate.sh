#!/bin/bash
# shellcheck disable=SC2086
# Repository updater script for CentOS & Debian distros (upstream)
# Currently, this script can sync the following packages:
SOFTWARE='CentOS, EPEL, Debian, Ubuntu, and ClamAV'

AUTHOR='AfroThundr'
BASENAME="${0##*/}"
MODIFIED='20181029'
VERSION='1.6.5'

# Argument handler
if [[ ! -n $1 ]]; then
    printf 'No arguments specified, use -h for help.\n'
    exit 0
fi

while [[ -n $1 ]]; do
    if [[ $1 == -v ]]; then
        printf '%s: Version %s, updated %s by %s\n' \
            "$BASENAME" "$VERSION" "$MODIFIED" "$AUTHOR"
        ver=true
        shift
    elif [[ $1 == -h ]]; then
        printf 'Software repository updater script for linux distros.\n'
        printf 'Can curently sync the following repositories:\n'
        printf '%s\n\n' "$SOFTWARE"
        printf 'Usage: %s [-v] (-h | -y)\n\n' "$BASENAME"
        printf 'Options:\n'
        printf '  -h  Display help text.\n'
        printf '  -v  Emit version info.\n'
        printf '  -y  Confirm repo sync.\n'
        exit 0
    elif [[ $1 == -y ]]; then
        CONFIRM=true
        shift
    else
        printf 'Invalid argument specified, use -h for help.\n'
        exit 0
    fi
done

if [[ ! $CONFIRM == true ]]; then
    if [[ ! $ver == true ]]; then
        printf 'Confirm with -y to start the sync.\n'
        exit 10
    fi
    exit 0
fi

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
CENTARCH=x86_64
MIRROR=mirrors.mit.edu
CENTREPO=${REPODIR}/centos
CENTHOST=${MIRROR}::centos
EPELREPO=${REPODIR}/fedora-epel
EPELHOST=${MIRROR}::fedora-epel

DEBARCH=amd64
UBUNTUREPO=${REPODIR}/ubuntu
UBUNTUHOST=${MIRROR}::ubuntu
DEBIANREPO=${REPODIR}/debian
DEBIANHOST=${MIRROR}::debian

SMIRROR=security.debian.org
DEBSECREPO=${REPODIR}/debian-security
DEBSECHOST=${SMIRROR}/

CMIRROR=database.clamav.net
CLAMREPO=${REPODIR}/clamav

ROPTS="-hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file=$PROGFILE"
TEELOG="tee -a $LOGFILE $PROGFILE"

# Here we go...
printf '%s: Progress log reset.\n' "$(date -u +%FT%TZ)" > $PROGFILE
printf '%s: Started synchronization of %s repositories.\n' \
    "$(date -u +%FT%TZ)" "$SOFTWARE" | $TEELOG
printf '%s: Use tail -f %s to view progress.\n\n' \
    "$(date -u +%FT%TZ)" "$PROGFILE"

# Check if the rsync script is already running
if [[ -f $LOCKFILE ]]; then
    printf '%s: Error: Repository updates are already running.\n\n' \
        "$(date -u +%FT%TZ)" | $TEELOG
    exit 10

# Check that we can reach the public mirror
elif ! ping -c 5 $MIRROR &> /dev/null; then
    printf '%s: Error: Cannot reach the %s mirror server.\n\n' \
        "$(date -u +%FT%TZ)" "$MIRROR" | $TEELOG
    exit 20

# Check that the repository is mounted
elif ! mount | grep $REPODIR &> /dev/null; then
    printf '%s: Error: Directory %s is not mounted.\n\n' \
        "$(date -u +%FT%TZ)" "$REPODIR" | $TEELOG
    exit 30

# Everything is good, let's continue
else
    # Declare more variables (CentOS/EPEL)
    if [[ $CENTOS_SYNC == true || $EPEL_SYNC == true ]]; then
        mapfile -t allrels <<< "$(
            rsync $CENTHOST | \
            awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}' |
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

        centex=$(echo --include={os,extras,updates,centosplus,readme,os/$CENTARCH/{repodata,Packages}} --exclude={i386,"os/$CENTARCH/*"} --exclude="/*")
        epelex=$(echo --exclude={SRPMS,aarch64,i386,ppc64,ppc64le,$CENTARCH/debug})
    fi

    # Declare more variables (Debian/Ubuntu)
    if [[ $UBUNTU_SYNC == true ]]; then
        mapfile -t uburels <<< "$(
            curl -sL $MIRROR/ubuntu-releases/HEADER.html |
            awk -F '[() ]' '/<li>/ && /LTS/ {print $6}'
        )"
        ubucur=${uburels[1],}
        ubupre=${uburels[2],}

        ubuntucomps="main,restricted,universe,multiverse"
        ubunturel1="$ubupre,$ubupre-backports,$ubupre-updates,$ubupre-proposed,$ubupre-security"
        ubunturel2="$ubucur,$ubucur-backports,$ubucur-updates,$ubucur-proposed,$ubucur-security"
        ubuntuopts1="-s $ubuntucomps -d $ubunturel1 -h $MIRROR -r /ubuntu"
        ubuntuopts2="-s $ubuntucomps -d $ubunturel2 -h $MIRROR -r /ubuntu"
    fi

    if [[ $DEBIAN_SYNC == true || $DEBSEC_SYNC == true ]]; then
        mapfile -t debrels <<< "$(
            curl -sL $MIRROR/debian/README.html |
            awk -F '[<> ]' '/<dt>/ && /Debian/ {print $9}'
        )"
        debcur=${debrels[0]}
        debpre=${debrels[1]}

        debiancomps="main,contrib,non-free"
        debianrel1="$debpre,$debpre-backports,$debpre-updates,$debpre-proposed-updates"
        debianrel2="$debcur,$debcur-backports,$debcur-updates,$debcur-proposed-updates"
        debianopts1="-s $debiancomps -d $debianrel1 -h $MIRROR -r /debian"
        debianopts2="-s $debiancomps -d $debianrel2 -h $MIRROR -r /debian"

        debsecrel1="$debpre/updates"
        debsecrel2="$debcur/updates"
        debsecopts1="-s $debiancomps -d $debsecrel1 -h $SMIRROR -r /"
        debsecopts2="-s $debiancomps -d $debsecrel2 -h $SMIRROR -r /"
    fi

    if [[ $UBUNTU_SYNC == true || $DEBIAN_SYNC == true || $DEBSEC_SYNC == true ]]; then
        dmirror="debmirror -a $DEBARCH --no-source --ignore-small-errors --method=rsync --retry-rsync-packages=5 -p --rsync-options="
        dmirror2="debmirror -a $DEBARCH --no-source --ignore-small-errors --method=http --checksums -p"
    fi

    # And a few more (ClamAV)
    if [[ $CLAMAV_SYNC == true ]]; then
        clamsync="clamavmirror -a $CMIRROR -d $CLAMREPO -u root -g www-data"
    fi

    # There can be only one...
    touch "$LOCKFILE"

    if [[ $CENTOS_SYNC == true ]]; then
        # Check for older centos release directory
        if [[ ! -d $CENTREPO/$oldrel ]]; then
            mkdir -p "$CENTREPO/$oldrel"
            ln -frs "$CENTREPO/$oldrel" "$CENTREPO/$oldmaj"
        fi

        # Sync older centos repository
        printf '%s: Beginning sync of legacy CentOS %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$oldrel" "$CENTHOST" | $TEELOG
        rsync $ROPTS $centex "$CENTHOST/$oldrel/" "$CENTREPO/$oldrel/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        # Check for centos release directory
        if [[ ! -d $CENTREPO/$currel ]]; then
            mkdir -p "$CENTREPO/$currel"
            ln -frs "$CENTREPO/$currel" "$CENTREPO/$curmaj"
        fi

        # Sync current centos repository
        printf '%s: Beginning sync of current CentOS %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$currel" "$CENTHOST" | $TEELOG
        rsync $ROPTS $centex "$CENTHOST/$currel/" "$CENTREPO/$currel/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        # Continue to sync previous point releases til they're empty
        # Check for older previous centos point release placeholder
        if [[ ! -f $CENTREPO/$oprerel/readme ]]; then

            # Check for older previous centos release directory
            if [[ ! -d $CENTREPO/$oprerel ]]; then
                mkdir -p "$CENTREPO/$oprerel"
            fi

            # Sync older previous centos repository
            printf '%s: Beginning sync of legacy CentOS %s repository from %s.\n' \
                "$(date -u +%FT%TZ)" "$oprerel" "$CENTHOST" | $TEELOG
            rsync $ROPTS $centex "$CENTHOST/$oprerel/" "$CENTREPO/$oprerel/"
            printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG
        fi

        # Check for previous centos point release placeholder
        if [[ ! -f $CENTREPO/$cprerel/readme ]]; then

            # Check for previous centos release directory
            if [[ ! -d $CENTREPO/$cprerel ]]; then
                mkdir -p "$CENTREPO/$cprerel"
            fi

            # Sync current previous centos repository
            printf '%s: Beginning sync of current CentOS %s repository from %s.\n' \
                "$(date -u +%FT%TZ)" "$cprerel" "$CENTHOST" | $TEELOG
            rsync $ROPTS $centex "$CENTHOST/$cprerel/" "$CENTREPO/$cprerel/"
            printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG
        fi
    fi

    if [[ $EPEL_SYNC == true ]]; then
        # Check for older epel release directory
        if [[ ! -d $EPELREPO/$oldmaj ]]; then
            mkdir -p "$EPELREPO/$oldmaj"
        fi

        # Sync older epel repository
        printf '%s: Beginning sync of legacy EPEL %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$oldmaj" "$EPELHOST" | $TEELOG
        rsync $ROPTS $epelex "$EPELHOST/$oldmaj/" "$EPELREPO/$oldmaj/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        # Check for older epel-testing release directory
        if [[ ! -d $EPELREPO/testing/$oldmaj ]]; then
            mkdir -p "$EPELREPO/testing/$oldmaj"
        fi

        # Sync older epel-testing repository
        printf '%s: Beginning sync of legacy EPEL %s Testing repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$oldmaj" "$EPELHOST" | $TEELOG
        rsync $ROPTS $epelex "$EPELHOST/testing/$oldmaj/" "$EPELREPO/testing/$oldmaj/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        # Check for current epel release directory
        if [[ ! -d $EPELREPO/$curmaj ]]; then
            mkdir -p "$EPELREPO/$curmaj"
        fi

        # Sync current epel repository
        printf '%s: Beginning sync of current EPEL %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$curmaj" "$EPELHOST" | $TEELOG
        rsync $ROPTS $epelex "$EPELHOST/$curmaj/" "$EPELREPO/$curmaj/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        # Check for current epel-testing release directory
        if [[ ! -d $EPELREPO/testing/$curmaj ]]; then
            mkdir -p "$EPELREPO/testing/$curmaj"
        fi

        # Sync current epel-testing repository
        printf '%s: Beginning sync of current EPEL %s Testing repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$curmaj" "$EPELHOST" | $TEELOG
        rsync $ROPTS $epelex "$EPELHOST/testing/$curmaj/" "$EPELREPO/testing/$curmaj/"
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG
    fi

    if [[ $UBUNTU_SYNC == true ]]; then
        export GNUPGHOME=$REPODIR/.gpg

        # Check for ubuntu release directory
        if [[ ! -d $UBUNTUREPO ]]; then
            mkdir -p "$UBUNTUREPO"
        fi

        # Sync older ubuntu repository
        printf '%s: Beginning sync of legacy Ubuntu %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${ubupre^}" "$UBUNTUHOST" | $TEELOG
        $dmirror"$ROPTS" $ubuntuopts1 $UBUNTUREPO | tee -a $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        # Sync current ubuntu repository
        printf '%s: Beginning sync of current Ubuntu %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${ubucur^}" "$UBUNTUHOST" | $TEELOG
        $dmirror"$ROPTS" $ubuntuopts2 $UBUNTUREPO | tee -a $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        unset GNUPGHOME
    fi

    if [[ $DEBIAN_SYNC == true ]]; then
        export GNUPGHOME=$REPODIR/.gpg

        # Check for debian release directory
        if [[ ! -d $DEBIANREPO ]]; then
            mkdir -p "$DEBIANREPO"
        fi

        # Sync older debian repository
        printf '%s: Beginning sync of legacy Debian %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${debpre^}" "$DEBIANHOST" | $TEELOG
        $dmirror"$ROPTS" $debianopts1 $DEBIANREPO | tee -a $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        # Sync current debian repository
        printf '%s: Beginning sync of current Debian %s repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${debcur^}" "$DEBIANHOST" | $TEELOG
        $dmirror"$ROPTS" $debianopts2 $DEBIANREPO | tee -a $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        unset GNUPGHOME
    fi

    if [[ $DEBSEC_SYNC == true ]]; then
        export GNUPGHOME=$REPODIR/.gpg

        # Check for ubuntu release directory
        if [[ ! -d $DEBIANREPO ]]; then
            mkdir -p "$DEBIANREPO"
        fi

        # Sync older debian security repository
        printf '%s: Beginning sync of legacy Debian %s Security repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${debpre^}" "$DEBSECHOST" | $TEELOG
        $dmirror2 $debsecopts1 $DEBSECREPO &>> $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        # Sync current debian security repository
        printf '%s: Beginning sync of current Debian %s Security repository from %s.\n' \
            "$(date -u +%FT%TZ)" "${debcur^}" "$DEBSECHOST" | $TEELOG
        $dmirror2 $debsecopts2 $DEBSECREPO &>> $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG

        unset GNUPGHOME
    fi

    if [[ $CLAMAV_SYNC == true ]]; then
        # Check for clamav release directory
        if [[ ! -d $CLAMREPO ]]; then
            mkdir -p "$CLAMREPO"
        fi

        # Sync clamav repository
        printf '%s: Beginning sync of ClamAV repository from %s.\n' \
            "$(date -u +%FT%TZ)" "$CMIRROR" | $TEELOG
        $clamsync &>> $PROGFILE
        printf '%s: Done.\n\n' "$(date -u +%FT%TZ)" | $TEELOG
    fi

    # Clear the lockfile
    rm -f "$LOCKFILE"
fi

# Now we're done
printf '%s: Completed synchronization of %s repositories.\n\n' \
    "$(date -u +%FT%TZ)" "$SOFTWARE" | $TEELOG
exit 0