# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Recreate dependent views when generating a migration with a Rails table name prefix.
- Discover and recreate dependent views across PostgreSQL schemas without mixing identically named views or their SQL definitions.

## [0.1.2] - 2026-11-01

### Fixed

- Select the latest existing dependent view definition when SQL version numbers have gaps.
- Report noncanonical numeric view definition filenames instead of silently selecting an older definition.
- Leave view definition files untouched when a dependent view has no Scenic definition.

## [0.1.1] - 2026-10-30

### Fixed

- Restore cascading migrations for deep dependency chains and views reached through multiple paths.

## [0.1.0] - 2023-12-11

### Added

- Initial release of the cascading Scenic view migration generator.

[Unreleased]: https://github.com/akiomik/scenic-cascade/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/akiomik/scenic-cascade/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/akiomik/scenic-cascade/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/akiomik/scenic-cascade/releases/tag/v0.1.0
