#!/bin/bash
# Repository sync script for CentOS & Debian distros
# This script can sync the repos listed in $SR_META_SOFTWARE

# TODO: Implement support for Rocky (and maybe Alma)
# TODO: Implement support for RHEL based SecurityOnion
# TODO: Implement Docker registry sync logic (also podman registry)

# Initialize global config variables
syncrepo.set_globals() {
    SR_META_AUTHOR='AfroThundr'
    SR_META_BASENAME="${0##*/}"
    SR_META_MODIFIED='20240309'
    SR_META_VERSION='1.8.0-rc8'
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

    return 0
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
            utils.say -h 'Usage:\n  %s [-V] (-h | -C [-f] [-c <config_file>])' "$SR_META_BASENAME"
            utils.say -h '  %s [-V] -y [-q|-v] [-d] [-m <mirror>] [-c <config_file>]' "$SR_META_BASENAME"
            utils.say -h '    [-l <log_file>] [-p <progress_log>]\n'
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
            utils.say -h '  -v|--verbose     Verbose output to console.'
            utils.say -h '  -V|--version      Show the version info.'
            utils.say -h '  -y|--yes          Confirm the repository sync.'
            utils.say -h '\nYou can explicitly enable components with the following:'
            utils.say -h '  --sync-all        Sync all available components.'
            utils.say -h '  --sync-centos     Sync the CentOS repo.'
            utils.say -h '  --sync-clamav     Sync the ClamAV repo.'
            utils.say -h '  --sync-debian     Sync the Debian repo.'
            utils.say -h '  --sync-debsec     Sync the Debian Secuirty repo.'
            utils.say -h '  --sync-epel       Sync the EPEL repo.'
            utils.say -h '  --sync-local      Sync a locally built repo.'
            utils.say -h '  --sync-sonion     Sync the Security Onion repo.'
            utils.say -h '  --sync-ubuntu     Sync the Ubuntu repo.'
            exit 0
        elif [[ $1 == -c ]]; then
            SR_META_CONFIG_MANUAL=$2
            shift 2
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
            : SR_BOOL_VERBOSE=true
            shift
        elif [[ $1 == -y ]]; then
            SR_BOOL_CONFIRMED=true
            shift
        else
            utils.say -h 'Invalid argument specified, use -h for help.'
            exit 1
        fi
    done

    [[ $SR_BOOL_DUMP_CONFIG == true ]] && {
        syncrepo.dump_config && exit 0 || exit 1
    }

    [[ ! $SR_BOOL_CONFIRMED == true ]] && {
        [[ $SR_BOOL_SHOW_VERSION == true ]] && exit 0
        utils.say -h 'Confirm with -y to start the sync.'
        exit 1
    }

    return 0
}

# Write config file do disk
syncrepo.dump_config() {
    local file=${SR_META_CONFIG_MANUAL:-${SR_FILE_CONFIG[0]}}
    [[ -f $file && ! $SR_BOOL_DUMP_CONFIG_FORCE == true ]] && {
        utils.say -h 'Config file %s exists, use -f to overwrite.' "$file"
        return 1
    }
    utils.say -h 'Writing configuration to: %s' "$file"
    set | awk '/^SR_/ && !/_(BOOL|META)_/ {gsub(/^SR_/,"SR_CFG_"); print $0}' >"$file"
    return 0
}

# Read settings from config file
# shellcheck disable=SC1090
syncrepo.parse_config() {
    local file files=("${SR_META_CONFIG_MANUAL:-${SR_FILE_CONFIG[@]}}")
    for file in "${files[@]}"; do
        [[ -s $file ]] && {
            utils.say -h 'Reading configuration from: %s' "$file"
            source <(awk '/^SR_CFG_/ && !/_(BOOL|META)_/ {gsub(/^SR_CFG_/,"SR_"); print $0}' "$file")
        }
    done
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
            : >"$SR_FILE_LOG_PROGRESS"
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
    # TODO: Test the tput combinations on multiple distros
    tput setaf 7 # For CentOS
    return 0
}

# Record time duration, concurrent timers
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
    [[ $1 == start ]] && timer_starttimes[timer_index]=$SECONDS
    [[ $1 == stop ]] && {
        [[ -n ${timer_starttimes[timer_index]} ]] || utils.say -n err 'Timer %s not started.' "$timer_index"
        timer_stoptimes[timer_index]=$SECONDS
        timer_durations[timer_index]=$((timer_stoptimes[timer_index] - timer_starttimes[timer_index]))
    }
    [[ $1 == show ]] && {
        [[ -n ${timer_stoptimes[timer_index]} ]] ||
            timer_durations[timer_index]=$((SECONDS - timer_starttimes[timer_index]))
        utils.say -h "${timer_durations[timer_index]}"
    }
    return 0
}

# Use wget to sync remote and local directory
# WIP: finish wget_rsync()
utils.wget_rsync() {
    local delete delta_add delta_remove local_dir local_files
    local number_dirs remote_dir remote_files wget_mirror wget_spider
    [[ $1 == -d ]] && {
        delete=true
        shift
    }
    [[ -n $1 && -n $2 ]] || utils.say -n err 'Must supply remote and local directory.'
    remote_dir=$1
    local_dir=$2
    # WIP: This can be done with one awk regex
    [[ -n ${remote_dir##*/} ]] && # Does it have trailing slash?
        number_dirs=$(printf '%s\n' "${remote_dir#*://*/}" | awk -F'/' '{print NF-1}') ||
        number_dirs=$(printf '%s\n' "${remote_dir#*://*/}" | awk -F'/' '{print NF}')
    # Spiders remote to collect file list
    wget_spider=(wget --spider -np -nH -r --cut-dirs="$number_dirs" -r index.html -P "$local_dir" "$remote_dir")
    # Mirrors files on remote list if not local
    wget_mirror=(wget -c -N -np -nH -r --cut-dirs="$number_dirs" -r index.html -P "$local_dir" "$remote_dir")

    # Strip host, and $number_dirs directories
    mapfile -t remote_files <<<"$(
        "${wget_spider[@]}" 2>&1 | awk -v ndirs="$number_dirs" \
            '/^--/ && /[^/]$/ {
            match($0,/^.*:\/\/[^/]*\/(.*)$/,a);
            print substr($0,) # Trim $remote_dir
            print a[1]
        }'
    )"
    mapfile -t local_files <<<"$(
        find "$local_dir" -type f |
            : # WIP: Trim $local_dir
    )"

    # Compare remote list with local list
    # WIP: Figure out the diff/comp options to return only left or right side differences
    mapfile -t delta_add <<<"$(diff <("${remote_files[@]}") <("${local_files[@]}"))"
    mapfile -t delta_remove <<<"$(diff <("${remote_files[@]}") <("${local_files[@]}"))"

    # Sync down the deltas (need to investigate size differences?)
    # NOTE: Maybe use here document to avoid command length limit)
    "${wget_mirror[@]}" -- "${delta_add[@]}"

    # Remove local files not on remote (optional)
    # NOTE: Probably also need to use a here document for this
    [[ $delete ]] && : rm -f "${delta_remove[@]}"

    return 0
}

# Construct the sync environment
syncrepo.build_vars() {
    IFS=,
    # Declare more variables (CentOS/EPEL)
    [[ $SR_SYNC_CENTOS == true || $SR_SYNC_EPEL == true || $SR_SYNC_DOCKER == true ]] && {
        mapfile -t rhel_all_releases <<<"$(
            rsync "$SR_MIRROR_CENTOS" |
                awk '/^d/ && /[0-9]+\.[0-9.]+$/ {print $5}'
        )"
        mapfile -t rhel_previous_releases <<<"$(
            printf '%s\n' "${rhel_all_releases[@]}" |
                awk -v m="^$((${rhel_all_releases[-1]%%.*} - 1))" '$0 ~ m'
        )"
        rhel_current_release=${rhel_all_releases[-1]}
        rhel_current_release_last=${rhel_all_releases[-2]}
        rhel_previous_release=${rhel_previous_releases[-1]}
        rhel_previous_release_last=${rhel_previous_releases[-2]}

        rhel_filter_rsync=(
            --include={os,BaseOS,AppStream,extras,updates,centosplus,fasttrack,readme}
            --include={os/$SR_ARCH_RHEL,{BaseOS,AppStream}/$SR_ARCH_RHEL/os}/{repodata,Packages}
            --exclude={aarch64,i386,ppc64le,{os/$SR_ARCH_RHEL,{BaseOS,AppStream}/$SR_ARCH_RHEL{,/os}}/*,/*}
        )
        epel_filter_rsync=(--exclude={SRPMS,aarch64,i386,ppc64,ppc64le,s390x,$SR_ARCH_RHEL/debug})

        docker_sync_args=(wget -m -np -N -nH -r --cut-dirs=1 -R index.html -P "$SR_REPO_PRIMARY/docker/")
        docker_sync_args+=("$SR_MIRROR_DOCKER/linux/centos/${rhel_current_release%%.*}/$SR_ARCH_RHEL/stable/")
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
    [[ $SR_SYNC_CLAMAV == true ]] && {
        tool_args_clamavmirror=(clamavmirror -a "$SR_MIRROR_CLAMAV" -d "$SR_REPO_CLAMAV")
        tool_args_clamavmirror+=(-u "$SR_REPO_CHOWN_UID" -g "$SR_REPO_CHOWN_GID")
    }

    IFS=' '
    return 0
}

# Ensure environment is ready for sync
# WIP: finish sanity_check()
# NOTE: Connectivity checks for all mirrors
# NOTE: Repo dir size/mount/permission checks
# NOTE: Dependency checks for all binaries
# NOTE: Catch nonsensical configuration issues
syncrepo.sanity_check() {
    # Check if the rsync script is already running
    if [[ -f $SR_FILE_LOCKFILE ]]; then
        utils.say err 'Detected lockfile: %s' "$SR_FILE_LOCKFILE"
        utils.say err 'Repository updates are already running.'
        exit 1
    fi

    # Check that we can reach the public mirror
    if ([[ $SR_BOOL_UPSTREAM == true ]] && ! rsync "${SR_MIRROR_PRIMARY}::" &>/dev/null) ||
        ([[ $SR_BOOL_UPSTREAM == false ]] && ! rsync "${SR_MIRROR_UPSTREAM}::" &>/dev/null); then
        utils.say err 'Cannot reach the %s mirror server.' "$SR_MIRROR_PRIMARY"
        exit 1
    fi

    # Check that the repository is mounted
    if ! mount | grep "$SR_REPO_PRIMARY" &>/dev/null; then
        utils.say err 'Directory %s is not mounted.' "$SR_REPO_PRIMARY"
        exit 1
    fi

    # TODO: Dig through the other functions and move their checks here

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
        rsync "${SR_OPTS_RSYNC[@]}" "${rhel_filter_rsync[@]}" \
            "$SR_MIRROR_CENTOS/$repo/" "$SR_REPO_CENTOS/$repo/"
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
            rsync "${SR_OPTS_RSYNC[@]}" "${rhel_filter_rsync[@]}" \
                "$SR_MIRROR_CENTOS/$repo/" "$SR_REPO_CENTOS/$repo/"
            utils.say 'Done.\n'
        }
    done

    return 0
}

syncrepo.sync_epel() {
    local repo
    for repo in {,testing/}{${rhel_previous_release%%.*},${rhel_current_release%%.*}}; do
        # Check for epel release directory
        [[ -d $SR_REPO_EPEL/$repo ]] || mkdir -p "$SR_REPO_EPEL/$repo"

        # Sync epel repository
        utils.say 'Beginning sync of EPEL %s repository from %s.' \
            "$repo" "$SR_MIRROR_EPEL"
        rsync "${SR_OPTS_RSYNC[@]}" "${epel_filter_rsync[@]}" \
            "$SR_MIRROR_EPEL/$repo/" "$SR_REPO_EPEL/$repo/"
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
    "${tool_args_debmirror2[@]}" "${ubuntu_sync_args[@]}" \
        "$SR_REPO_UBUNTU" &>>"$SR_FILE_LOG_PROGRESS"
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
    "${tool_args_debmirror2[@]}" "${debian_sync_args[@]}" \
        "$SR_REPO_DEBIAN" &>>"$SR_FILE_LOG_PROGRESS"
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
    "${tool_args_debmirror2[@]}" "${debian_sync_args_security[@]}" \
        "$SR_REPO_DEBIAN_SECURITY" &>>"$SR_FILE_LOG_PROGRESS"
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
    "${tool_args_debmirror2[@]}" "${securityonion_sync_args[@]}" \
        "$SR_REPO_SECURITYONION" &>>"$SR_FILE_LOG_PROGRESS"
    utils.say 'Done.\n'

    unset GNUPGHOME
    return 0
}

syncrepo.sync_docker() {
    export GNUPGHOME=$SR_REPO_PRIMARY/.gpg

    # Check for docker directory
    [[ -d $SR_REPO_DOCKER ]] || mkdir -p "$SR_REPO_DOCKER"

    # Sync docker repository (for each enabled OS)
    # TODO: Use wget_rsync() instead of a regular clone

    [[ $SR_SYNC_CENTOS == true ]] && {
        utils.say 'Beginning sync of Docker Centos %s repository from %s.' \
            "${ubuntu_current_release^}" "$SR_MIRROR_DOCKER"
        "${docker_sync_args[@]}" &>>"$SR_FILE_LOG_PROGRESS"
        utils.say 'Done.\n'
    }

    [[ $SR_SYNC_UBUNTU == true ]] && {
        utils.say 'Beginning sync of Docker Ubuntu %s and %s repositories from %s.' \
            "${ubuntu_previous_release^}" "${ubuntu_current_release^}" "$SR_MIRROR_DOCKER"
        "${tool_args_debmirror3[@]}" "${docker_sync_args_ubuntu[@]}" \
            "$SR_REPO_DOCKER/ubuntu" &>>"$SR_FILE_LOG_PROGRESS"
        utils.say 'Done.\n'
    }

    [[ $SR_SYNC_DEBIAN == true ]] && {
        utils.say 'Beginning sync of Docker Debian %s and %s repositories from %s.' \
            "${debian_previous_release^}" "${debian_current_release^}" "$SR_MIRROR_DOCKER"
        "${tool_args_debmirror3[@]}" "${docker_sync_args_debian[@]}" \
            "$SR_REPO_DOCKER/debian" &>>"$SR_FILE_LOG_PROGRESS"
        utils.say 'Done.\n'
    }

    unset GNUPGHOME
    return 0
}

syncrepo.sync_clamav() {
    # Check for clamav directory
    [[ -d $SR_REPO_CLAMAV ]] || mkdir -p "$SR_REPO_CLAMAV"

    # Sync clamav repository
    # TODO: Replace with wget_rsync()
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

    # Read config file
    syncrepo.parse_config

    # Process arguments
    syncrepo.parse_arguments "$@"

    syncrepo.sanity_check && {
        # If evrything is good, begin the sync
        utils.say -t 'Progress log reset.'
        utils.say 'Started synchronization of repositories: %s' "${SR_META_SOFTWARE[*]}"
        utils.say 'Use tail -f %s to view progress.' "$SR_FILE_LOG_PROGRESS"
        utils.timer start

        # There can be only one...
        touch "$SR_FILE_LOCKFILE"

        # Are we upstream?
        if [[ $SR_BOOL_UPSTREAM == true ]]; then
            # Generate variables
            syncrepo.build_vars

            # Sync every enabled repo
            # WIP: Maybe move these guards inside their respective functions
            #   Then we could remove sync_downstream and inline that too
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
            # TODO: This should probably be empty until set by the user
            SR_MIRROR_UPSTREAM=${SR_MIRROR_UPSTREAM:-$SR_MIRROR_PRIMARY} && syncrepo.sync_downstream
        fi

        # Fix ownership of files
        utils.say 'Normalizing repository file permissions.'
        chown -R "$SR_REPO_CHOWN_UID:$SR_REPO_CHOWN_GID" "$SR_REPO_PRIMARY"

        # Clear the lockfile
        rm -f "$SR_FILE_LOCKFILE"

        # Now we're done
        utils.timer stop
        utils.say 'Completed synchronization of repositories: %s' "${SR_META_SOFTWARE[*]}"
        utils.say 'Total duration: %d seconds. Current repository size: %s.\n' \
            "$(utils.timer show)" "$(du -hs "$SR_REPO_PRIMARY" | awk '{print $1}')"
    }

    exit 0
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && syncrepo.main "$@"
