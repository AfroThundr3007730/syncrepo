#!/bin/bash
# Repository sync script for CentOS & Debian distros
# This script can sync the repos listed in $SR_META_SOFTWARE

# Initialize global config variables
syncrepo.set_globals() {
    SR_META_AUTHOR='AfroThundr'
    SR_META_BASENAME="${0##*/}"
    SR_META_MODIFIED='20240308'
    SR_META_VERSION='1.8.0-rc6'
    SR_META_SOFTWARE=('CentOS' 'EPEL' 'Debian' 'Ubuntu' 'Security Onion' 'Docker' 'ClamAV')

    # User can override with environment variables
    SR_BOOL_UPSTREAM=${SR_BOOL_UPSTREAM:-true}

    SR_SYNC_ALL_REPOS=${SR_SYNC_ALL_REPOS:-false}
    SR_SYNC_CENTOS=${SR_SYNC_CENTOS:-$SR_SYNC_ALL_REPOS}
    SR_SYNC_EPEL=${SR_SYNC_EPEL:-$SR_SYNC_ALL_REPOS}
    SR_SYNC_DEBIAN=${SR_SYNC_DEBIAN:-$SR_SYNC_ALL_REPOS}
    SR_SYNC_DEBIAN_SECURITY=${SR_SYNC_DEBIAN_SECURITY:-$SR_SYNC_ALL_REPOS}
    SR_SYNC_UBUNTU=${SR_SYNC_UBUNTU:-$SR_SYNC_ALL_REPOS}
    SR_SYNC_SECURITYONION=${SR_SYNC_SECURITYONION:-$SR_SYNC_ALL_REPOS}
    SR_SYNC_DOCKER=${SR_SYNC_DOCKER:-$SR_SYNC_ALL_REPOS}
    SR_SYNC_CLAMAV=${SR_SYNC_CLAMAV:-$SR_SYNC_ALL_REPOS}
    SR_SYNC_LOCAL=${SR_SYNC_LOCAL:-$SR_SYNC_ALL_REPOS}

    SR_REPO_PRIMARY=${SR_REPO_PRIMARY:-/srv/repository}
    SR_REPO_CHOWN_UID=${SR_REPO_CHOWN_UID:-root}
    SR_REPO_CHOWN_GID=${SR_REPO_CHOWN_GID:-www-data}
    SR_FILE_LOCKFILE=${SR_FILE_LOCKFILE:-/var/lock/subsys/syncrepo}
    SR_FILE_LOG_MAIN=${SR_FILE_LOG_MAIN:-/var/log/syncrepo.log}
    SR_FILE_LOG_PROGRESS=${SR_FILE_LOG_PROGRESS:-/var/log/syncrepo_progress.log}

    SR_MIRROR_PRIMARY=${SR_MIRROR_PRIMARY:-mirrors.mit.edu}
    SR_MIRROR_UPSTREAM=${SR_MIRROR_UPSTREAM:-mirror-us.lab.local}

    SR_ARCH_RHEL=${SR_ARCH_RHEL:-x86_64}
    SR_REPO_CENTOS=${SR_REPO_CENTOS:-${SR_REPO_PRIMARY}/centos}
    SR_MIRROR_CENTOS=${SR_MIRROR_CENTOS:-${SR_MIRROR_PRIMARY}::centos}
    SR_REPO_EPEL=${SR_REPO_EPEL:-${SR_REPO_PRIMARY}/fedora-epel}
    SR_MIRROR_EPEL=${SR_MIRROR_EPEL:-${SR_MIRROR_PRIMARY}::fedora-epel}

    SR_ARCH_DEBIAN=${SR_ARCH_DEBIAN:-amd64}
    SR_REPO_UBUNTU=${SR_REPO_UBUNTU:-${SR_REPO_PRIMARY}/ubuntu}
    SR_MIRROR_UBUNTU=${SR_MIRROR_UBUNTU:-${SR_MIRROR_PRIMARY}::ubuntu}
    SR_REPO_DEBIAN=${SR_REPO_DEBIAN:-${SR_REPO_PRIMARY}/debian}
    SR_MIRROR_DEBIAN=${SR_MIRROR_DEBIAN:-${SR_MIRROR_PRIMARY}::debian}

    SR_MIRROR_DEBIAN_SECURITY=${SR_MIRROR_DEBIAN_SECURITY:-security.debian.org}
    SR_REPO_DEBIAN_SECURITY=${SR_REPO_DEBIAN_SECURITY:-${SR_REPO_PRIMARY}/debian-security}

    SR_MIRROR_SECURITYONION=${SR_MIRROR_SECURITYONION:-ppa.launchpad.net}
    SR_REPO_SECURITYONION=${SR_REPO_SECURITYONION:-${SR_REPO_PRIMARY}/securityonion}

    SR_MIRROR_DOCKER=${SR_MIRROR_DOCKER:-download.docker.com}
    SR_REPO_DOCKER=${SR_REPO_DOCKER:-${SR_REPO_PRIMARY}/docker}

    SR_MIRROR_CLAMAV=${SR_MIRROR_CLAMAV:-database.clamav.net}
    SR_REPO_CLAMAV=${SR_REPO_CLAMAV:-${SR_REPO_PRIMARY}/clamav}

    [[ ${SR_FILE_CONFIG[*]} ]] || SR_FILE_CONFIG=(/etc/syncrepo{,/syncrepo}.conf)
    [[ ${SR_OPTS_RSYNC[*]} ]] ||
        SR_OPTS_RSYNC=(-hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file="$SR_FILE_LOG_PROGRESS")
    [[ ${SR_OPTS_TEE[*]} ]] || SR_OPTS_TEE=(tee -a "$SR_FILE_LOG_MAIN" "$SR_FILE_LOG_PROGRESS")

    # Source a config file if it exists (an environment file)
    # shellcheck disable=SC1090
    for file in "${SR_FILE_CONFIG[@]}"; do [[ -f $file ]] && source "$file"; done
}

# Parse command line options
syncrepo.parse_arguments() {
    [[ -n $1 ]] || {
        utils.say -h 'No arguments specified, use -h for help.'
        exit 1
    }

    while [[ -n $1 ]]; do
        if [[ $1 == -V ]]; then
            utils.say -h '%s: Version %s, updated %s by %s' \
                "$SR_META_BASENAME" "$SR_META_VERSION" "$SR_META_MODIFIED" "$SR_META_AUTHOR"
            SR_BOOL_SHOW_VERSION=true
            shift
        elif [[ $1 == -h ]]; then
            utils.say -h 'Software repository sync script for linux distros.'
            utils.say -h '\nCan curently sync the following components:'
            utils.say -h '  %s\n' "${SR_META_SOFTWARE[*]}"
            utils.say -h 'Usage:\n  %s [-V] (-h | -C)' "$SR_META_BASENAME"
            utils.say -h '  %s [-V] -y [-q|-v] [-d] [-m <mirror>] [-c <config_file>]' "$SR_META_BASENAME"
            utils.say -h '    [-l <log_file>] [-p <progress_log>])\n'
            utils.say -h 'Options:'
            utils.say -h '  -a|--arch         Specify architecture to sync.'
            utils.say -h '  -c|--config       Specify config file location.'
            utils.say -h '  -C|--config-dump  Dumps default values to a config file.'
            utils.say -h '  -d|--downstream   Set this mirror to be downstream.'
            utils.say -h '  -f|--force-dump   Overwrite config file when dumping.'
            utils.say -h '  -h|--help         Display this help message.'
            utils.say -h '  -l|--log-file     Specify log file location.'
            utils.say -h '  -p|--progress     Specify progress log location.'
            utils.say -h '  -m|--mirror       Specify upstream mirror.'
            utils.say -h '  -q|--quiet        Suppress console output.'
            utils.say -h '  -s|--sync         List of components to sync.'
            utils.say -h '  -v|--verbose     Verbose output to console.'
            utils.say -h '  -V|--version      Show the version info.'
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
        elif [[ $1 == -C ]]; then
            SR_BOOL_DUMP_CONFIG=true
            shift
        elif [[ $1 == -f ]]; then
            SR_BOOL_DUMP_CONFIG_FORCE=true
            shift
        elif [[ $1 == -q ]]; then
            SR_BOOL_QUIET=true
            shift
        elif [[ $1 == -v ]]; then
            # TODO: Implement verbose or remove this
            SR_BOOL_VERBOSE=true
            shift
        elif [[ $1 == -y ]]; then
            SR_BOOL_CONFIRMED=true
            shift
        else
            utils.say -h 'Invalid argument specified, use -h for help.'
            exit 1
        fi
    done

    # TODO: Move this to a function that mangles the names when dumping; adjust import logic
    [[ $SR_BOOL_DUMP_CONFIG == true ]] && {
        [[ -f ${SR_FILE_CONFIG[0]} && ! $SR_BOOL_DUMP_CONFIG_FORCE == true ]] && {
            utils.say -h 'Config file %s exists, use -f to overwrite.' "${SR_FILE_CONFIG[0]}"
            exit 1
        }
        set | awk '/^SR_[A-Z0-9_]+=/ && !/_(BOOL|META)_/' >"${SR_FILE_CONFIG[0]}"
        exit 0
    }

    [[ ! $SR_BOOL_CONFIRMED == true && $SR_BOOL_SHOW_VERSION == true ]] || {
        utils.say -h 'Confirm with -y to start the sync.'
        exit 1
    } && exit 0

    return 0
}

# Log message and print to stdout
# shellcheck disable=SC2059
utils.say() {
    export TERM=${TERM:-xterm}
    if [[ $1 == -h ]]; then
        local say_format=$2
        shift 2
        tput setaf 2
        printf "$say_format\\n" "$@"
    else
        if [[ $SR_FILE_LOG_MAIN == no || $1 == -n ]]; then
            [[ $1 == -n ]] && shift
        else
            local say_log=true
        fi
        [[ $1 == -t ]] && {
            echo >"$SR_FILE_LOG_PROGRESS"
            shift
        }
        if [[ $1 == info || $1 == warn || $1 == err ]]; then
            [[ $1 == info ]] && tput setaf 4
            [[ $1 == warn ]] && tput setaf 3
            [[ $1 == err ]] && tput setaf 1
            local say_format="${1^^}: $2"
            shift 2
        else
            local say_format="$1"
            shift
        fi
        if [[ $say_log == true ]]; then
            if [[ $SR_BOOL_QUIET == true ]]; then
                printf "%s: $say_format\\n" "$(date -u +%FT%TZ)" "$@" | "${SR_OPTS_TEE[@]}" >/dev/null
            else
                printf "%s: $say_format\\n" "$(date -u +%FT%TZ)" "$@" | "${SR_OPTS_TEE[@]}"
            fi
        else
            [[ $SR_BOOL_QUIET == true ]] || printf "%s: $say_format\\n" "$(date -u +%FT%TZ)" "$@"
        fi
    fi
    tput setaf 7 # For CentOS
    return 0
}

# Record time duration, concurrent timers
# shellcheck disable=SC2004
utils.timer() {
    [[ $1 =~ ^[0-9]+$ ]] && {
        [[ $timer_bookmark -ge $1 ]] || timer_bookmark=$1
        local timer_index=$1
        shift
    }
    [[ $1 == -n ]] && ((timer_bookmark++))
    [[ $1 == -p ]] && ((timer_bookmark--))
    [[ $1 == -c ]] && local timer_index=$timer_bookmark
    shift
    [[ -n $1 ]] || utils.say -n err 'No timer action specified.'
    [[ $1 == start ]] && timer_starttimes[$timer_index]=$SECONDS
    [[ $1 == stop ]] && {
        [[ -n ${timer_starttimes[$timer_index]} ]] || utils.say -n err 'Timer %s not started.' "$timer_index"
        timer_stoptimes[$timer_index]=$SECONDS
        timer_durations[$timer_index]=$((timer_stoptimes[timer_index] - timer_starttimes[timer_index]))
    }
    [[ $1 == show ]] && {
        [[ -n ${timer_stoptimes[$timer_index]} ]] ||
            timer_durations[$timer_index]=$((SECONDS - timer_starttimes[timer_index]))
        echo "${timer_durations[$timer_index]}"
    }
    return 0
}

# Construct the sync environment
syncrepo.build_vars() {
    IFS=,
    # Declare more variables (CentOS/EPEL)
    [[ $SR_SYNC_CENTOS == true || $SR_SYNC_EPEL == true || $SR_SYNC_DOCKER == true ]] && {
        mapfile -t rhel_all_releases <<<"$(
            rsync "$SR_MIRROR_CENTOS" |
                awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}' |
                sort -V
        )"
        mapfile -t rhel_previous_releases <<<"$(
            for i in "${rhel_all_releases[@]}"; do
                [[ ${i%%.*} -eq $((${rhel_all_releases[-1]%%.*} - 1)) ]] && echo "$i"
            done
        )"
        rhel_current_release=${rhel_all_releases[-1]}
        rhel_current_major_version=${rhel_current_release%%.*}
        rhel_current_release_last=${rhel_all_releases[-2]}
        rhel_previous_release=${rhel_previous_releases[-1]}
        rhel_previous_major_version=${rhel_previous_release%%.*}
        rhel_previous_release_last=${rhel_previous_releases[-2]}

        rhel_filter_rsync=(
            --include={os,BaseOS,AppStream,extras,updates,centosplus,fasttrack,readme}
            --include={os/$SR_ARCH_RHEL,{BaseOS,AppStream}/$SR_ARCH_RHEL/os}/{repodata,Packages}
            --exclude={aarch64,i386,ppc64le,{os/$SR_ARCH_RHEL,{BaseOS,AppStream}/$SR_ARCH_RHEL{,/os}}/*,/*}
        )
        epel_filter_rsync=(--exclude={SRPMS,aarch64,i386,ppc64,ppc64le,s390x,$SR_ARCH_RHEL/debug})

        docker_sync_args=(wget -m -np -N -nH -r --cut-dirs=1 -R index.html -P "$SR_REPO_PRIMARY/docker/")
        docker_sync_args+=("$SR_MIRROR_DOCKER/linux/centos/$rhel_current_major_version/$SR_ARCH_RHEL/stable/")
    }

    # Declare more variables (Debian/Ubuntu)
    [[ $SR_SYNC_UBUNTU == true || $SR_SYNC_SECURITYONION == true || $SR_SYNC_DOCKER == true ]] && {
        mapfile -t ubuntu_all_releases <<<"$(
            curl -sL "$SR_MIRROR_PRIMARY/ubuntu-releases/HEADER.html" |
                awk -F '(' '/<li.+>/ && /LTS/ && match($2, /[[:alpha:]]+/, a) {print a[0]}'
        )"
        ubuntu_current_release=${ubuntu_all_releases[0],}
        ubuntu_previous_release=${ubuntu_all_releases[1],}

        ubuntu_components=(main restricted universe multiverse)
        ubuntu_repos=({$ubuntu_previous_release,$ubuntu_current_release}{,-backports,-updates,-proposed,-security})
        ubuntu_sync_args=(-s "${ubuntu_components[*]}" -d "${ubuntu_repos[*]}" -h "$SR_MIRROR_PRIMARY" -r /ubuntu)

        securityonion_sync_args=(-s main -d "$ubuntu_previous_release,$ubuntu_current_release")
        securityonion_sync_args+=(-h "$SR_MIRROR_SECURITYONION" --rsync-extra=none -r /securityonion/stable/ubuntu)

        docker_sync_args_ubuntu=(-s stable -d "$ubuntu_previous_release,$ubuntu_current_release")
        docker_sync_args_ubuntu+=(-h "$SR_MIRROR_DOCKER" --rsync-extra=none -r /linux/ubuntu)
    }

    [[ $SR_SYNC_DEBIAN == true || $SR_SYNC_DEBIAN_SECURITY == true || $SR_SYNC_DOCKER == true ]] && {
        mapfile -t debian_all_releases <<<"$(
            curl -sL "$SR_MIRROR_PRIMARY/debian/README.html" |
                awk -F '[<> ]' '/<dt>/ && /Debian/ {print $9}'
        )"
        debian_current_release=${debian_all_releases[0]}
        debian_previous_release=${debian_all_releases[1]}

        debian_components=(main contrib non-free)
        debian_repos=({$debian_previous_release,$debian_current_release}{,-backports,-updates,-proposed-updates})
        debian_sync_args=(-s "${debian_components[*]}" -d "${debian_repos[*]}" -h "$SR_MIRROR_PRIMARY" -r /debian)

        debian_repos_security=({$debian_current_release,$debian_previous_release}/updates)
        debian_sync_args_security=(-s "${debian_components[*]}" -d "${debian_repos_security[*]}")
        debian_sync_args_security+=(-h "$SR_MIRROR_DEBIAN_SECURITY" -r /)

        docker_sync_args_debian=(-s stable -d "$debian_previous_release,$debian_current_release")
        docker_sync_args_debian+=(-h "$SR_MIRROR_DOCKER" --rsync-extra=none -r /linux/debian)
    }

    [[ $SR_SYNC_UBUNTU == true || $SR_SYNC_DEBIAN == true || $SR_SYNC_DEBIAN_SECURITY == true ||
        $SR_SYNC_SECURITYONION == true || $SR_SYNC_DOCKER == true ]] && {
        tool_args_debmirror1=(debmirror -a "$SR_ARCH_DEBIAN" --no-source --ignore-small-errors)
        tool_args_debmirror1+=(--method=rsync --retry-rsync-packages=5 -p "--rsync-options='${SR_OPTS_RSYNC[*]}'")
        tool_args_debmirror2=(debmirror -a "$SR_ARCH_DEBIAN" --no-source --ignore-small-errors)
        tool_args_debmirror2+=(--method=http --checksums -p)
        tool_args_debmirror3=(debmirror -a "$SR_ARCH_DEBIAN" --no-source --ignore-small-errors)
        tool_args_debmirror3+=(--method=https --checksums -p)
    }

    # And a few more (ClamAV)
    [[ $SR_SYNC_CLAMAV == true ]] &&
        tool_args_clamavmirror=(clamavmirror -a "$SR_MIRROR_CLAMAV" -d "$SR_REPO_CLAMAV")
        tool_args_clamavmirror+=(-u "$SR_REPO_CHOWN_UID" -g "$SR_REPO_CHOWN_GID")

    IFS=' '
    return 0
}

syncrepo.sync_centos() {
    local repo
    for repo in $rhel_previous_release $rhel_current_release; do
        # Check for centos release directory
        [[ -d $SR_REPO_CENTOS/$repo ]] || mkdir -p "$SR_REPO_CENTOS/$repo"

        # Sync current centos repository
        utils.say 'Beginning sync of CentOS %s repository from %s.' \
            "$repo" "$SR_MIRROR_CENTOS"
        rsync "${SR_OPTS_RSYNC[@]}" "${rhel_filter_rsync[@]}" "$SR_MIRROR_CENTOS/$repo/" "$SR_REPO_CENTOS/$repo/"
        utils.say 'Done.\n'

        # Create the symlink, or move, if necessary
        [[ -L ${repo%%.*} && $(readlink "${repo%%.*}") == "$repo" ]] ||
            ln -frsn "$SR_REPO_CENTOS/$repo" "$SR_REPO_CENTOS/${repo%%.*}"
    done

    # Continue to sync previous point releases til they're empty
    for repo in $rhel_previous_release_last $rhel_current_release_last; do
        # Check for release directory
        [[ -d $SR_REPO_CENTOS/$repo ]] || mkdir -p "$SR_REPO_CENTOS/$repo"

        # Check for point release placeholder
        [[ -f $SR_REPO_CENTOS/$repo/readme ]] || {
            # Sync previous centos repository
            utils.say 'Beginning sync of CentOS %s repository from %s.' \
                "$repo" "$SR_MIRROR_CENTOS"
            rsync "${SR_OPTS_RSYNC[@]}" "${rhel_filter_rsync[@]}" "$SR_MIRROR_CENTOS/$repo/" "$SR_REPO_CENTOS/$repo/"
            utils.say 'Done.\n'
        }
    done

    return 0
}

syncrepo.sync_epel() {
    local repo
    for repo in {,testing/}{$rhel_previous_major_version,$rhel_current_major_version}; do
        # Check for epel release directory
        [[ -d $SR_REPO_EPEL/$repo ]] || mkdir -p "$SR_REPO_EPEL/$repo"

        # Sync epel repository
        utils.say 'Beginning sync of EPEL %s repository from %s.' "$repo" "$SR_MIRROR_EPEL"
        rsync "${SR_OPTS_RSYNC[@]}" "${epel_filter_rsync[@]}" "$SR_MIRROR_EPEL/$repo/" "$SR_REPO_EPEL/$repo/"
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
        "${ubuntu_previous_release^}" "${ubuntu_current_release^}" "$SR_MIRROR_UBUNTU"
    "${tool_args_debmirror2[@]}" "${ubuntu_sync_args[@]}" "$SR_REPO_UBUNTU" &>>"$SR_FILE_LOG_PROGRESS"
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
        "${debian_previous_release^}" "${debian_current_release^}" "$SR_MIRROR_DEBIAN"
    "${tool_args_debmirror2[@]}" "${debian_sync_args[@]}" "$SR_REPO_DEBIAN" &>>"$SR_FILE_LOG_PROGRESS"
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_debian_security() {
    export GNUPGHOME=$SR_REPO_PRIMARY/.gpg

    # Check for debian security directory
    [[ -d $SR_REPO_DEBIAN_SECURITY ]] || mkdir -p "$SR_REPO_DEBIAN_SECURITY"

    # Sync debian security repository
    utils.say 'Beginning sync of Debian %s and %s Security repositories from %s.' \
        "${debian_previous_release^}" "${debian_current_release^}" "$SR_MIRROR_DEBIAN_SECURITY"
    "${tool_args_debmirror2[@]}" "${debian_sync_args_security[@]}" "$SR_REPO_DEBIAN_SECURITY" &>>"$SR_FILE_LOG_PROGRESS"
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_securityonion() {
    export GNUPGHOME=$SR_REPO_PRIMARY/.gpg

    # Check for security onion directory
    [[ -d $SR_REPO_SECURITYONION ]] || mkdir -p "$SR_REPO_SECURITYONION"

    # Sync security onion repository
    utils.say 'Beginning sync of Security Onion %s and %s repositories from %s.' \
        "${ubuntu_previous_release^}" "${ubuntu_current_release^}" "$SR_MIRROR_SECURITYONION"
    "${tool_args_debmirror2[@]}" "${securityonion_sync_args[@]}" "$SR_REPO_SECURITYONION" &>>"$SR_FILE_LOG_PROGRESS"
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
            "${ubuntu_current_release^}" "$SR_MIRROR_DOCKER"
        "${docker_sync_args[@]}" &>>"$SR_FILE_LOG_PROGRESS"
        utils.say 'Done.\n'
    }

    [[ $SR_SYNC_UBUNTU == true ]] && {
        utils.say 'Beginning sync of Docker Ubuntu %s and %s repositories from %s.' \
            "${ubuntu_previous_release^}" "${ubuntu_current_release^}" "$SR_MIRROR_DOCKER"
        "${tool_args_debmirror3[@]}" "${docker_sync_args_ubuntu[@]}" "$SR_REPO_DOCKER/ubuntu" &>>"$SR_FILE_LOG_PROGRESS"
        utils.say 'Done.\n'
    }

    [[ $SR_SYNC_DEBIAN == true ]] && {
        utils.say 'Beginning sync of Docker Debian %s and %s repositories from %s.' \
            "${debian_previous_release^}" "${debian_current_release^}" "$SR_MIRROR_DOCKER"
        "${tool_args_debmirror3[@]}" "${docker_sync_args_debian[@]}" "$SR_REPO_DOCKER/debian" &>>"$SR_FILE_LOG_PROGRESS"
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
    "${tool_args_clamavmirror[@]}" &>>"$SR_FILE_LOG_PROGRESS"
    utils.say 'Done.\n'

    return 0
}

syncrepo.sync_downstream() {
    local repo package_list
    utils.say 'Configured as downstream, so mirroring local upstream.'

    [[ -n $SR_MIRROR_UPSTREAM ]] || {
        utils.say err 'SR_MIRROR_UPSTREAM is empty or not set.'
        exit 1
    }

    # Build array of repos to sync downstream
    [[ $SR_SYNC_CENTOS          == true ]] && package_list+=(centos)
    [[ $SR_SYNC_EPEL            == true ]] && package_list+=(fedora-epel)
    [[ $SR_SYNC_UBUNTU          == true ]] && package_list+=(ubuntu)
    [[ $SR_SYNC_DEBIAN          == true ]] && package_list+=(debian)
    [[ $SR_SYNC_DEBIAN_SECURITY == true ]] && package_list+=(debian-security)
    [[ $SR_SYNC_SECURITYONION   == true ]] && package_list+=(securityonion)
    [[ $SR_SYNC_DOCKER          == true ]] && package_list+=(docker)
    [[ $SR_SYNC_CLAMAV          == true ]] && package_list+=(clamav)
    [[ $SR_SYNC_LOCAL           == true ]] && package_list+=(local)

    [[ -n ${package_list[*]} ]] || {
        utils.say err 'No repos enabled for sync.'
        exit 1
    }

    # For every enabled repo
    for repo in "${package_list[@]}"; do
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
    utils.say 'Started synchronization of repositories: %s' "${SR_META_SOFTWARE[*]}"
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
            [[ $SR_SYNC_CENTOS          == true ]] && syncrepo.sync_centos
            [[ $SR_SYNC_EPEL            == true ]] && syncrepo.sync_epel
            [[ $SR_SYNC_UBUNTU          == true ]] && syncrepo.sync_ubuntu
            [[ $SR_SYNC_DEBIAN          == true ]] && syncrepo.sync_debian
            [[ $SR_SYNC_DEBIAN_SECURITY == true ]] && syncrepo.sync_debian_security
            [[ $SR_SYNC_SECURITYONION   == true ]] && syncrepo.sync_securityonion
            [[ $SR_SYNC_DOCKER          == true ]] && syncrepo.sync_docker
            [[ $SR_SYNC_CLAMAV          == true ]] && syncrepo.sync_clamav
            [[ $SR_SYNC_LOCAL           == true ]] && syncrepo.sync_local
        else
            # Do a downstream sync
            SR_MIRROR_UPSTREAM=${SR_MIRROR_UPSTREAM:-$SR_MIRROR_PRIMARY} && syncrepo.sync_downstream
        fi

        # Fix ownership of files
        utils.say 'Normalizing repository file permissions.'
        chown -R "$SR_REPO_CHOWN_UID:$SR_REPO_CHOWN_GID" "$SR_REPO_PRIMARY"

        # Clear the lockfile
        rm -f "$SR_FILE_LOCKFILE"
    fi

    # Now we're done
    utils.timer stop
    utils.say 'Completed synchronization of repositories: %s' "${SR_META_SOFTWARE[*]}"
    utils.say 'Total duration: %d seconds. Current repository size: %s.\n' \
        "$(utils.timer show)" "$(du -hs "$SR_REPO_PRIMARY" | awk '{print $1}')"
    exit 0
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && syncrepo.main "$@"
