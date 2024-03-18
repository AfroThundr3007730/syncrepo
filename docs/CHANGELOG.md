# Changelog

This document logs the change details between releases.

Further details can be found by reviewing the commit [history].

---

## [v1.8.0] (2024-03-XX)

- Changes TBD

## [v1.7.0] (2024-03-01)

Stable release of syncrepo version 1.7.0

Full changeset: [`v1.6.5...v1.7.0`][v1.7.0]

### [v1.7.0-rc8] (2024-02-28)

> **Note:** This version lacked an in-file version label

- Converted `debmirror` and `clamavmirror` to git submodules
- Fixed another minor bug in CentOS version filter logic

### [v1.7.0-rc7] (2019-12-10)

> **Note:** 1.7.0-rc7 was actually committed on 2020-08-11
<!-- -->
> **Note:** This version lacked an in-file version label

- Created `CONTRIBUTING.md` (contributor guidelines)
- Created `CHANGELOG.md` (changelog skeleton)
- Fixed CentOS 8 repository layout and version logic

### [v1.7.0-rc6] (2019-03-19)

- Integrated muiti-distro docker package repository sync
- Applied minor bug fixes and improvements

### [v1.7.0-rc5] (2018-12-10)

- Added Docker repository (Ubuntu only, at the moment)
- Fixed mirror connection check logic for upstream
- Tweaked `timer` function to allow incrementing index

### [v1.7.0-rc4] (2018-12-04)

- Changed systemd service to confirm sync by defualt
- Added missing `securityonion` module to `rsync` config
- Fixed downstream logic also triggering upstream sync
- Fixed mirror connection check for downstream sync
- Added `timer` function to show elapsed time for sync jobs
- Formatted so lines are now under 100 characters in length

### [v1.7.0-rc3] (2018-12-03)

- Integrated downstream and upstream sync scripts
- Refactored consolidated script to reduce code duplication
- Adjusted debian repository sync to use http due to rsync issues

### [v1.7.0-rc2] (2018-12-03)

- Added erstwhile missing downstream consolidated script
- Added sync logic for SecurityOnion repositories
- Added logic to normalize file permissions after sync
- Adjusted function ordering and formatting fixes

### [v1.7.0-rc1] (2018-10-29)

- Renamed `reposync` to `syncrepo` (naming things is hard)
- Removed the legacy repoupdate scripts; replaced by syncrepo
- Added consolidated `rsync` and `apache` config files
- Replaced `printf` usage with new `say` wrapper function
- Refactored syncrepo script to use functions for everything

## Older Changes

> **NOTE:** There was no established changelog prior to version 1.7.0, so any
> entries preceeding this version were reconstructed from the commit history.

### [Moved] to GitHub (2018-11-11)

Initial commit to GitHub repository. Previous versions lived as a gist. The gist
history has been partially replayed and preserved in the git repository. If you
want to dig back that far, check out this [gist] for details.

- Renamed files to remove number prefixes from gist era
- Added a `LICENSE` file (GNU GPL v3.0) to the repository
- Rewrote README table and added notes on files

### [v1.6.0] to [v1.6.5] (2018-10-11 - 2018-10-29)

- Added more sync control flags
- Adjusted version list variables to use arrays
- Changed CentOS version selection to be dynamic
- Reduced the amount of calls to external binaries
- Added argument handler and initial CLI usage
- Replaced legacy `[` test syntax with bash `[[` tests
- Made variable declarations coditional to avoid pollution
- Initial attempt to manage line length and code style
- Added `logrotate` configuration for sync logs
- Case correction (all caps) for global variables

### [v1.5.0] to [v1.5.3] (2018-10-02 - 2018-10-04)

- Added `clamavmirror` tool for virus definitions
- Added combined (apt and yum) upstream script
- Added switches to control sync behavior
- Refactored and reorganized script for clarity

### [v1.4.0] to [v1.4.2] (2018-05-18 - 2018-10-03)

- Fixed various variable quoting issues
- Fixed `printf` usage to apply format strings
- Converted to ISO-8601 dates and adjused `rsync` options
- Fixed recursive directory creation issue
- Set service permissions to work with `httpd`

### [v1.3.0] (2018-05-02)

- Added a proper markdown `README` file
- Added EPEL repository sync logic
- Added basic directory existence checks

### [v1.2.0] (2017-02-24)

Initial version committed to version control.

Comprised four scripts: an upstream and downstream each for yum and apt based
repositories. Also included repository configurations for clients, and service
configuration files for the associated services.

Initially supported Ubuntu, Debian, and CentOS repositories.

---

[v1.8.0]: https://github.com/AfroThundr3007730/syncrepo/tree/dev
[v1.7.0]: https://github.com/AfroThundr3007730/syncrepo/compare/v1.6.5...v1.7.0
[v1.7.0-rc8]: https://github.com/AfroThundr3007730/syncrepo/compare/3b10c69...4464568
[v1.7.0-rc7]: https://github.com/AfroThundr3007730/syncrepo/compare/d824990...3b10c69
[v1.7.0-rc6]: https://github.com/AfroThundr3007730/syncrepo/commit/d824990
[v1.7.0-rc5]: https://github.com/AfroThundr3007730/syncrepo/commit/db152af
[v1.7.0-rc4]: https://github.com/AfroThundr3007730/syncrepo/commit/f87446c
[v1.7.0-rc3]: https://github.com/AfroThundr3007730/syncrepo/commit/b8259cc
[v1.7.0-rc2]: https://github.com/AfroThundr3007730/syncrepo/commit/51ffb82
[v1.7.0-rc1]: https://github.com/AfroThundr3007730/syncrepo/commit/4bddf27
[moved]: https://github.com/AfroThundr3007730/syncrepo/compare/9588205...4bddf27
[v1.6.5]: https://github.com/AfroThundr3007730/syncrepo/compare/a5d28c5...9588205
[v1.6.0]: https://github.com/AfroThundr3007730/syncrepo/compare/65a4867...a5d28c5
[v1.5.3]: https://github.com/AfroThundr3007730/syncrepo/compare/347423d...65a4867
[v1.5.0]: https://github.com/AfroThundr3007730/syncrepo/compare/b35fda6...347423d
[v1.4.2]: https://github.com/AfroThundr3007730/syncrepo/compare/47e4e50...b35fda6
[v1.4.0]: https://github.com/AfroThundr3007730/syncrepo/compare/295dece...47e4e50
[v1.3.0]: https://github.com/AfroThundr3007730/syncrepo/compare/8642c56...295dece
[v1.2.0]: https://github.com/AfroThundr3007730/syncrepo/commit/8642c56
[history]: https://github.com/AfroThundr3007730/syncrepo/commits/master/
[gist]: https://gist.github.com/AfroThundr3007730/d813dc149b2407cf53936915e98659af
