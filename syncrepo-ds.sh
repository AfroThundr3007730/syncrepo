#!/bin/bash
# Repository sync script for CentOS & Debian distros
# This script can sync the repos listed in $SOFTWARE

# Gotta keep the namespace clean
set_globals() {
    AUTHOR='AfroThundr'
    BASENAME="${0##*/}"
    MODIFIED='20181203'
    VERSION='1.7.0-rc2~ds'
    
    SOFTWARE='CentOS, EPEL, Debian, Ubuntu, Security Onion, and ClamAV'
    
    # Global config variables (modify as necessary)
    CENTOS_SYNC=true
    EPEL_SYNC=true
    UBUNTU_SYNC=true
    DEBIAN_SYNC=true
    DEBSEC_SYNC=true
    SONION_SYNC=true
    CLAMAV_SYNC=true
    LOCAL_SYNC=true
    
    REPODIR=/srv/repository
    LOCKFILE=/var/lock/subsys/syncrepo
    LOGFILE=/var/log/syncsync.log
    PROGFILE=/var/log/syncrepo_progress.log
    
    # More internal config variables
    MIRROR=yum-us.lab.local
    ROPTS="-hlmprtzDHS --stats --no-motd --del --delete-excluded --log-file=$PROGFILE"
    TEELOG="tee -a $LOGFILE $PROGFILE"
}

argument_handler() {
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
say() {
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
        [[ $1 == -t ]] && (echo > $PROGFILE; shift)
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
    [[ $CENTOS_SYNC == true ]] && PACKAGES+=( centos )
    [[ $EPEL_SYNC   == true ]] && PACKAGES+=( fedora-epel )
    [[ $UBUNTU_SYNC == true ]] && PACKAGES+=( ubuntu )
    [[ $DEBIAN_SYNC == true ]] && PACKAGES+=( debian )
    [[ $DEBSEC_SYNC == true ]] && PACKAGES+=( debian-security )
    [[ $SONION_SYNC == true ]] && PACKAGES+=( securityonion )
    [[ $CLAMAV_SYNC == true ]] && PACKAGES+=( clamav )
    [[ $LOCAL_SYNC  == true ]] && PACKAGES+=( local )
}

# Where the magic happens
# shellcheck disable=SC2086
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
        exit 10
        
        # Check that we can reach the public mirror
        elif ! rsync ${MIRROR}:: &>/dev/null; then
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
        
        # For every enabled repo
        for repo in "${PACKAGES[@]}"; do
            # Sync the upstream repository
            say 'Beginning sync of %s repository from %s.' "$repo" "$MIRROR"
            rsync $ROPTS "$MIRROR::$repo/" "$REPODIR/$repo/"
            say 'Done.\n'
        done
        
        # Fix ownership of files
        say 'Normalizing repository file permissions.'
        chown -R root:www-data $REPODIR
        
        # Clear the lockfile
        rm -f "$LOCKFILE"
    fi
    
    # Now we're done
    say 'Completed synchronization of %s repositories.\n' "$SOFTWARE"
    exit 0
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
