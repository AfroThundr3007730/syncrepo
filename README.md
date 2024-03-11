syncrepo
========

[![FOSSA Status][fossa_1]][fossa_3]
![GitHub Tag][repo_1]
![GitHub Repo stars][repo_2]
![GitHub forks][repo_3]
![GitHub watchers][repo_4]
[![Mirrored on Codeberg][codeberg_1]][codeberg_2]
[![Chat on Discord][discord_1]][discord_2]

[![FOSSA Status][fossa_1]][fossa_2]
[![Codacy Badge][codacy_1]][codacy_2]
[![codecov][codecov_1]][codecov_2]
[![Maintainability][codeclimate_1]][codeclimate_2]
[![CircleCI][circleci_1]][circleci_2]

An all-in-one software repository sync script (or at least it aims to be)

Below are configuration files for creating upstream and downstream yum and apt repositories.
These can be hosted on a CentOS, Debian, or Ubuntu system and served via rsync or http.
The only requirements are rsync and a webserver, such as apache, and also debmirror.
Note that not all required setup steps are listed here (TODO: add setup guide).

Filename               | Description                                 | Notes
---                    | ---                                         | ---
`syncrepo.sh`          | New all-in-one repository sync script       | Still beta. Last tested: v1.7.0-rc3
`syncrepo.service`     | Systemd service unit for syncrepo script    | -
`syncrepo.timer`       | Systemd timer unit for syncrepo script      | -
`syncrepo-vhost.conf`  | Apache vhost config for repository          | Combined the old ones
`syncrepo-log.conf`    | Logrotate config file                       | -
`rsyncd.conf`          | Rsync config for repository                 | Combined the old ones
`rsyncd.service`       | Systemd service unit for rsyncd service     | -
`centos-local.repo`    | Centos package config for clients           | -
`debian-sources.list`  | Debian package sources for clients          | -
`ubuntu-sources.list`  | Ubuntu package sources for clients          | -
`debmirror/*`          | The `debmirror` tool submodule              | From: [debian/debmirror][ext_1]
`clamavmirror/*`       | The `clamavmirror` tool submodule           | From: [akissa/clamavmirror][ext_2]

> **Note:** The `dev` branch is where the latest changes happen.
> It's not guaranteed to be completely functional all the time.

License
-------

[![FOSSA Status][fossa_2]][fossa_4]

[repo_1]: https://img.shields.io/github/v/tag/AfroThundr3007730/syncrepo?style=flat&logo=github
[repo_2]: https://img.shields.io/github/stars/AfroThundr3007730/syncrepo?style=flat&logo=github
[repo_3]: https://img.shields.io/github/forks/AfroThundr3007730/syncrepo?style=flat&logo=github
[repo_4]: https://img.shields.io/github/watchers/AfroThundr3007730/syncrepo?style=flat&logo=github
[codeberg_1]: https://img.shields.io/badge/Mirrored-on_Codeberg-blue?style=flat&logo=codeberg
[codeberg_2]: https://codeberg.org/AfroThundr/syncrepo
[discord_1]: https://img.shields.io/badge/Chat-on_Discord-blue?style=flat&logo=discord
[discord_2]: https://discord.gg/zue9DcemEKZ

[fossa_1]: https://app.fossa.com/api/projects/git%2Bgithub.com%2FAfroThundr3007730%2Fsyncrepo.svg?type=shield
[fossa_2]: https://app.fossa.com/api/projects/git%2Bgithub.com%2FAfroThundr3007730%2Fsyncrepo.svg?type=large
[fossa_3]: https://app.fossa.com/projects/git%2Bgithub.com%2FAfroThundr3007730%2Fsyncrepo?ref=badge_shield
[fossa_4]: https://app.fossa.com/projects/git%2Bgithub.com%2FAfroThundr3007730%2Fsyncrepo?ref=badge_large
[codacy_1]: https://api.codacy.com/project/badge/Grade/0eeda1228af140359e2ca903aae328b8
[codacy_2]: https://app.codacy.com/gh/AfroThundr3007730/syncrepo
[codecov_1]: https://codecov.io/gh/AfroThundr3007730/syncrepo/graph/badge.svg?token=5tKkLwN9Hm
[codecov_2]: https://codecov.io/gh/AfroThundr3007730/syncrepo
[codeclimate_1]: https://api.codeclimate.com/v1/badges/ac638bd38fc19249118d/maintainability
[codeclimate_2]: https://codeclimate.com/github/AfroThundr3007730/syncrepo/maintainability
[circleci_1]: https://dl.circleci.com/status-badge/img/circleci/DVFFcfNipFFiNiYZSDG4fD/Dh38tGgCFzRd13a2PV9xoq/tree/master.svg?style=shield
[circleci_2]: https://dl.circleci.com/status-badge/redirect/circleci/DVFFcfNipFFiNiYZSDG4fD/Dh38tGgCFzRd13a2PV9xoq/tree/master

[ext_1]: https://salsa.debian.org/debian/debmirror
[ext_2]: https://github.com/akissa/clamavmirror
