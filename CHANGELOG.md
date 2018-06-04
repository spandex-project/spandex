# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- No unreleased changes currently.

## [1.6.1] - 2018-06-04
### Added
- `private` key, when updating spans, for non-inheriting meta

## [1.6.0] - 2018-06-04
### Added
- Storage strategy behaviour

### Changed
- Centralize most storage logic, requiring only the most adapter specific behaviour to be defined by the adapter.

## [1.5.0] - 2018-06-02
### Changed
- Interface for updating span metadata, and creating with metadata has been updated
- Check documentation for examples

[1.5.0]: https://github.com/olivierlacan/keep-a-changelog/compare/v1.5.0...v1.4.1

## [1.4.1] - 2018-05-31
### Changed
- Resolved an issue with distributed trace header parsing

[1.4.1]: https://github.com/olivierlacan/keep-a-changelog/compare/v1.4.0...v1.4.1

## [1.4.0] - 2018-05-29
### Added
- The tracer pattern
- Modernized configuration
- More: Please read the readme again!

[1.4.0]: https://github.com/olivierlacan/keep-a-changelog/compare/v1.3.4...v1.4.0

## [1.3.4] - 2018-05-25
### Added
- Support distributed tracing via trace headers.
- Added a changelog

### Changed
- No new changes

[1.3.4]: https://github.com/olivierlacan/keep-a-changelog/compare/v1.3.3...v1.3.4
