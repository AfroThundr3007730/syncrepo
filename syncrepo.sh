#!/bin/bash
## shellcheck disable=SC2086
# Repository sync script for CentOS & Debian distros
# This script can sync the repos listed in $SOFTWARE

# Gotta keep the namespace clean
set_globals () {
    AUTHOR='AfroThundr'
    BASENAME="${0##*/}"
    MODIFIED='20181029'
    VERSION='1.7.0-rc1'

    SOFTWARE='CentOS, EPEL, Debian, Ubuntu, and ClamAV'

    # Global config variables (modify as necessary)
    UPSTREAM=true
    CENTOS_SYNC=true
    EPEL_SYNC=true
    DEBIAN_SYNC=true
    DEBSEC_SYNC=true
    UBUNTU_SYNC=true
    CLAMAV_SYNC=true
    LOCAL_SYNC=true

    REPODIR=/srv/repository
    LOCKFILE=/var/lock/subsys/reposync
    LOGFILE=/var/log/reposync.log
    PROGFILE=/var/log/reposync_progress.log

    # More internal config variables
    MIRROR=mirrors.mit.edu
    UMIRROR=mirror-us.lab.local
    CENTARCH=x86_64
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

    LOCALREPO=${REPODIR}/local
    LOCALHOST=${MIRROR}::local

    ROPTS="-hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file=$PROGFILE"
    TEELOG="tee -a $LOGFILE $PROGFILE"
}

# Parse command line options
argument_handler () {
    if [[ ! -n $1 ]]; then
        say -h 'No arguments specified, use -h for help.'
        exit 0
    fi

    while [[ -n $1 ]]; do
        if [[ $1 == -v ]]; then
            say -h '%s: Version %s, updated %s by %s' \
                "$BASENAME" "$VERSION" "$MODIFIED" "$AUTHOR"
            ver=true
            shift
        elif [[ $1 == -h ]]; then
            say -h 'Software repository updater script for linux distros.'
            say -h 'Can curently sync the following repositories:'
            say -h '%s\n' "$SOFTWARE"
            say -h 'Usage: %s [-v] (-h | -y)\n' "$BASENAME"
            say -h 'Options:'
            say -h '  -h  Display help text.'
            say -h '  -v  Emit version info.'
            say -h '  -y  Confirm repo sync.'
            # Need to add options
            # -l|--log-file
            # -p|--prog-log
            # -u|--upstream
            # --centos-sync
            # --epel-sync
            # --ubuntu-sync
            # --debian-sync
            # --debsec-sync
            # --clamav-sync
            # --local-sync
            exit 0
        elif [[ $1 == -y ]]; then
            CONFIRM=true
            shift
        else
            say -h 'Invalid argument specified, use -h for help.'
            exit 0
        fi
    done

    if [[ ! $CONFIRM == true ]]; then
        if [[ ! $ver == true ]]; then
            say -h 'Confirm with -y to start the sync.'
            exit 10
        fi
        exit 0
    fi
}

# Log message and print to stdout
# shellcheck disable=SC2059
say () {
    if [[ $1 == -h ]]; then
        shift; local s=$1; shift
        tput setaf 2; printf "$s\\n" "$@"
    else
        if [[ $LOGFILE == no && $PROGFILE == no ]] || [[ $1 == -n ]]; then
            [[ $1 == -n ]] && shift
        else
            local log=true
        fi
        [[ $1 == -t ]] && (echo > $PROGFILE; shift)
        if [[ $1 == info || $1 == warn || $1 == err ]]; then
            [[ $1 == info ]] && tput setaf 4
            [[ $1 == warn ]] && tput setaf 3
            [[ $1 == err ]] && tput setaf 1
            local l=${1^^}; shift
            local s="$l: $1"; shift
        else
            local s="$1"; shift
        fi
        if [[ $log == true ]]; then
            printf "%s: $s\\n" "$(date -u +%FT%TZ)" "$@" | $TEELOG
        else
            printf "%s: $s\\n" "$(date -u +%FT%TZ)" "$@"
        fi
    fi
    tput setaf 7 # For CentOS
}

# Construct the sync environment
build_vars () {
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

    return 0
}

centos_sync () {
    # Check for older centos release directory
    if [[ ! -d $CENTREPO/$oldrel ]]; then
        mkdir -p "$CENTREPO/$oldrel"
        ln -frs "$CENTREPO/$oldrel" "$CENTREPO/$oldmaj"
    fi

    # Sync older centos repository
    say 'Beginning sync of legacy CentOS %s repository from %s.' \
        "$oldrel" "$CENTHOST"
    rsync $ROPTS $centex "$CENTHOST/$oldrel/" "$CENTREPO/$oldrel/"
    say 'Done.\n'

    # Check for centos release directory
    if [[ ! -d $CENTREPO/$currel ]]; then
        mkdir -p "$CENTREPO/$currel"
        ln -frs "$CENTREPO/$currel" "$CENTREPO/$curmaj"
    fi

    # Sync current centos repository
    say 'Beginning sync of current CentOS %s repository from %s.' \
        "$currel" "$CENTHOST"
    rsync $ROPTS $centex "$CENTHOST/$currel/" "$CENTREPO/$currel/"
    say 'Done.\n'

    # Continue to sync previous point releases til they're empty
    # Check for older previous centos point release placeholder
    if [[ ! -f $CENTREPO/$oprerel/readme ]]; then

        # Check for older previous centos release directory
        if [[ ! -d $CENTREPO/$oprerel ]]; then
            mkdir -p "$CENTREPO/$oprerel"
        fi

        # Sync older previous centos repository
        say 'Beginning sync of legacy CentOS %s repository from %s.' \
            "$oprerel" "$CENTHOST"
        rsync $ROPTS $centex "$CENTHOST/$oprerel/" "$CENTREPO/$oprerel/"
        say 'Done.\n'
    fi

    # Check for previous centos point release placeholder
    if [[ ! -f $CENTREPO/$cprerel/readme ]]; then

        # Check for previous centos release directory
        if [[ ! -d $CENTREPO/$cprerel ]]; then
            mkdir -p "$CENTREPO/$cprerel"
        fi

        # Sync current previous centos repository
        say 'Beginning sync of current CentOS %s repository from %s.' \
            "$cprerel" "$CENTHOST"
        rsync $ROPTS $centex "$CENTHOST/$cprerel/" "$CENTREPO/$cprerel/"
        say 'Done.\n'
    fi

    return 0
}

epel_sync () {
    # Check for older epel release directory
    if [[ ! -d $EPELREPO/$oldmaj ]]; then
        mkdir -p "$EPELREPO/$oldmaj"
    fi

    # Sync older epel repository
    say 'Beginning sync of legacy EPEL %s repository from %s.' \
        "$oldmaj" "$EPELHOST"
    rsync $ROPTS $epelex "$EPELHOST/$oldmaj/" "$EPELREPO/$oldmaj/"
    say 'Done.\n'

    # Check for older epel-testing release directory
    if [[ ! -d $EPELREPO/testing/$oldmaj ]]; then
        mkdir -p "$EPELREPO/testing/$oldmaj"
    fi

    # Sync older epel-testing repository
    say 'Beginning sync of legacy EPEL %s Testing repository from %s.' \
        "$oldmaj" "$EPELHOST"
    rsync $ROPTS $epelex "$EPELHOST/testing/$oldmaj/" "$EPELREPO/testing/$oldmaj/"
    say 'Done.\n'

    # Check for current epel release directory
    if [[ ! -d $EPELREPO/$curmaj ]]; then
        mkdir -p "$EPELREPO/$curmaj"
    fi

    # Sync current epel repository
    say 'Beginning sync of current EPEL %s repository from %s.' \
        "$curmaj" "$EPELHOST"
    rsync $ROPTS $epelex "$EPELHOST/$curmaj/" "$EPELREPO/$curmaj/"
    say 'Done.\n'

    # Check for current epel-testing release directory
    if [[ ! -d $EPELREPO/testing/$curmaj ]]; then
        mkdir -p "$EPELREPO/testing/$curmaj"
    fi

    # Sync current epel-testing repository
    say 'Beginning sync of current EPEL %s Testing repository from %s.' \
        "$curmaj" "$EPELHOST"
    rsync $ROPTS $epelex "$EPELHOST/testing/$curmaj/" "$EPELREPO/testing/$curmaj/"
    say 'Done.\n'

    return 0
}

ubuntu_sync () {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for ubuntu release directory
    if [[ ! -d $UBUNTUREPO ]]; then
        mkdir -p "$UBUNTUREPO"
    fi

    # Sync older ubuntu repository
    say 'Beginning sync of legacy Ubuntu %s repository from %s.' \
        "${ubupre^}" "$UBUNTUHOST"
    $dmirror"$ROPTS" $ubuntuopts1 $UBUNTUREPO | tee -a $PROGFILE
    say 'Done.\n'

    # Sync current ubuntu repository
    say 'Beginning sync of current Ubuntu %s repository from %s.' \
        "${ubucur^}" "$UBUNTUHOST"
    $dmirror"$ROPTS" $ubuntuopts2 $UBUNTUREPO | tee -a $PROGFILE
    say 'Done.\n'

    unset GNUPGHOME
    return 0
}

debian_sync () {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for debian release directory
    if [[ ! -d $DEBIANREPO ]]; then
        mkdir -p "$DEBIANREPO"
    fi

    # Sync older debian repository
    say 'Beginning sync of legacy Debian %s repository from %s.' \
        "${debpre^}" "$DEBIANHOST"
    $dmirror"$ROPTS" $debianopts1 $DEBIANREPO | tee -a $PROGFILE
    say 'Done.\n'

    # Sync current debian repository
    say 'Beginning sync of current Debian %s repository from %s.' \
        "${debcur^}" "$DEBIANHOST"
    $dmirror"$ROPTS" $debianopts2 $DEBIANREPO | tee -a $PROGFILE
    say 'Done.\n'

    unset GNUPGHOME
    return 0
}

debsec_sync () {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for ubuntu release directory
    if [[ ! -d $DEBIANREPO ]]; then
        mkdir -p "$DEBIANREPO"
    fi

    # Sync older debian security repository
    say 'Beginning sync of legacy Debian %s Security repository from %s.' \
        "${debpre^}" "$DEBSECHOST"
    $dmirror2 $debsecopts1 $DEBSECREPO &>> $PROGFILE
    say 'Done.\n'

    # Sync current debian security repository
    say 'Beginning sync of current Debian %s Security repository from %s.' \
        "${debcur^}" "$DEBSECHOST"
    $dmirror2 $debsecopts2 $DEBSECREPO &>> $PROGFILE
    say 'Done.\n'

    unset GNUPGHOME
    return 0
}

clamav_sync () {
    # Check for clamav release directory
    if [[ ! -d $CLAMREPO ]]; then
        mkdir -p "$CLAMREPO"
    fi

    # Sync clamav repository
    say 'Beginning sync of ClamAV repository from %s.' "$CMIRROR"
    $clamsync &>> $PROGFILE
    say 'Done.\n'

    return 0
}

local_sync () {
    # Check for local repository directory
    if [[ ! -d $LOCALREPO ]]; then
        mkdir -p "$LOCALREPO"
    fi

    # Sync local repository
    say 'Beginning sync of local repository from %s.' "$MIRROR"
    rsync $ROPTS $centex "$LOCALHOST/" "$LOCALREPO/"
    say 'Done.\n'

    return 0
}

# Where the magic happens
main () {
    # Process arguments
    argument_handler "$@"

    # Set Globals
    set_globals

    # Here we go...
    say -t 'Progress log reset.'
    say 'Started synchronization of %s repositories.' "$SOFTWARE"
    say 'Use tail -f %s to view progress.' "$PROGFILE"

    # Check if the rsync script is already running
    if [[ -f $LOCKFILE ]]; then
        say err 'Detected lockfile: %s' "$LOCKFILE"
        say err 'Repository updates are already running.'
        exit 10

    # Check that we can reach the public mirror
    elif ! ping -c 5 $MIRROR &> /dev/null; then
        say err 'Cannot reach the %s mirror server.' "$MIRROR"
        exit 20

    # Check that the repository is mounted
    elif ! mount | grep $REPODIR &> /dev/null; then
        say err 'Directory %s is not mounted.' "$REPODIR"
        exit 30

    # Everything is good, let's continue
    else
        # There can be only one...
        touch "$LOCKFILE"

        # Generate variables
        build_vars

        # Are we upstream?
        [[ $UPSTREAM == false ]] && MIRROR="$UMIRROR"

        # Sync CentOS repo
        [[ $CENTOS_SYNC == true ]] && centos_sync

        # Sync EPEL repo
        [[ $EPEL_SYNC == true ]] && epel_sync

        # Sync Ubuntu repo
        [[ $UBUNTU_SYNC == true ]] && ubuntu_sync

        # Sync Debian repo
        [[ $DEBIAN_SYNC == true ]] && debian_sync

        # Sync Debian Security repo
        [[ $DEBSEC_SYNC == true ]] && debsec_sync

        # Sync Clamav reop
        [[ $CLAMAV_SYNC == true ]] && clamav_sync

        # Sync Local repo
        [[ $LOCAL_SYNC == true ]] && local_sync

        # Clear the lockfile
        rm -f "$LOCKFILE"
    fi

    # Now we're done
    say 'Completed synchronization of %s repositories.\n' "$SOFTWARE"
    exit 0
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"