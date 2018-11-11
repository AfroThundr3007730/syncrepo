Below are configuration files for creating upstream and downstream yum and apt repositories.
These can be hosted on a CentOS, Debian, or Ubuntu system and served via rsync or http.
The only requirements are rsync and a webserver, such as apache, and also debmirror.

Filename               | Description
---                    | ---
`repoupdate.sh`        | (ALPHA) Combined all-in-one repo sync script.
`yum-repoupdate-us.sh` | Upstream yum repository updater script.
`yum-repoupdate-ds.sh` | Downstream yum repository updater script.
`apt-repoupdate-us.sh` | Upstream apt repository updater script.
`apt-repoupdate-ds.sh` | Downstream apt repository updater script.
`repoupdate.service`   | Systemd service unit for repoupdate script.
`repoupdate.timer`     | Systemd timer unit for repoupdate script.
`yum-rsyncd.conf`      | Rsync config for yum repository.
`apt-rsyncd.conf`      | Rsync config for apt repository.
`rsyncd.service`       | Systemd service unit for rsyncd service.
`yum-vhost.conf`       | Apache vhost config for yum repository.
`apt-vhost.conf`       | Apache vhost config for apt repository.
`centos-local.repo`    | Centos package config for clients.
`debian-sources.list`  | Debian package sources for clients.
`ubuntu-sources.list`  | Ubuntu package sources for clients.
`repoupdate-log.conf`  | Logrotate config file.
`debmirror.pl`         | Debmirror perl script provided for convenience.
`clamavmirror.py`      | ClamAV mirror python script provided for convenience.
