# syncrepo

![GitHub Tag][repo_1]
![GitHub Repo stars][repo_2]
![GitHub forks][repo_3]
![GitHub watchers][repo_4]
[![Mirrored on Codeberg][codeberg_1]][codeberg_2]
[![Chat on Gitter][gitter_1]][gitter_2]
[![Contributor Covenant][covenant]](CODE_OF_CONDUCT.md)

[![Semantic Versioning][symver_1]][symver_2]
[![GNU General Public License][license_1]][license_2]
[![FOSSA Status][fossa_1]][fossa_2]
[![Codacy Badge][codacy_1]][codacy_2]
[![codecov][codecov_1]][codecov_2]
[![Maintainability][codeclimate_1]][codeclimate_2]
[![CircleCI][circleci_1]][circleci_2]

[![Open in GitHub Codespaces][codespace_1]][codespace_2]

An all-in-one software repository sync script (or at least it aims to be)

Below are configuration files for creating upstream and downstream yum and apt
repositories. These can be hosted on a CentOS, Debian, or Ubuntu system and
served via rsync or http.

The only requirements are rsync and a webserver, such as apache. For apt
repositories or ClamAV definitions, debmirror or clamavmirror will also be
needed. Note that not all required setup steps are listed here.

> TODO: Add a proper setup guide.

Filename               | Description
---                    | ---
`syncrepo.sh`          | New all-in-one repository sync script
`syncrepo.service`     | Systemd service unit for syncrepo script
`syncrepo.timer`       | Systemd timer unit for syncrepo script
`syncrepo-vhost.conf`  | Apache vhost config for repository
`syncrepo-log.conf`    | Logrotate config file
`rsyncd.conf`          | Rsync config for repository
`rsyncd.service`       | Systemd service unit for rsyncd service
`centos-local.repo`    | Centos package config for clients
`debian-sources.list`  | Debian package sources for clients
`ubuntu-sources.list`  | Ubuntu package sources for clients
`debmirror/*`          | The [`debmirror`][debmirror] tool submodule
`clamavmirror/*`       | The [`clamavmirror`][clamavmirror] tool submodule

> **Note:** The `dev` branch is where the latest changes happen.
> It's not guaranteed to be completely functional all the time.

## Contributing

Contributions are welcome! Check out the [contribution guide](CONTRIBUTING.md).

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).

## Credits

All project contributors are listed in the [authors document](AUTHORS.md).

## Change log

Changes can (ostensibly) be found in the [change log](CHANGES.md).

## Security Issues

For reporting security issues, see the [security document](SECURITY.md).

## License

This project is released under the [GNU GPL-3.0 License](LICENSE.md).

## Versioning

This project follows [Semantic Versioning 2.0.0][symver_2].

&nbsp;

[repo_1]: https://img.shields.io/github/v/tag/AfroThundr3007730/syncrepo?style=flat&logo=github
[repo_2]: https://img.shields.io/github/stars/AfroThundr3007730/syncrepo?style=flat&logo=github
[repo_3]: https://img.shields.io/github/forks/AfroThundr3007730/syncrepo?style=flat&logo=github
[repo_4]: https://img.shields.io/github/watchers/AfroThundr3007730/syncrepo?style=flat&logo=github
[codeberg_1]: https://img.shields.io/badge/Mirrored-on_Codeberg-blue?style=flat&logo=codeberg
[codeberg_2]: https://codeberg.org/AfroThundr/syncrepo
[gitter_1]: https://img.shields.io/badge/Chat-on_Gitter-blue?style=flat&logo=gitter
[gitter_2]: https://matrix.to/#/#syncrepo:gitter.im
[covenant]: https://img.shields.io/badge/Contributor%20Covenant-2.1-blue?style=flat&logo=contributor-covenant

[symver_1]: https://img.shields.io/badge/semver-2.0.0-green?logo=semver
[symver_2]: https://semver.org/spec/v2.0.0.html
[license_1]: https://img.shields.io/badge/license-GPL%20v3-orange.svg?style=flat&logo=gnu
[license_2]: http://www.gnu.org/licenses/gpl-3.0.en.html
[fossa_1]: https://app.fossa.com/api/projects/git%2Bgithub.com%2FAfroThundr3007730%2Fsyncrepo.svg?type=shield
[fossa_2]: https://app.fossa.com/projects/git%2Bgithub.com%2FAfroThundr3007730%2Fsyncrepo?ref=badge_shield
[codacy_1]: https://api.codacy.com/project/badge/Grade/0eeda1228af140359e2ca903aae328b8
[codacy_2]: https://app.codacy.com/gh/AfroThundr3007730/syncrepo
[codecov_1]: https://codecov.io/gh/AfroThundr3007730/syncrepo/graph/badge.svg?token=5tKkLwN9Hm
[codecov_2]: https://codecov.io/gh/AfroThundr3007730/syncrepo
[codeclimate_1]: https://api.codeclimate.com/v1/badges/ac638bd38fc19249118d/maintainability
[codeclimate_2]: https://codeclimate.com/github/AfroThundr3007730/syncrepo/maintainability
[circleci_1]: https://dl.circleci.com/status-badge/img/circleci/DVFFcfNipFFiNiYZSDG4fD/Dh38tGgCFzRd13a2PV9xoq/tree/master.svg?style=shield
[circleci_2]: https://dl.circleci.com/status-badge/redirect/circleci/DVFFcfNipFFiNiYZSDG4fD/Dh38tGgCFzRd13a2PV9xoq/tree/master

[codespace_1]: https://github.com/codespaces/badge.svg
[codespace_2]: https://codespaces.new/AfroThundr3007730/syncrepo/tree/dev?quickstart=1

[debmirror]: https://salsa.debian.org/debian/debmirror
[clamavmirror]: https://github.com/akissa/clamavmirror
