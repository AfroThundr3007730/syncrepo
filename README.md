syncrepo
========

An all-in-one software repository sync script (or at least it aims to be)

Below are configuration files for creating upstream and downstream yum and apt repositories.
These can be hosted on a CentOS, Debian, or Ubuntu system and served via rsync or http.
The only requirements are rsync and a webserver, such as apache, and also debmirror.
Note that not all required setup steps are listed here (TODO: add setup guide).

Filename               | Description                                 | Notes
---                    | ---                                         | ---
`syncrepo.sh`          | New all-in-one repository sync script     . | Still beta. Last tested: v1.7.0-rc3
`syncrepo.service`     | Systemd service unit for syncrepo script.   |
`syncrepo.timer`       | Systemd timer unit for syncrepo script.     |
`syncrepo-vhost.conf`  | Apache vhost config for repository.         | Combined the old ones
`syncrepo-log.conf`    | Logrotate config file.                      |
`rsyncd.conf`          | Rsync config for repository.                | Combined the old ones
`rsyncd.service`       | Systemd service unit for rsyncd service.    |
`centos-local.repo`    | Centos package config for clients.          |
`debian-sources.list`  | Debian package sources for clients.         |
`ubuntu-sources.list`  | Ubuntu package sources for clients.         |
`debmirror/*`          | The `debmirror` tool submodule.             | From: [debian/debmirror](https://salsa.debian.org/debian/debmirror)
`clamavmirror/* `      | The `clamavmirror` tool submodule.          | From: [akissa/clamavmirror](https://github.com/akissa/clamavmirror)

Note: The `dev` branch is where the latest changes happen.
It's not guaranteed to be completely functional all the time.