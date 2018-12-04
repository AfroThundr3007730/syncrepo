#!/bin/bash
## shellcheck disable=SC2086
# Repository sync script for CentOS & Debian distros
# This script can sync the repos listed in $SOFTWARE

# Gotta keep the namespace clean
set_globals() {
    AUTHOR='AfroThundr'
    BASENAME="${0##*/}"
    MODIFIED='20181203'
    VERSION='1.7.0-rc3'

    SOFTWARE='CentOS, EPEL, Debian, Ubuntu, Security Onion, and ClamAV'

    # Global config variables (modify as necessary)
    UPSTREAM=true
    CENTOS_SYNC=true
    EPEL_SYNC=true
    DEBIAN_SYNC=true
    DEBSEC_SYNC=true
    UBUNTU_SYNC=true
    CLAMAV_SYNC=true
    SONION_SYNC=true
    LOCAL_SYNC=true

    REPODIR=/srv/repository
    LOCKFILE=/var/lock/subsys/syncrepo
    LOGFILE=/var/log/syncrepo.log
    PROGFILE=/var/log/syncrepo_progress.log

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

    SOMIRROR=ppa.launchpad.net
    SONIONREPO=${REPODIR}/securityonion
    SONIONHOST=${SOMIRROR}/securityonion

    CMIRROR=database.clamav.net
    CLAMREPO=${REPODIR}/clamav

    ROPTS="-hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file=$PROGFILE"
    TEELOG="tee -a $LOGFILE $PROGFILE"
}

# Parse command line options
argument_handler() {
    if [[ ! -n $1 ]]; then
        say -h 'No arguments specified, use -h for help.'
        exit 10
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
            # -s|--sync (array)
            # --centos-sync
            # --epel-sync
            # --ubuntu-sync
            # --debian-sync
            # --debsec-sync
            # --sonion-sync
            # --clamav-sync
            # --local-sync
            exit 0
        elif [[ $1 == -y ]]; then
            CONFIRM=true
            shift
        else
            say -h 'Invalid argument specified, use -h for help.'
            exit 10
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
say() {
    [[ -n $TERM ]] && export TERM=xterm
    if [[ $1 == -h ]]; then
        shift; local s=$1; shift
        tput setaf 2; printf "$s\\n" "$@"
    else
        if [[ $LOGFILE == no && $PROGFILE == no ]] || [[ $1 == -n ]]; then
            [[ $1 == -n ]] && shift
        else
            local log=true
        fi
        [[ $1 == -t ]] && { echo > $PROGFILE; shift; }
        if [[ $1 == info || $1 == warn || $1 == err ]]; then
            [[ $1 == info ]] && tput setaf 4
            [[ $1 == warn ]] && tput setaf 3
            [[ $1 == err  ]] && tput setaf 1
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
build_vars() {
    # Declare more variables (CentOS/EPEL)
    if [[ $CENTOS_SYNC == true || $EPEL_SYNC == true ]]; then
        mapfile -t allrels <<< "$(
            rsync $CENTHOST |
            awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}' |
            sort -V
        )"
        mapfile -t oldrels <<< "$(
            for i in "${allrels[@]}"; do
                [[ ${i%%.*} -eq "(${allrels[-1]%%.*} - 1)" ]] && echo "$i"
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
    if [[ $UBUNTU_SYNC == true || $SONION_SYNC == true ]]; then
        mapfile -t uburels <<< "$(
            curl -sL $MIRROR/ubuntu-releases/HEADER.html |
            awk -F '[() ]' '/<li>/ && /LTS/ {print $6}'
        )"
        ubucur=${uburels[1],}
        ubupre=${uburels[2],}

        ubuntucomps="main,restricted,universe,multiverse"
        ubunturel1="$ubupre,$ubupre-backports,$ubupre-updates,$ubupre-proposed,$ubupre-security"
        ubunturel2="$ubucur,$ubucur-backports,$ubucur-updates,$ubucur-proposed,$ubucur-security"
        ubuntuopts="-s $ubuntucomps -d $ubunturel1 -d $ubunturel2 -h $MIRROR -r /ubuntu"

        sonionopts="s main -d $ubupre -d $ubucur -h $SOMIRROR --rsync-extras=none -r /securityonion/stable/ubuntu"
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
        debianopts="-s $debiancomps -d $debianrel1 -d $debianrel2 -h $MIRROR -r /debian"

        debsecrel1="$debpre/updates"
        debsecrel2="$debcur/updates"
        debsecopts="-s $debiancomps -d $debsecrel1 -d $debsecrel2 -h $SMIRROR -r /"
    fi

    if [[ $UBUNTU_SYNC == true || $DEBIAN_SYNC == true || $DEBSEC_SYNC == true || $SONION_SYNC == true ]]; then
        dmirror="debmirror -a $DEBARCH --no-source --ignore-small-errors --method=rsync --retry-rsync-packages=5 -p --rsync-options="
        dmirror2="debmirror -a $DEBARCH --no-source --ignore-small-errors --method=http --checksums -p"
    fi

    # And a few more (ClamAV)
    if [[ $CLAMAV_SYNC == true ]]; then
        clamsync="clamavmirror -a $CMIRROR -d $CLAMREPO -u root -g www-data"
    fi

    return 0
}

centos_sync() {
    for repo in $oldrel $currel; do
        # Check for centos release directory
        [[ -d $CENTREPO/$repo ]] || mkdir -p "$CENTREPO/$repo"

        # Sync current centos repository
        say 'Beginning sync of CentOS %s repository from %s.' \
            "$repo" "$CENTHOST"
        rsync $ROPTS $centex "$CENTHOST/$repo/" "$CENTREPO/$repo/"
        say 'Done.\n'
    done

    # Create the symlink, or move, if necessary
    [[ -L ${repo%%.*} && $(readlink "${repo%%.*}") == "$repo" ]] ||
        ln -frs "$CENTREPO/$repo" "$CENTREPO/${repo%%.*}"

    # Continue to sync previous point releases til they're empty
    for repo in $oprerel $cprerel; do
        # Check for release directory
        [[ -d $CENTREPO/$repo ]] || mkdir -p "$CENTREPO/$repo"

        # Check for point release placeholder
        [[ -f $CENTREPO/$repo/readme ]] || {
            # Sync previous centos repository
            say 'Beginning sync of CentOS %s repository from %s.' \
                "$repo" "$CENTHOST"
            rsync $ROPTS $centex "$CENTHOST/$repo/" "$CENTREPO/$repo/"
            say 'Done.\n'
        }
    done

    return 0
}

epel_sync() {
    for repo in $oldmaj $curmaj testing/{$oldmaj,$curmaj}; do
        # Check for epel release directory
        [[ -d $EPELREPO/$repo ]] || mkdir -p "$EPELREPO/$repo"

        # Sync epel repository
        say 'Beginning sync of EPEL %s repository from %s.' "$repo" "$EPELHOST"
        rsync $ROPTS $epelex "$EPELHOST/$repo/" "$EPELREPO/$repo/"
        say 'Done.\n'
    done

    return 0
}

ubuntu_sync() {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for ubuntu release directory
    [[ -d $UBUNTUREPO ]] || mkdir -p "$UBUNTUREPO"

    # Sync ubuntu repository
    say 'Beginning sync of Ubuntu %s and %s repositories from %s.' \
        "${ubupre^}" "${ubucur^}" "$UBUNTUHOST"
    $dmirror2 $ubuntuopts $UBUNTUREPO &>> $PROGFILE
    say 'Done.\n'

    unset GNUPGHOME
    return 0
}

debian_sync() {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for debian release directory
    [[ -d $DEBIANREPO ]] || mkdir -p "$DEBIANREPO"

    # Sync debian repository
    say 'Beginning sync of Debian %s and %s repositories from %s.' \
        "${debpre^}" "${debcur^}" "$DEBIANHOST"
    $dmirror2 $debianopts $DEBIANREPO &>> $PROGFILE
    say 'Done.\n'

    unset GNUPGHOME
    return 0
}

debsec_sync() {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for debian security release directory
    [[ -d $DEBSECREPO ]] || mkdir -p "$DEBSECREPO"

    # Sync debian security repository
    say 'Beginning sync of Debian %s and %s Security repositories from %s.' \
        "${debpre^}" "${debcur^}" "$DEBSECHOST"
    $dmirror2 $debsecopts $DEBSECREPO &>> $PROGFILE
    say 'Done.\n'

    unset GNUPGHOME
    return 0
}

sonion_sync() {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for ubuntu release directory
    [[ -d $SONIONREPO ]] || mkdir -p "$SONIONREPO"

    # Sync security onion repository
    say 'Beginning sync of Security Onion %s and %s repositories from %s.' \
        "${ubupre^}" "${ubucur^}" "$SONIONHOST"
    $dmirror2 $sonionopts $SONIONREPO &>> $PROGFILE
    say 'Done.\n'

    unset GNUPGHOME
    return 0
}

clamav_sync() {
    # Check for clamav release directory
    [[ -d $CLAMREPO ]] || mkdir -p "$CLAMREPO"

    # Sync clamav repository
    say 'Beginning sync of ClamAV repository from %s.' "$CMIRROR"
    $clamsync &>> $PROGFILE
    say 'Done.\n'

    return 0
}

ds_sync() {
    say 'Configured as downstream, so mirroring local upstream.'

    [[ -n $UMIRROR ]] || {
        say err 'UMIRROR is empty or not set.'; exit 14; }

    # Build array of repos to sync downstream
    [[ $CENTOS_SYNC == true ]] && PACKAGES+=( centos )
    [[ $EPEL_SYNC   == true ]] && PACKAGES+=( fedora-epel )
    [[ $UBUNTU_SYNC == true ]] && PACKAGES+=( ubuntu )
    [[ $DEBIAN_SYNC == true ]] && PACKAGES+=( debian )
    [[ $DEBSEC_SYNC == true ]] && PACKAGES+=( debian-security )
    [[ $SONION_SYNC == true ]] && PACKAGES+=( securityonion )
    [[ $CLAMAV_SYNC == true ]] && PACKAGES+=( clamav )
    [[ $LOCAL_SYNC  == true ]] && PACKAGES+=( local )

    [[ -n ${PACKAGES[*]} ]] || {
        say err 'No repos enabled for sync.'; exit 15; }

    # For every enabled repo
    for repo in "${PACKAGES[@]}"; do
        # Check for local repository directory
        [[ -d $REPODIR/$repo ]] || mkdir -p "$REPODIR/$repo"

        # Sync the upstream repository
        say 'Beginning sync of %s repository from %s.' "$repo" "$UMIRROR"
        rsync $ROPTS "${UMIRROR}::$repo/" "$REPODIR/$repo/"
        say 'Done.\n'
    done

    return 0
}

# Where the magic happens
main() {
    # Set Globals
    set_globals

    # Process arguments
    argument_handler "$@"

    # Here we go...
    say -t 'Progress log reset.'
    say 'Started synchronization of %s repositories.' "$SOFTWARE"
    say 'Use tail -f %s to view progress.' "$PROGFILE"

    # Check if the rsync script is already running
    if [[ -f $LOCKFILE ]]; then
        say err 'Detected lockfile: %s' "$LOCKFILE"
        say err 'Repository updates are already running.'
        exit 11

    # Check that we can reach the public mirror
    elif ! rsync ${MIRROR}:: &> /dev/null; then
        say err 'Cannot reach the %s mirror server.' "$MIRROR"
        exit 12

    # Check that the repository is mounted
    elif ! mount | grep "$REPODIR" &> /dev/null; then
        say err 'Directory %s is not mounted.' "$REPODIR"
        exit 13

    # Everything is good, let's continue
    else
        # There can be only one...
        touch "$LOCKFILE"

        # Generate variables
        build_vars

        # Are we upstream?
        [[ $UPSTREAM    == true ]] || {
            UMIRROR=${UMIRROR:=$MIRROR} && ds_sync; }

        # Sync CentOS repo
        [[ $CENTOS_SYNC == true ]] && centos_sync

        # Sync EPEL repo
        [[ $EPEL_SYNC   == true ]] && epel_sync

        # Sync Ubuntu repo
        [[ $UBUNTU_SYNC == true ]] && ubuntu_sync

        # Sync Debian repo
        [[ $DEBIAN_SYNC == true ]] && debian_sync

        # Sync Debian Security repo
        [[ $DEBSEC_SYNC == true ]] && debsec_sync

        # Sync Clamav reop
        [[ $CLAMAV_SYNC == true ]] && clamav_sync

        # Sync Security Onion reop
        [[ $SONION_SYNC == true ]] && clamav_sync

        # Sync Local repo
        [[ $LOCAL_SYNC  == true ]] && local_sync

        # Fix ownership of files
        say 'Normalizing repository file permissions.'
        chown -R root:www-data "$REPODIR"

        # Clear the lockfile
        rm -f "$LOCKFILE"
    fi

    # Now we're done
    say 'Completed synchronization of %s repositories.\n' "$SOFTWARE"
    exit 0
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"