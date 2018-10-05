Below are configuration files for creating upstream and downstream yum and apt repositories.
These can be hosted on a CentOS, Debian, or Ubuntu system and served via rsync or http.
The only requirements are rsync and a webserver, such as apache, and also debmirror.

Filename | Description
---|---
[`01-yum-repoupdate-us.sh`](#file-01-yum-repoupdate-us-sh) | Upstream yum repository updater script.
[`02-yum-repoupdate-ds.sh`](#file-02-yum-repoupdate-ds-sh) | Downstream yum repository updater script.
[`03-apt-repoupdate-us.sh`](#file-03-apt-repoupdate-us-sh) | Upstream apt repository updater script.
[`04-apt-repoupdate-ds.sh`](#file-04-apt-repoupdate-ds-sh) | Downstream apt repository updater script.
[`05-repoupdate.service`](#file-05-repoupdate-service) | Systemd service unit for repoupdate script.
[`06-repoupdate.timer`](#file-06-repoupdate-timer) | Systemd timer unit for repoupdate script.
[`07-yum-rsyncd.conf`](#file-07-yum-rsyncd-conf) | Rsync config for yum repository.
[`08-apt-rsyncd.conf`](#file-08-apt-rsyncd-conf) | Rsync config for apt repository.
[`09-rsyncd.service`](#file-09-rsyncd-service) | Systemd service unit for rsyncd service.
[`10-yum-vhost.conf`](#file-10-yum-vhost-conf) | Apache vhost config for yum repository.
[`11-apt-vhost.conf`](#file-11-apt-vhost-conf) | Apache vhost config for apt repository.
[`12-centos-local.repo`](#file-12-centos-local-repo) | Centos package config for clients.
[`13-debian-sources.list`](#file-13-debian-sources-list) | Debian package sources for clients.
[`14-ubuntu-sources.list`](#file-14-ubuntu-sources-list) | Ubuntu package sources for clients.
[`97-repoupdate.sh`](#file-97-repoupdate-sh) | (ALPHA) Combined omni-mirror sync script.
[`98-debmirror.pl`](#file-98-debmirror-pl) | Debmirror perl script provided for convenience.
[`99-clamavmirror.py`](#file-99-clamavmirror-py) | ClamAV mirror python script provided for convenience.