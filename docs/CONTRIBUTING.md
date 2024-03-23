# How to Contribute

Note that the author is not a codeing expert, and makes plenty of mistakes. If
you've found one - and would like to report it or submit a fix - feel free to do
so by opening an [issue] or pull request. Feature additions or requests are also
welcome here.

For bug reports and feature requests, open an issue and provide any relevant
details there. Questions are not well suited to issue format, and may be better
addressed by asking instead on [Gitter].

## Code contributions

For pull requests, features and bug fixes should be submitted to the `dev`
branch. Bug fixes will also get pushed to `master` or the relevant release
branch when needed. Code submissions should be lint free and follow best
practices where possible. We use [shellcheck] and [shfmt] for this purpose. If
you're using VSCode, it will recommend them when you open this repo.

The code generally follows Google's Bash style [guide], with notable exceptions:

- Indent with four spaces, no tabs. The `.editorconfig` file helps with this.
- Pipeline and compounds (e.g. `|` or `&&`) end a line instead of beginning it.
- Variables are brace delimited (`${var}`) only when needed, but always quoted.
- Function namespacing is done with `.` instead of `::` (e.g. `module.func()`).

By making contributions to this project you agree to follow the conditions laid
out in the [Developer Certificate of Origin][cert].

[issue]: https://github.com/AfroThundr3007730/syncrepo/issues/new
[gitter]: https://matrix.to/#/#syncrepo:gitter.im
[shellcheck]: https://github.com/koalaman/shellcheck
[shfmt]: https://github.com/mvdan/sh
[guide]: https://github.com/google/styleguide/blob/gh-pages/shellguide.md
[cert]: https://developercertificate.org/
