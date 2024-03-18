# ![logo](sync-logo.svg) Syncrepo

An all-in-one software repository sync script (or at least it aims to be)

![GitHub Release][repo_1]
![GitHub Repo stars][repo_2]
![GitHub forks][repo_3]
![GitHub watchers][repo_4]
[![GNU General Public License][license_1]][license_2]
[![Mirrored on Codeberg][codeberg_1]][codeberg_2]
[![Chat on Gitter][gitter_1]][gitter_2]

[![GitHub Actions Workflow Status][action_1]][action_2]
[![FOSSA License Status][fossa_1]][fossa_2]
[![OpenSSF Best Practices][openssf_1]][openssf_2]
[![Codacy Badge][codacy_1]][codacy_2]
[![Codecov Coverage][codecov_1]][codecov_2]
[![Maintainability][codeclimate_1]][codeclimate_2]

[![Open in GitHub Codespaces][codespace_1]][codespace_2]

## Project Overview

Below are configuration files for creating upstream and downstream yum and apt
repositories. These can be hosted on a CentOS, Debian, or Ubuntu system and
served via rsync or http.

The only requirements are rsync and a webserver, such as apache. For apt
repositories or ClamAV definitions, debmirror or clamavmirror will also be
needed. Note that not all required setup steps are listed here.

> TODO: Add a proper setup guide.

## Working with this repository

The `master` branch hosts stable releases, unless bugfixes are needed, then a
release branch is forked to host changes.

The `dev` branch is where the latest changes happen. It's not guaranteed to be
completely functional all the time.

Further details can be found in the contributor guidelines.

### Repository Layout

Filename                    | Description
---                         | ---
`docs/`                     | Documentation and other metadata
`src/syncrepo.sh`           | New all-in-one repository sync script
`src/syncrepo.service`      | Systemd service unit for syncrepo script
`src/syncrepo.timer`        | Systemd timer unit for syncrepo script
`src/syncrepo-vhost.conf`   | Apache vhost config for repository
`src/syncrepo-log.conf`     | Logrotate config file
`src/rsyncd.conf`           | Rsync config for repository
`src/rsyncd.service`        | Systemd service unit for rsyncd service
`src/centos-local.repo`     | Centos package config for clients
`src/debian-sources.list`   | Debian package sources for clients
`src/ubuntu-sources.list`   | Ubuntu package sources for clients
`modules/debmirror/`        | The [debmirror] tool submodule
`modules/clamavmirror/`     | The [clamavmirror] tool submodule

### Contributing

Contributions are welcome! Check out the [contribution guide](CONTRIBUTING.md).

### Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).

### Credits

All project contributors are listed in the [authors document](AUTHORS.md).

### Change log

Changes can (ostensibly) be found in the [change log](CHANGES.md).

### Security Issues

For reporting security issues, see the [security document](SECURITY.md).

### License

This project is released under the [GNU GPL-3.0 License](/LICENSE.md).

### Versioning

This project follows [Semantic Versioning 2.0.0][symver_2].

### Acknowledgements

This project uses resources from [these other projects](ACKNOWLEDGEMENTS.md).

---

[![Contributor Covenant][covenant_1]][covenant_2]
[![Semantic Versioning][symver_1]][symver_2]
[![Keep a Changelog][changelog_1]][changelog_2]
[![Make a Readme][readme_1]][readme_2]
[![Developer Certificate][certificate_1]][certificate_2]

[repo_1]: https://img.shields.io/github/v/release/AfroThundr3007730/syncrepo?style=flat&logo=github
[repo_2]: https://img.shields.io/github/stars/AfroThundr3007730/syncrepo?style=flat&logo=github
[repo_3]: https://img.shields.io/github/forks/AfroThundr3007730/syncrepo?style=flat&logo=github
[repo_4]: https://img.shields.io/github/watchers/AfroThundr3007730/syncrepo?style=flat&logo=github
[license_1]: https://img.shields.io/badge/license-GPL_v3-blue.svg?style=flat&logo=gnu
[license_2]: http://www.gnu.org/licenses/gpl-3.0.en.html
[codeberg_1]: https://img.shields.io/badge/Mirrored-on_Codeberg-blue?style=flat&logo=codeberg
[codeberg_2]: https://codeberg.org/AfroThundr/syncrepo
[gitter_1]: https://img.shields.io/badge/Chat-on_Gitter-blue?style=flat&logo=gitter
[gitter_2]: https://matrix.to/#/#syncrepo:gitter.im

[action_1]: https://img.shields.io/github/actions/workflow/status/AfroThundr3007730/syncrepo/codacy-analysis.yml?style=flat&logo=github
[action_2]: https://github.com/AfroThundr3007730/syncrepo/actions/workflows/codacy-analysis.yml
[fossa_1]: https://app.fossa.com/api/projects/git%2Bgithub.com%2FAfroThundr3007730%2Fsyncrepo.svg?type=shield
[fossa_2]: https://app.fossa.com/projects/git%2Bgithub.com%2FAfroThundr3007730%2Fsyncrepo?ref=badge_shield
[codacy_1]: https://api.codacy.com/project/badge/Grade/0eeda1228af140359e2ca903aae328b8
[codacy_2]: https://app.codacy.com/gh/AfroThundr3007730/syncrepo
[openssf_1]: https://www.bestpractices.dev/projects/8686/badge
[openssf_2]: https://www.bestpractices.dev/projects/8686
[codecov_1]: https://codecov.io/gh/AfroThundr3007730/syncrepo/graph/badge.svg?token=5tKkLwN9Hm
[codecov_2]: https://codecov.io/gh/AfroThundr3007730/syncrepo
[codeclimate_1]: https://api.codeclimate.com/v1/badges/ac638bd38fc19249118d/maintainability
[codeclimate_2]: https://codeclimate.com/github/AfroThundr3007730/syncrepo/maintainability

[covenant_1]: https://img.shields.io/badge/Contributor_Covenant-2.1-blue?style=flat&logo=contributor-covenant
[covenant_2]: https://www.contributor-covenant.org/version/2/1/code_of_conduct/
[symver_1]: https://img.shields.io/badge/Semantic_Versioning-2.0.0-blue?style=flat&logo=semver
[symver_2]: https://semver.org/spec/v2.0.0.html
[changelog_1]: https://img.shields.io/badge/Keep_a_Changelog-1.1.0-blue?style=flat&logo=keepachangelog
[changelog_2]: https://keepachangelog.com/en/1.1.0/
[readme_1]: https://img.shields.io/badge/Make_a_Readme-101-blue?style=flat&logo=readme
[readme_2]: https://www.makeareadme.com/#readme-101
[certificate_1]: https://img.shields.io/badge/Developer_Certificate-1.1-blue?style=flat&logo=cachet
[certificate_2]: https://developercertificate.org/

[codespace_1]: https://github.com/codespaces/badge.svg
[codespace_2]: https://codespaces.new/AfroThundr3007730/syncrepo/tree/dev?quickstart=1

[debmirror]: https://salsa.debian.org/debian/debmirror
[clamavmirror]: https://github.com/akissa/clamavmirror
