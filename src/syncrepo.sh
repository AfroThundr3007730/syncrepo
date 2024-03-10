#!/bin/bash
# Repository sync script for CentOS & Debian distros
# This script can sync the repos listed in $SR_LIST_SOFTWARE

# TODO: Note to self, since I probably forgot again:
#   Don't truncate the variable names, spell em out.

# Gotta keep the namespace clean
syncrepo.set_globals() {
    AUTHOR='AfroThundr'
    BASENAME="${0##*/}"
    MODIFIED='20240308'
    VERSION='1.8.0-rc3'

    SR_LIST_SOFTWARE=('CentOS' 'EPEL' 'Debian' 'Ubuntu' 'Security Onion' 'Docker' 'ClamAV')

    # Global config variables (override with environment variables)
    # TODO: Build config file schema
    SR_BOOL_UPSTREAM=${SR_BOOL_UPSTREAM:=true}
    SR_SYNC_CENTOS=${SR_SYNC_CENTOS:=true}
    SR_SYNC_EPEL=${SR_SYNC_EPEL:=true}
    SR_SYNC_DEBIAN=${SR_SYNC_DEBIAN:=true}
    SR_SYNC_DEBSEC=${SR_SYNC_DEBSEC:=true}
    SR_SYNC_UBUNTU=${SR_SYNC_UBUNTU:=true}
    SR_SYNC_SONION=${SR_SYNC_SONION:=true}
    SR_SYNC_DOCKER=${SR_SYNC_DOCKER:=true}
    SR_SYNC_CLAMAV=${SR_SYNC_CLAMAV:=true}
    SR_SYNC_LOCAL=${SR_SYNC_LOCAL:=true}

    SR_REPO_PRIMARY=${SR_REPO_PRIMARY:=/srv/repository}
    SR_FILE_LOCKFILE=${SR_FILE_LOCKFILE:=/var/lock/subsys/syncrepo}
    SR_FILE_LOG_MAIN=${SR_FILE_LOG_MAIN:=/var/log/syncrepo.log}
    SR_FILE_LOG_PROGRESS=${SR_FILE_LOG_PROGRESS:=/var/log/syncrepo_progress.log}

    # More internal config variables
    SR_MIRROR_PRIMARY=${SR_MIRROR_PRIMARY:=mirrors.mit.edu}
    SR_MIRROR_UPSTREAM=${SR_MIRROR_UPSTREAM:=mirror-us.lab.local}

    SR_ARCH_RHEL=${SR_ARCH_RHEL:=x86_64}
    SR_REPO_CENTOS=${SR_REPO_CENTOS:=${SR_REPO_PRIMARY}/centos}
    SR_MIRROR_CENTOS=${SR_MIRROR_CENTOS:=${SR_MIRROR_PRIMARY}::centos}
    SR_REPO_EPEL=${SR_REPO_EPEL:=${SR_REPO_PRIMARY}/fedora-epel}
    SR_MIRROR_EPEL=${SR_MIRROR_EPEL:=${SR_MIRROR_PRIMARY}::fedora-epel}

    SR_ARCH_DEBIAN=${SR_ARCH_DEBIAN:=amd64}
    SR_REPO_UBUNTU=${SR_REPO_UBUNTU:=${SR_REPO_PRIMARY}/ubuntu}
    SR_MIRROR_UBUNTU=${SR_MIRROR_UBUNTU:=${SR_MIRROR_PRIMARY}::ubuntu}
    SR_REPO_DEBIAN=${SR_REPO_DEBIAN:=${SR_REPO_PRIMARY}/debian}
    SR_MIRROR_DEBIAN=${SR_MIRROR_DEBIAN:=${SR_MIRROR_PRIMARY}::debian}

    SR_MIRROR_DEBIAN_SECURITY=${SR_MIRROR_DEBIAN_SECURITY:=security.debian.org}
    SR_REPO_DEBIAN_SECURITY=${SR_REPO_DEBIAN_SECURITY:=${SR_REPO_PRIMARY}/debian-security}

    SR_MIRROR_SECURITYONION=${SR_MIRROR_SECURITYONION:=ppa.launchpad.net}
    SR_REPO_SECURITYONION=${SR_REPO_SECURITYONION:=${SR_REPO_PRIMARY}/securityonion}

    SR_MIRROR_DOCKER=${SR_MIRROR_DOCKER:=download.docker.com}
    SR_REPO_DOCKER=${SR_REPO_DOCKER:=${SR_REPO_PRIMARY}/docker}

    SR_MIRROR_CLAMAV=${SR_MIRROR_CLAMAV:=database.clamav.net}
    SR_REPO_CLAMAV=${SR_REPO_CLAMAV:=${SR_REPO_PRIMARY}/clamav}

    [[ ${SR_OPTS_RSYNC[*]} ]] ||
        SR_OPTS_RSYNC=(-hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file="$SR_FILE_LOG_PROGRESS")
    [[ ${SR_OPTS_TEE[*]} ]] || SR_OPTS_TEE=(tee -a "$SR_FILE_LOG_MAIN" "$SR_FILE_LOG_PROGRESS")
}

# Parse command line options
syncrepo.parse_arguments() {
    [[ -n $1 ]] || {
        utils.say -h 'No arguments specified, use -h for help.'
        exit 1
    }

    while [[ -n $1 ]]; do
        if [[ $1 == -v ]]; then
            utils.say -h '%s: Version %s, updated %s by %s' \
                "$BASENAME" "$VERSION" "$MODIFIED" "$AUTHOR"
            ver=true
            shift
        elif [[ $1 == -h ]]; then
            utils.say -h 'Software repository updater script for linux distros.'
            utils.say -h 'Can curently sync the following repositories:'
            utils.say -h '%s\n' "${SR_LIST_SOFTWARE[*]}"
            utils.say -h 'Usage: %s [-v] (-h | -y)\n' "$BASENAME"
            utils.say -h 'Options:'
            utils.say -h '  -a|--arch         Specify architecture to sync.'
            utils.say -h '  -d|--downstream   Set this mirror to be downstream.'
            utils.say -h '  -h|--help         Display this help message.'
            utils.say -h '  -l|--log-file     Specify log file location.'
            utils.say -h '  -p|--prog-log     Specify progress log location.'
            utils.say -h '  -m|--mirror       Specify upstream mirror.'
            utils.say -h '  -s|--sync         List of components to sync.'
            utils.say -h '  -v|--version      Show the version info.'
            utils.say -h '  -y|--yes          Confirm the repository sync.'
            # TODO: Do we want these to supersede `--sync` or merge with it?
            utils.say -h '\nYou can explicitly enable components with the following:'
            utils.say -h '  --centos-sync     Sync the CentOS repo.'
            utils.say -h '  --clamav-sync     Sync the ClamAV repo.'
            utils.say -h '  --debian-sync     Sync the Debian repo.'
            utils.say -h '  --debsec-sync     Sync the Debian Secuirty repo.'
            utils.say -h '  --epel-sync       Sync the EPEL repo.'
            utils.say -h '  --local-sync      Sync a locally built repo.'
            utils.say -h '  --sonion-sync     Sync the Security Onion repo.'
            utils.say -h '  --ubuntu-sync     Sync the Ubuntu repo.'
            exit 0
        elif [[ $1 == -q ]]; then
            SR_BOOL_QUIET=true
            shift
        elif [[ $1 == -y ]]; then
            SR_BOOL_CONFIRMED=true
            shift
        else
            utils.say -h 'Invalid argument specified, use -h for help.'
            exit 1
        fi
    done

    [[ $SR_BOOL_CONFIRMED == true ]] || {
        [[ $ver == true ]] || {
            utils.say -h 'Confirm with -y to start the sync.'
            exit 1
        }
        exit 0
    }
}

# Log message and print to stdout
# shellcheck disable=SC2059
utils.say() {
    export TERM=${TERM:=xterm}
    if [[ $1 == -h ]]; then
        local s=$2
        shift 2
        tput setaf 2
        printf "$s\\n" "$@"
    else
        if [[ $SR_FILE_LOG_MAIN == no && $SR_FILE_LOG_PROGRESS == no || $1 == -n ]]; then
            [[ $1 == -n ]] && shift
        else
            local log=true
        fi
        [[ $1 == -t ]] && {
            echo >"$SR_FILE_LOG_PROGRESS"
            shift
        }
        if [[ $1 == info || $1 == warn || $1 == err ]]; then
            [[ $1 == info ]] && tput setaf 4
            [[ $1 == warn ]] && tput setaf 3
            [[ $1 == err ]] && tput setaf 1
            local s="${1^^}: $2"
            shift 2
        else
            local s="$1"
            shift
        fi
        if [[ $log == true ]]; then
            # shellcheck disable=SC2015
            [[ ! $SR_BOOL_QUIET ]] &&
                printf "%s: $s\\n" "$(date -u +%FT%TZ)" "$@" | "${SR_OPTS_TEE[@]}" ||
                printf "%s: $s\\n" "$(date -u +%FT%TZ)" "$@" | "${SR_OPTS_TEE[@]}" >/dev/null
        else
            [[ $SR_BOOL_QUIET ]] || printf "%s: $s\\n" "$(date -u +%FT%TZ)" "$@"
        fi
    fi
    tput setaf 7 # For CentOS
    return 0
}

# Record time duration, concurrent timers
# shellcheck disable=SC2004
utils.timer() {
    [[ $1 =~ ^[0-9]+$ ]] && {
        [[ $n -gt $1 ]] || n=$1
        local i=$1
        shift
    }
    [[ $1 == -n ]] && {
        n=$((n + 1))
        shift
    }
    [[ $1 == -p ]] && {
        n=$((n - 1))
        shift
    }
    [[ $1 == -c ]] && {
        local i=$n
        shift
    }
    [[ -n $1 ]] || utils.say -n err 'No timer action specified.'
    [[ $1 == start ]] && tstart[$i]=$SECONDS
    [[ $1 == stop ]] && {
        [[ -n ${tstart[$i]} ]] || utils.say -n err 'Timer %s not started.' "$i"
        tstop[$i]=$SECONDS
        duration[$i]=$((tstop[i] - tstart[i]))
    }
    [[ $1 == show ]] && {
        [[ -n ${tstop[$i]} ]] || duration[$i]=$((SECONDS - tstart[i]))
        echo "${duration[$i]}"
    }
    return 0
}

# Construct the sync environment
syncrepo.build_vars() {
    # Declare more variables (CentOS/EPEL)
    [[ $SR_SYNC_CENTOS == true || $SR_SYNC_EPEL == true || $SR_SYNC_DOCKER == true ]] && {
        mapfile -t allrels <<<"$(
            rsync "$SR_MIRROR_CENTOS" |
                awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}' |
                sort -V
        )"
        mapfile -t oldrels <<<"$(
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

        centex=(
            --include={os,BaseOS,AppStream,extras,updates,centosplus,fasttrack,readme}
            --include={os/$SR_ARCH_RHEL,{BaseOS,AppStream}/$SR_ARCH_RHEL/os}/{repodata,Packages}
            --exclude={aarch64,i386,ppc64le,{os/$SR_ARCH_RHEL,{BaseOS,AppStream}/$SR_ARCH_RHEL{,/os}}/*,/*}
        )
        epelex=(--exclude={SRPMS,aarch64,i386,ppc64,ppc64le,s390x,$SR_ARCH_RHEL/debug})

        dockersync="wget -m -np -N -nH -r --cut-dirs=1 -R 'index.html' -P $SR_REPO_PRIMARY/docker/"
        dockersync+=" $SR_MIRROR_DOCKER/linux/centos/$curmaj/$SR_ARCH_RHEL/stable/"
    }

    # Declare more variables (Debian/Ubuntu)
    [[ $SR_SYNC_UBUNTU == true || $SR_SYNC_SONION == true || $SR_SYNC_DOCKER == true ]] && {
        mapfile -t uburels <<<"$(
            curl -sL "$SR_MIRROR_PRIMARY/ubuntu-releases/HEADER.html" |
                awk -F '(' '/<li.+>/ && /LTS/ && match($2, /[[:alpha:]]+/, a) {print a[0]}'
        )"
        ubucur=${uburels[0],}
        ubupre=${uburels[1],}

        ubuntucomps='main,restricted,universe,multiverse'
        ubunturels=({$ubupre,$ubucur}{,-backports,-updates,-proposed,-security})
        IFS=, ubuntuopts="-s $ubuntucomps -d ${ubunturels[*]} -h $SR_MIRROR_PRIMARY -r /ubuntu"

        sonionopts="-s main -d $ubupre -d $ubucur -h $SR_MIRROR_SECURITYONION --rsync-extra=none"
        sonionopts+=" -r /securityonion/stable/ubuntu"

        dockeroptsu="-s stable -d $ubupre -d $ubucur -h $SR_MIRROR_DOCKER --rsync-extra=none"
        dockeroptsu+=' -r /linux/ubuntu'
    }

    [[ $SR_SYNC_DEBIAN == true || $SR_SYNC_DEBSEC == true || $SR_SYNC_DOCKER == true ]] && {
        mapfile -t debrels <<<"$(
            curl -sL "$SR_MIRROR_PRIMARY/debian/README.html" |
                awk -F '[<> ]' '/<dt>/ && /Debian/ {print $9}'
        )"
        debcur=${debrels[0]}
        debpre=${debrels[1]}

        debiancomps='main,contrib,non-free'
        debianrels=({$debpre,$debcur}{,-backports,-updates,-proposed-updates})
        IFS=, debianopts="-s $debiancomps -d ${debianrels[*]} -h $SR_MIRROR_PRIMARY -r /debian"

        debsecrels=({$debcur,$debpre}/updates)
        IFS=, debsecopts="-s $debiancomps -d ${debsecrels[*]} -h $SR_MIRROR_DEBIAN_SECURITY -r /"

        dockeroptsd="-s stable -d $debpre -d $debcur -h $SR_MIRROR_DOCKER --rsync-extra=none"
        dockeroptsd+=' -r /linux/debian'
    }

    [[ $SR_SYNC_UBUNTU == true || $SR_SYNC_DEBIAN == true ||
        $SR_SYNC_DEBSEC == true || $SR_SYNC_SONION == true || $SR_SYNC_DOCKER == true ]] && {
        dmirror1="debmirror -a $SR_ARCH_DEBIAN --no-source --ignore-small-errors"
        dmirror1+=" --method=rsync --retry-rsync-packages=5 -p --rsync-options="
        dmirror2="debmirror -a $SR_ARCH_DEBIAN --no-source --ignore-small-errors"
        dmirror2+=" --method=http --checksums -p"
        dmirror3="debmirror -a $SR_ARCH_DEBIAN --no-source --ignore-small-errors"
        dmirror3+=" --method=https --checksums -p"
    }

    # And a few more (ClamAV)
    [[ $SR_SYNC_CLAMAV == true ]] &&
        clamsync="clamavmirror -a $SR_MIRROR_CLAMAV -d $SR_REPO_CLAMAV -u root -g www-data"

    return 0
}

syncrepo.sync_centos() {
    for repo in $oldrel $currel; do
        # Check for centos release directory
        [[ -d $SR_REPO_CENTOS/$repo ]] || mkdir -p "$SR_REPO_CENTOS/$repo"

        # Sync current centos repository
        utils.say 'Beginning sync of CentOS %s repository from %s.' \
            "$repo" "$SR_MIRROR_CENTOS"
        rsync "${SR_OPTS_RSYNC[@]}" "${centex[@]}" "$SR_MIRROR_CENTOS/$repo/" "$SR_REPO_CENTOS/$repo/"
        utils.say 'Done.\n'

        # Create the symlink, or move, if necessary
        [[ -L ${repo%%.*} && $(readlink "${repo%%.*}") == "$repo" ]] ||
            ln -frsn "$SR_REPO_CENTOS/$repo" "$SR_REPO_CENTOS/${repo%%.*}"
    done

    # Continue to sync previous point releases til they're empty
    for repo in $oprerel $cprerel; do
        # Check for release directory
        [[ -d $SR_REPO_CENTOS/$repo ]] || mkdir -p "$SR_REPO_CENTOS/$repo"

        # Check for point release placeholder
        [[ -f $SR_REPO_CENTOS/$repo/readme ]] || {
            # Sync previous centos repository
            utils.say 'Beginning sync of CentOS %s repository from %s.' \
                "$repo" "$SR_MIRROR_CENTOS"
            rsync "${SR_OPTS_RSYNC[@]}" "${centex[@]}" "$SR_MIRROR_CENTOS/$repo/" "$SR_REPO_CENTOS/$repo/"
            utils.say 'Done.\n'
        }
    done

    return 0
}

syncrepo.sync_epel() {
    for repo in $oldmaj $curmaj testing/{$oldmaj,$curmaj}; do
        # Check for epel release directory
        [[ -d $SR_REPO_EPEL/$repo ]] || mkdir -p "$SR_REPO_EPEL/$repo"

        # Sync epel repository
        utils.say 'Beginning sync of EPEL %s repository from %s.' "$repo" "$SR_MIRROR_EPEL"
        rsync "${SR_OPTS_RSYNC[@]}" "${epelex[@]}" "$SR_MIRROR_EPEL/$repo/" "$SR_REPO_EPEL/$repo/"
        utils.say 'Done.\n'
    done

    return 0
}

syncrepo.sync_ubuntu() {
    export GNUPGHOME=$SR_REPO_PRIMARY/.gpg

    # Check for ubuntu directory
    [[ -d $SR_REPO_UBUNTU ]] || mkdir -p "$SR_REPO_UBUNTU"

    # Sync ubuntu repository
    utils.say 'Beginning sync of Ubuntu %s and %s repositories from %s.' \
        "${ubupre^}" "${ubucur^}" "$SR_MIRROR_UBUNTU"
    $dmirror2 "$ubuntuopts" "$SR_REPO_UBUNTU" &>>"$SR_FILE_LOG_PROGRESS"
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_debian() {
    export GNUPGHOME=$SR_REPO_PRIMARY/.gpg

    # Check for debian directory
    [[ -d $SR_REPO_DEBIAN ]] || mkdir -p "$SR_REPO_DEBIAN"

    # Sync debian repository
    utils.say 'Beginning sync of Debian %s and %s repositories from %s.' \
        "${debpre^}" "${debcur^}" "$SR_MIRROR_DEBIAN"
    $dmirror2 "$debianopts" "$SR_REPO_DEBIAN" &>>"$SR_FILE_LOG_PROGRESS"
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_debsec() {
    export GNUPGHOME=$SR_REPO_PRIMARY/.gpg

    # Check for debian security directory
    [[ -d $SR_REPO_DEBIAN_SECURITY ]] || mkdir -p "$SR_REPO_DEBIAN_SECURITY"

    # Sync debian security repository
    utils.say 'Beginning sync of Debian %s and %s Security repositories from %s.' \
        "${debpre^}" "${debcur^}" "$SR_MIRROR_DEBIAN_SECURITY"
    $dmirror2 "$debsecopts" "$SR_REPO_DEBIAN_SECURITY" &>>"$SR_FILE_LOG_PROGRESS"
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_sonion() {
    export GNUPGHOME=$SR_REPO_PRIMARY/.gpg

    # Check for security onion directory
    [[ -d $SR_REPO_SECURITYONION ]] || mkdir -p "$SR_REPO_SECURITYONION"

    # Sync security onion repository
    utils.say 'Beginning sync of Security Onion %s and %s repositories from %s.' \
        "${ubupre^}" "${ubucur^}" "$SR_MIRROR_SECURITYONION"
    $dmirror2 "$sonionopts" "$SR_REPO_SECURITYONION" &>>"$SR_FILE_LOG_PROGRESS"
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_docker() {
    export GNUPGHOME=$SR_REPO_PRIMARY/.gpg

    # Check for docker directory
    [[ -d $SR_REPO_DOCKER ]] || mkdir -p "$SR_REPO_DOCKER"

    # Sync docker repository (for each enabled OS)

    # TODO: Implement `wget_rsync` method instead of a regular clone
    [[ $SR_SYNC_CENTOS == true ]] && {
        utils.say 'Beginning sync of Docker Centos %s repository from %s.' \
            "${ubucur^}" "$SR_MIRROR_DOCKER"
        $dockersync &>>"$SR_FILE_LOG_PROGRESS"
        utils.say 'Done.\n'
    }

    [[ $SR_SYNC_UBUNTU == true ]] && {
        utils.say 'Beginning sync of Docker Ubuntu %s and %s repositories from %s.' \
            "${ubupre^}" "${ubucur^}" "$SR_MIRROR_DOCKER"
        $dmirror3 "$dockeroptsu" "$SR_REPO_DOCKER/ubuntu" &>>"$SR_FILE_LOG_PROGRESS"
        utils.say 'Done.\n'
    }

    [[ $SR_SYNC_DEBIAN == true ]] && {
        utils.say 'Beginning sync of Docker Debian %s and %s repositories from %s.' \
            "${debpre^}" "${debcur^}" "$SR_MIRROR_DOCKER"
        $dmirror3 "$dockeroptsd" "$SR_REPO_DOCKER/debian" &>>"$SR_FILE_LOG_PROGRESS"
        utils.say 'Done.\n'
    }

    unset GNUPGHOME
    return 0
}

syncrepo.sync_clamav() {
    # Check for clamav directory
    [[ -d $SR_REPO_CLAMAV ]] || mkdir -p "$SR_REPO_CLAMAV"

    # Sync clamav repository
    utils.say 'Beginning sync of ClamAV repository from %s.' "$SR_MIRROR_CLAMAV"
    $clamsync &>>"$SR_FILE_LOG_PROGRESS"
    utils.say 'Done.\n'

    return 0
}

syncrepo.sync_downstream() {
    utils.say 'Configured as downstream, so mirroring local upstream.'

    [[ -n $SR_MIRROR_UPSTREAM ]] || {
        utils.say err 'SR_MIRROR_UPSTREAM is empty or not set.'
        exit 1
    }

    # Build array of repos to sync downstream
    [[ $SR_SYNC_CENTOS == true ]] && SR_LIST_PACKAGES+=(centos)
    [[ $SR_SYNC_EPEL   == true ]] && SR_LIST_PACKAGES+=(fedora-epel)
    [[ $SR_SYNC_UBUNTU == true ]] && SR_LIST_PACKAGES+=(ubuntu)
    [[ $SR_SYNC_DEBIAN == true ]] && SR_LIST_PACKAGES+=(debian)
    [[ $SR_SYNC_DEBSEC == true ]] && SR_LIST_PACKAGES+=(debian-security)
    [[ $SR_SYNC_SONION == true ]] && SR_LIST_PACKAGES+=(securityonion)
    [[ $SR_SYNC_DOCKER == true ]] && SR_LIST_PACKAGES+=(docker)
    [[ $SR_SYNC_CLAMAV == true ]] && SR_LIST_PACKAGES+=(clamav)
    [[ $SR_SYNC_LOCAL  == true ]] && SR_LIST_PACKAGES+=(local)

    [[ -n ${SR_LIST_PACKAGES[*]} ]] || {
        utils.say err 'No repos enabled for sync.'
        exit 1
    }

    # For every enabled repo
    for repo in "${SR_LIST_PACKAGES[@]}"; do
        # Check for local repository directory
        [[ -d $SR_REPO_PRIMARY/$repo ]] || mkdir -p "$SR_REPO_PRIMARY/$repo"

        # Sync the upstream repository
        utils.say 'Beginning sync of %s repository from %s.' "$repo" "$SR_MIRROR_UPSTREAM"
        rsync "${SR_OPTS_RSYNC[@]}" "${SR_MIRROR_UPSTREAM}::$repo/" "$SR_REPO_PRIMARY/$repo/"
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
    utils.say 'Started synchronization of repositories: %s' "${SR_LIST_SOFTWARE[*]}"
    utils.say 'Use tail -f %s to view progress.' "$SR_FILE_LOG_PROGRESS"
    utils.timer start

    # Check if the rsync script is already running
    if [[ -f $SR_FILE_LOCKFILE ]]; then
        utils.say err 'Detected lockfile: %s' "$SR_FILE_LOCKFILE"
        utils.say err 'Repository updates are already running.'
        exit 1

    # Check that we can reach the public mirror
    elif ([[ $SR_BOOL_UPSTREAM == true ]] && ! rsync "${SR_MIRROR_PRIMARY}::" &>/dev/null) ||
        ([[ $SR_BOOL_UPSTREAM == false ]] && ! rsync "${SR_MIRROR_UPSTREAM}::" &>/dev/null); then
        utils.say err 'Cannot reach the %s mirror server.' "$SR_MIRROR_PRIMARY"
        exit 1

    # Check that the repository is mounted
    elif ! mount | grep "$SR_REPO_PRIMARY" &>/dev/null; then
        utils.say err 'Directory %s is not mounted.' "$SR_REPO_PRIMARY"
        exit 1

    # Everything is good, let's continue
    else
        # There can be only one...
        touch "$SR_FILE_LOCKFILE"

        # Are we upstream?
        if [[ $SR_BOOL_UPSTREAM == true ]]; then
            # Generate variables
            syncrepo.build_vars

            # Sync every enabled repo
            [[ $SR_SYNC_CENTOS == true ]] && syncrepo.sync_centos
            [[ $SR_SYNC_EPEL   == true ]] && syncrepo.sync_epel
            [[ $SR_SYNC_UBUNTU == true ]] && syncrepo.sync_ubuntu
            [[ $SR_SYNC_DEBIAN == true ]] && syncrepo.sync_debian
            [[ $SR_SYNC_DEBSEC == true ]] && syncrepo.sync_debsec
            [[ $SR_SYNC_SONION == true ]] && syncrepo.sync_sonion
            [[ $SR_SYNC_DOCKER == true ]] && syncrepo.sync_docker
            [[ $SR_SYNC_CLAMAV == true ]] && syncrepo.sync_clamav
            [[ $SR_SYNC_LOCAL  == true ]] && syncrepo.sync_local
        else
            # Do a downstream sync
            SR_MIRROR_UPSTREAM=${SR_MIRROR_UPSTREAM:=$SR_MIRROR_PRIMARY} && syncrepo.sync_downstream
        fi

        # Fix ownership of files
        # TODO: Make uid/gid into variable
        utils.say 'Normalizing repository file permissions.'
        chown -R root:www-data "$SR_REPO_PRIMARY"

        # Clear the lockfile
        rm -f "$SR_FILE_LOCKFILE"
    fi

    # Now we're done
    utils.timer stop
    utils.say 'Completed synchronization of repositories: %s' "${SR_LIST_SOFTWARE[*]}"
    utils.say 'Total duration: %d seconds. Current repository size: %s.\n' \
        "$(utils.timer show)" "$(du -hs "$SR_REPO_PRIMARY" | awk '{print $1}')"
    exit 0
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && syncrepo.main "$@"
