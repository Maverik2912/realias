# Changelog

All notable changes to **realias** are documented here.

The format is based on
[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## How to use this file

- Every PR that user-visibly changes behaviour adds a bullet under
  `[Unreleased]`, in one of the standard sections:
  - **Added** — new features.
  - **Changed** — changes to existing behaviour.
  - **Deprecated** — soon-to-be-removed features.
  - **Removed** — features removed in this release.
  - **Fixed** — bug fixes.
  - **Security** — vulnerabilities.
- On release:
  1. Rename `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`.
  2. Add a fresh empty `[Unreleased]` block at the top.
  3. Update the compare-link footnotes at the bottom of this file.
  4. Bump `version` in `package.json`, commit, and tag `vX.Y.Z`.

## [Unreleased]

### Added
- Rewrite stale-sigil aliases. When an import's leading symbol (e.g. `@`)
  doesn't match any leading symbol in the current `tsconfig` aliases (e.g.
  all `~`), realias now treats the import as a renamed alias and rewrites
  it instead of leaving it as a bare module. Triggered only when the
  current sigil is *not* present in any alias key, so legitimate but
  unmatched bare imports are still left alone.
- Test fixture at `src/` exercising every CLI flag, with a per-flag
  expected-diff README at `src/README.md`.

## [0.1.2] - 2026-05-13

### Added
- GitHub Actions workflow publishing the package to npm via OIDC trusted
  publishing on every `v*` tag, and creating a matching GitHub release.

### Fixed
- `bin/realias` resolves tsconfig from the invocation directory instead of
  the script directory, so global/`node_modules` installs work as expected.

## [0.1.0] - Initial release

### Added
- `realias` CLI: rewrites relative imports under the nearest
  `tsconfig*.json` to the most specific `compilerOptions.paths` alias, and
  re-aliases existing aliased imports when a better match exists.
- Flags: `-c/--tsconfig`, `-r/--root`, `-e/--exts`, `-s/--skip`,
  `-a/--all-relative`, `-v/--verbose`.

[Unreleased]: https://github.com/Maverik2912/realias/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/Maverik2912/realias/compare/v0.1.0...v0.1.2
[0.1.0]: https://github.com/Maverik2912/realias/releases/tag/v0.1.0
