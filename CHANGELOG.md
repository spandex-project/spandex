# Change Log

<!-- changelog -->

## [3.2.0](https://github.com/spandex-project/spandex/compare/3.1.0...3.2.0) (2022-10-20)

### Features:

* Add Service Version Support by @kamilkowalski in https://github.com/spandex-project/spandex/pull/122

## Bug Fixes:

* Fix interpolated string span and trace names by @gerbal in https://github.com/spandex-project/spandex/pull/136

## New Contributors:
* @gerbal made their first contribution in https://github.com/spandex-project/spandex/pull/136


## [3.1.0](https://github.com/spandex-project/spandex/compare/3.0.3...3.1.0) (2021-10-23)

* Encode logger metadata as string. by @aselder in https://github.com/spandex-project/spandex/pull/127
* Set up sponsorship links by @GregMefford in https://github.com/spandex-project/spandex/pull/132
* Guard clauses for trace and span macros by @GregMefford in https://github.com/spandex-project/spandex/pull/130
* Misc doc changes by @kianmeng in https://github.com/spandex-project/spandex/pull/128

## [3.0.3](https://github.com/spandex-project/spandex/compare/3.0.2...3.0.3) (2020-11-10)




## [3.0.2](https://github.com/spandex-project/spandex/compare/3.0.1...3.0.2) (2020-07-13)




### Bug Fixes:

* add a name to failed traces (#116)

## [3.0.1](https://github.com/spandex-project/spandex/compare/3.0.0...3.0.1) (2020-05-14)




### Bug Fixes:

* configure sender in tests

## [3.0.0](https://github.com/spandex-project/spandex/compare/2.4.4...3.0.0) (2020-05-14)
### Breaking Changes:

* allow headers to be passed into `Spandex.distributed_context/2` (#113)



## [2.4.4](https://github.com/spandex-project/spandex/compare/2.4.3...2.4.4) (2020-4-28)




### Bug Fixes:

* Set Logger.metadata when `continue_trace/3` is called as well (#111)

## [2.4.3](https://github.com/spandex-project/spandex/compare/2.4.2...2.4.3) (2020-3-25)




### Bug Fixes:

* No unmatched returns (#109)

## [2.4.2](https://github.com/spandex-project/spandex/compare/2.4.1...2.4.2) (2020-1-13)




### Bug Fixes:

* Add missing trace_id to logger metadata (#107)

## [2.4.1](https://github.com/spandex-project/spandex/compare/2.4.0...2.4.1) (2018-12-11)

### Bug Fixes:

* Resolve unknown dialyzer type error


### Bug Fixes:

* don't silence errors on span update calls (#90)

* update span on finish trace/update (#88)

## [2.4.0](https://github.com/spandex-project/spandex/compare/2.4.0...2.4.0) (2018-10-11)




### Features:

* Add(bring back) span and trace decorators


# The below is before automated changelog management

## [2.3.0]

[2.3.0]: https://github.com/spandex-project/spandex/compare/v2.3.0...v2.2.0

### Added
- `Spandex.current_context/1` and `Spandex.Tracer.current_context/1` functions,
  which get a `Spandex.SpanContext` struct based on the current context.
- `Spandex.inject_context/3` and `Spandex.Tracer.inject_context/2` functions,
  which inject a distributed tracing context into a list of HTTP headers.

### Changed
- The `Spandex.Adapter` behaviour now requires an `inject_context/3` callback,
  which encodes a `Spandex.SpanContext` as HTTP headers for distributed
  tracing.

## [2.2.0]

[2.2.0]: https://github.com/spandex-project/spandex/compare/v2.2.0...v2.1.0

### Added
- The `Spandex.Trace` struct now includes `priority` and `baggage` fields, to
  support priority sampling of distributed traces and trace-level baggage,
  respectively. More details about these concepts can be found in the
  OpenTracing documentation.  An updated version of the `spandex_datadog`
  library will enable support for this feature in terms of the
  `Spandex.Adapter` and `Sender` APIs.

### Changed
- It is no longer required that you specify the `env` option. If not specified,
  it will default to `nil`. This is useful, for example, for allowing the
  Datadog trace collector configured default to be used.
- The `Spandex.Adapter.distributed_context/2` callback now expects a
  `SpanContext` struct to be returned, rather than a `Map`.
- Similarly, the `Spandex.continue_trace` function now expects a `SpanContext`
  struct rather than a separate `trace_id` and `span_id`.
- The sender API now calls the `send_trace` function, passing in a
  `Spandex.Trace` struct, rather than passing a list of `Spandex.Span` structs.
  This means that you need to update the `spandex_datadog` to a compatible
  version.

### Deprecated
- `Spandex.continue_trace/4` is deprecated in favor of
  `Spandex.continue_trace/3`
- Similarly, `Tracer.continue_trace/4` is deprecated in favor of
  `Tracer.continue_trace/3`

## [2.1.0]
It is recommended to reread the README, to see the upgrade guide and understand the changes.

[2.1.0]: https://github.com/spandex-project/spandex/compare/v2.1.0...v1.6.1

### Added
- Massive changes, including separating adapters into their own repositories

### Changed
- Many interface changes, specifically around return values

### Removed
- Adapters now exist in their own repositories

## [1.6.1] - 2018-06-04

[1.6.1]: https://github.com/spandex-project/spandex/compare/v1.6.1...v1.6.0

### Added
- `private` key, when updating spans, for non-inheriting meta

## [1.6.0] - 2018-06-04

[1.6.0]: https://github.com/spandex-project/spandex/compare/v1.6.0...v1.5.0

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
