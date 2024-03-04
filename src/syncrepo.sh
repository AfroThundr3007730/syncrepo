#!/bin/bash
# shellcheck disable=SC2086
# Repository sync script for CentOS & Debian distros
# This script can sync the repos listed in $SOFTWARE

# TODO: Note to self, since I probably forgot again:
#   Don't truncate the variable names, spell em out.

# Gotta keep the namespace clean
syncrepo.set_globals() {
    AUTHOR='AfroThundr'
    BASENAME="${0##*/}"
    MODIFIED='20240304'
    VERSION='1.8.0-rc1'

    SOFTWARE='CentOS, EPEL, Debian, Ubuntu, Security Onion, Docker, and ClamAV'

    # Global config variables (modify as necessary)
    UPSTREAM=true
    CENTOS_SYNC=true
    EPEL_SYNC=true
    DEBIAN_SYNC=true
    DEBSEC_SYNC=true
    UBUNTU_SYNC=true
    SONION_SYNC=true
    DOCKER_SYNC=true
    CLAMAV_SYNC=true
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

    SOMIRROR=ppa.launchpad.net
    SONIONREPO=${REPODIR}/securityonion

    DMIRROR=download.docker.com
    DOCKERREPO=${REPODIR}/docker

    CMIRROR=database.clamav.net
    CLAMREPO=${REPODIR}/clamav

    ROPTS="-hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file=$PROGFILE"
    TEELOG="tee -a $LOGFILE $PROGFILE"
}

# Parse command line options
syncrepo.parse_arguments() {
    [[ -n $1 ]] || {
        utils.say -h 'No arguments specified, use -h for help.'; exit 10; }

    while [[ -n $1 ]]; do
        if [[ $1 == -v ]]; then
            utils.say -h '%s: Version %s, updated %s by %s' \
                "$BASENAME" "$VERSION" "$MODIFIED" "$AUTHOR"
            ver=true
            shift
        elif [[ $1 == -h ]]; then
            utils.say -h 'Software repository updater script for linux distros.'
            utils.say -h 'Can curently sync the following repositories:'
            utils.say -h '%s\n' "$SOFTWARE"
            utils.say -h 'Usage: %s [-v] (-h | -y)\n' "$BASENAME"
            utils.say -h 'Options:'
            utils.say -h '  -h  Display help text.'
            utils.say -h '  -v  Emit version info.'
            utils.say -h '  -y  Confirm repo sync.'
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
            utils.say -h 'Invalid argument specified, use -h for help.'
            exit 10
        fi
    done

    [[ $CONFIRM == true ]] || {
        [[ $ver == true ]] || {
            utils.say -h 'Confirm with -y to start the sync.'; exit 10; }; exit 0; }
}

# Log message and print to stdout
# shellcheck disable=SC2059
utils.say() {
    export TERM=${TERM:=xterm}
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

# Record time duration, concurrent timers
# shellcheck disable=SC2004
utils.timer() {
    [[ $1 =~ ^[0-9]+$ ]] && {
        [[ $n -gt $1 ]] || n=$1; local i=$1; shift; }
    [[ $1 == -n ]] && { n=$(( n + 1 )); shift; }
    [[ $1 == -p ]] && { n=$(( n - 1 )); shift; }
    [[ $1 == -c ]] && { local i=$n; shift; }
    [[ -n $1 ]] || utils.say -n err 'No timer action specified.'
    [[ $1 == start ]] && tstart[$i]=$SECONDS
    [[ $1 == stop  ]] && {
        [[ -n ${tstart[$i]} ]] || utils.say -n err 'Timer %s not started.' "$i"
        tstop[$i]=$SECONDS; duration[$i]=$(( tstop[i] - tstart[i] )); }
    [[ $1 == show ]] && {
        [[ -n ${tstop[$i]} ]] || duration[$i]=$(( SECONDS - tstart[i] ))
        echo ${duration[$i]}; }
    return 0
}

# Construct the sync environment
syncrepo.build_vars() {
    # Declare more variables (CentOS/EPEL)
    [[ $CENTOS_SYNC == true || $EPEL_SYNC == true || $DOCKER_SYNC == true ]] && {
        mapfile -t allrels <<< "$(
            rsync $CENTHOST |
            awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}' |
            sort -V
        )"
        mapfile -t oldrels <<< "$(
            for i in "${allrels[@]}"; do
                [[ ${i%%.*} -eq $((${allrels[-1]%%.*} - 1)) ]] && echo "$i"
            done
        )"
        currel=${allrels[-1]}
        curmaj=${currel%%.*}
        cprerel=${allrels[-2]}
        oldrel=${oldrels[-1]}
        oldmaj=${oldrel%%.*}
        oprerel=${oldrels[-2]}

        centex=$(echo \
            --include={os,BaseOS,AppStream,extras,updates,centosplus,fasttrack,readme,{os/$CENTARCH,{BaseOS,AppStream}/$CENTARCH/os}/{repodata,Packages}} \
            --exclude={aarch64,i386,ppc64le,{os/$CENTARCH,{BaseOS,AppStream}/$CENTARCH{,/os}}/"*"} --exclude="/*")
        epelex=$(echo --exclude={SRPMS,aarch64,i386,ppc64,ppc64le,s390x,$CENTARCH/debug})

        dockersync="wget -m -np -N -nH -r --cut-dirs=1 -R 'index.html' -P $REPODIR/docker/"
        dockersync+=" $DMIRROR/linux/centos/$curmaj/$CENTARCH/stable/"
    }

    # Declare more variables (Debian/Ubuntu)
    [[ $UBUNTU_SYNC == true || $SONION_SYNC == true || $DOCKER_SYNC == true ]] && {
        mapfile -t uburels <<< "$(
            curl -sL $MIRROR/ubuntu-releases/HEADER.html |
            awk -F '(' '/<li.+>/ && /LTS/ && match($2, /[[:alpha:]]+/, a) {print a[0]}'
        )"
        ubucur=${uburels[0],}
        ubupre=${uburels[1],}

        ubuntucomps="main,restricted,universe,multiverse"
        ubunturel1="$ubupre,$ubupre-backports,$ubupre-updates,$ubupre-proposed,$ubupre-security"
        ubunturel2="$ubucur,$ubucur-backports,$ubucur-updates,$ubucur-proposed,$ubucur-security"
        ubuntuopts="-s $ubuntucomps -d $ubunturel1 -d $ubunturel2 -h $MIRROR -r /ubuntu"

        sonionopts="-s main -d $ubupre -d $ubucur -h $SOMIRROR --rsync-extra=none"
        sonionopts+=" -r /securityonion/stable/ubuntu"

        dockeroptsu="-s stable -d $ubupre -d $ubucur -h $DMIRROR --rsync-extra=none"
        dockeroptsu+=" -r /linux/ubuntu"
    }

    [[ $DEBIAN_SYNC == true || $DEBSEC_SYNC == true || $DOCKER_SYNC == true ]] && {
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

        dockeroptsd="-s stable -d $debpre -d $debcur -h $DMIRROR --rsync-extra=none"
        dockeroptsd+=" -r /linux/debian"
    }

    [[ $UBUNTU_SYNC == true || $DEBIAN_SYNC == true ||
       $DEBSEC_SYNC == true || $SONION_SYNC == true || $DOCKER_SYNC == true ]] && {
        dmirror1="debmirror -a $DEBARCH --no-source --ignore-small-errors"
        dmirror1+=" --method=rsync --retry-rsync-packages=5 -p --rsync-options="
        dmirror2="debmirror -a $DEBARCH --no-source --ignore-small-errors"
        dmirror2+=" --method=http --checksums -p"
        dmirror3="debmirror -a $DEBARCH --no-source --ignore-small-errors"
        dmirror3+=" --method=https --checksums -p"
    }

    # And a few more (ClamAV)
    [[ $CLAMAV_SYNC == true ]] &&
        clamsync="clamavmirror -a $CMIRROR -d $CLAMREPO -u root -g www-data"

    return 0
}

syncrepo.sync_centos() {
    for repo in $oldrel $currel; do
        # Check for centos release directory
        [[ -d $CENTREPO/$repo ]] || mkdir -p "$CENTREPO/$repo"

        # Sync current centos repository
        utils.say 'Beginning sync of CentOS %s repository from %s.' \
            "$repo" "$CENTHOST"
        rsync $ROPTS $centex "$CENTHOST/$repo/" "$CENTREPO/$repo/"
        utils.say 'Done.\n'

        # Create the symlink, or move, if necessary
        [[ -L ${repo%%.*} && $(readlink "${repo%%.*}") == "$repo" ]] ||
            ln -frsn "$CENTREPO/$repo" "$CENTREPO/${repo%%.*}"
    done

    # Continue to sync previous point releases til they're empty
    for repo in $oprerel $cprerel; do
        # Check for release directory
        [[ -d $CENTREPO/$repo ]] || mkdir -p "$CENTREPO/$repo"

        # Check for point release placeholder
        [[ -f $CENTREPO/$repo/readme ]] || {
            # Sync previous centos repository
            utils.say 'Beginning sync of CentOS %s repository from %s.' \
                "$repo" "$CENTHOST"
            rsync $ROPTS $centex "$CENTHOST/$repo/" "$CENTREPO/$repo/"
            utils.say 'Done.\n'
        }
    done

    return 0
}

syncrepo.sync_epel() {
    for repo in $oldmaj $curmaj testing/{$oldmaj,$curmaj}; do
        # Check for epel release directory
        [[ -d $EPELREPO/$repo ]] || mkdir -p "$EPELREPO/$repo"

        # Sync epel repository
        utils.say 'Beginning sync of EPEL %s repository from %s.' "$repo" "$EPELHOST"
        rsync $ROPTS $epelex "$EPELHOST/$repo/" "$EPELREPO/$repo/"
        utils.say 'Done.\n'
    done

    return 0
}

syncrepo.sync_ubuntu() {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for ubuntu directory
    [[ -d $UBUNTUREPO ]] || mkdir -p "$UBUNTUREPO"

    # Sync ubuntu repository
    utils.say 'Beginning sync of Ubuntu %s and %s repositories from %s.' \
        "${ubupre^}" "${ubucur^}" "$UBUNTUHOST"
    $dmirror2 $ubuntuopts $UBUNTUREPO &>> $PROGFILE
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_debian() {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for debian directory
    [[ -d $DEBIANREPO ]] || mkdir -p "$DEBIANREPO"

    # Sync debian repository
    utils.say 'Beginning sync of Debian %s and %s repositories from %s.' \
        "${debpre^}" "${debcur^}" "$DEBIANHOST"
    $dmirror2 $debianopts $DEBIANREPO &>> $PROGFILE
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_debsec() {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for debian security directory
    [[ -d $DEBSECREPO ]] || mkdir -p "$DEBSECREPO"

    # Sync debian security repository
    utils.say 'Beginning sync of Debian %s and %s Security repositories from %s.' \
        "${debpre^}" "${debcur^}" "$SMIRROR"
    $dmirror2 $debsecopts $DEBSECREPO &>> $PROGFILE
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_sonion() {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for security onion directory
    [[ -d $SONIONREPO ]] || mkdir -p "$SONIONREPO"

    # Sync security onion repository
    utils.say 'Beginning sync of Security Onion %s and %s repositories from %s.' \
        "${ubupre^}" "${ubucur^}" "$SOMIRROR"
    $dmirror2 $sonionopts $SONIONREPO &>> $PROGFILE
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_docker() {
    export GNUPGHOME=$REPODIR/.gpg

    # Check for docker directory
    [[ -d $DOCKERREPO ]] || mkdir -p "$DOCKERREPO"

    # Sync docker repository (for each enabled OS)

    # TODO: Implement `wget_rsync` method instead of a regular clone
    [[ $CENTOS_SYNC == true ]] && {
    utils.say 'Beginning sync of Docker Centos %s repository from %s.' \
        "${ubucur^}" "$DMIRROR"
    $dockersync &>> $PROGFILE
    utils.say 'Done.\n'
    }

    [[ $UBUNTU_SYNC == true ]] && {
    utils.say 'Beginning sync of Docker Ubuntu %s and %s repositories from %s.' \
        "${ubupre^}" "${ubucur^}" "$DMIRROR"
    $dmirror3 ${dockeroptsu} $DOCKERREPO/ubuntu &>> $PROGFILE
    utils.say 'Done.\n'
    }

    [[ $DEBIAN_SYNC == true ]] && {
    utils.say 'Beginning sync of Docker Debian %s and %s repositories from %s.' \
        "${debpre^}" "${debcur^}" "$DMIRROR"
    $dmirror3 ${dockeroptsd} $DOCKERREPO/debian &>> $PROGFILE
    utils.say 'Done.\n'
    }

    unset GNUPGHOME
    return 0
}

syncrepo.sync_clamav() {
    # Check for clamav directory
    [[ -d $CLAMREPO ]] || mkdir -p "$CLAMREPO"

    # Sync clamav repository
    utils.say 'Beginning sync of ClamAV repository from %s.' "$CMIRROR"
    $clamsync &>> $PROGFILE
    utils.say 'Done.\n'

    return 0
}

syncrepo.sync_downstream() {
    utils.say 'Configured as downstream, so mirroring local upstream.'

    [[ -n $UMIRROR ]] || {
        utils.say err 'UMIRROR is empty or not set.'; exit 14; }

    # Build array of repos to sync downstream
    [[ $CENTOS_SYNC == true ]] && PACKAGES+=( centos )
    [[ $EPEL_SYNC   == true ]] && PACKAGES+=( fedora-epel )
    [[ $UBUNTU_SYNC == true ]] && PACKAGES+=( ubuntu )
    [[ $DEBIAN_SYNC == true ]] && PACKAGES+=( debian )
    [[ $DEBSEC_SYNC == true ]] && PACKAGES+=( debian-security )
    [[ $SONION_SYNC == true ]] && PACKAGES+=( securityonion )
    [[ $DOCKER_SYNC == true ]] && PACKAGES+=( docker )
    [[ $CLAMAV_SYNC == true ]] && PACKAGES+=( clamav )
    [[ $LOCAL_SYNC  == true ]] && PACKAGES+=( local )

    [[ -n ${PACKAGES[*]} ]] || {
        utils.say err 'No repos enabled for sync.'; exit 15; }

    # For every enabled repo
    for repo in "${PACKAGES[@]}"; do
        # Check for local repository directory
        [[ -d $REPODIR/$repo ]] || mkdir -p "$REPODIR/$repo"

        # Sync the upstream repository
        utils.say 'Beginning sync of %s repository from %s.' "$repo" "$UMIRROR"
        rsync $ROPTS "${UMIRROR}::$repo/" "$REPODIR/$repo/"
        utils.say 'Done.\n'
    done

    return 0
}

# Where the magic happens
syncrepo.main() {
    # Set Globals
    syncrepo.set_globals

    # Process arguments
    syncrepo.parse_arguments "$@"

    # Here we go...
    utils.say -t 'Progress log reset.'
    utils.say 'Started synchronization of %s repositories.' "$SOFTWARE"
    utils.say 'Use tail -f %s to view progress.' "$PROGFILE"
    utils.timer start

    # Check if the rsync script is already running
    if [[ -f $LOCKFILE ]]; then
        utils.say err 'Detected lockfile: %s' "$LOCKFILE"
        utils.say err 'Repository updates are already running.'
        exit 11

    # Check that we can reach the public mirror
    elif ( [[ $UPSTREAM == true ]] && ! rsync ${MIRROR}:: &> /dev/null ) ||
         ( [[ $UPSTREAM == false ]] && ! rsync ${UMIRROR}:: &> /dev/null ); then
        utils.say err 'Cannot reach the %s mirror server.' "$MIRROR"
        exit 12

    # Check that the repository is mounted
    elif ! mount | grep "$REPODIR" &> /dev/null; then
        utils.say err 'Directory %s is not mounted.' "$REPODIR"
        exit 13

    # Everything is good, let's continue
    else
        # There can be only one...
        touch "$LOCKFILE"

        # Are we upstream?
        if [[ $UPSTREAM == true ]]; then
            # Generate variables
            syncrepo.build_vars

            # Sync every enabled repo
            [[ $CENTOS_SYNC == true ]] && syncrepo.sync_centos
            [[ $EPEL_SYNC   == true ]] && syncrepo.sync_epel
            [[ $UBUNTU_SYNC == true ]] && syncrepo.sync_ubuntu
            [[ $DEBIAN_SYNC == true ]] && syncrepo.sync_debian
            [[ $DEBSEC_SYNC == true ]] && syncrepo.sync_debsec
            [[ $SONION_SYNC == true ]] && syncrepo.sync_sonion
            [[ $DOCKER_SYNC == true ]] && syncrepo.sync_docker
            [[ $CLAMAV_SYNC == true ]] && syncrepo.sync_clamav
            [[ $LOCAL_SYNC  == true ]] && syncrepo.sync_local
        else
            # Do a downstream sync
            UMIRROR=${UMIRROR:=$MIRROR} && syncrepo.sync_downstream
        fi

        # Fix ownership of files
        utils.say 'Normalizing repository file permissions.'
        chown -R root:www-data "$REPODIR"

        # Clear the lockfile
        rm -f "$LOCKFILE"
    fi

    # Now we're done
    utils.timer stop
    utils.say 'Completed synchronization of %s repositories.' "$SOFTWARE"
    utils.say 'Total duration: %d seconds. Current repository size: %s.\n' \
        "$(utils.timer show)" "$(du -hs $REPODIR | awk '{print $1}')"
    exit 0
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && syncrepo.main "$@"
