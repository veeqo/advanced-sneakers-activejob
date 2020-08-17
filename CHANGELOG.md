# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.3.5...HEAD)

### Changed
- [#12](https://github.com/veeqo/advanced-sneakers-activejob/pull/12) Refactor changelog to comply with Keep a Changelog


## [0.3.5](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.3.4...v0.3.5) - 2020-06-27

### Fixed
- [#11](https://github.com/veeqo/advanced-sneakers-activejob/pull/11) `NoMethodError` on `Rails.application.eager_load!` in Rails initializer


## [0.3.4](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.3.3...v0.3.4) - 2020-06-11

### Added
- [#10](https://github.com/veeqo/advanced-sneakers-activejob/pull/10) Ability to run ActiveJob consumers by wildcards for queue names


## [0.3.3](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.3.2...v0.3.3) - 2020-06-09

### Added
- [#9](https://github.com/veeqo/advanced-sneakers-activejob/pull/9) Ability to run ActiveJob consumers by queue names


## [0.3.2](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.3.1...v0.3.2) - 2020-06-05

### Added
- [#8](https://github.com/veeqo/advanced-sneakers-activejob/pull/8) Ability to run specified ActiveJob queues consumers


## [0.3.1](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.3.0...v0.3.1) - 2020-06-02

### Fixed
- [#6](https://github.com/veeqo/advanced-sneakers-activejob/pull/6) Restore Sneakers::Worker::Classes methods


## [0.3.0](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.2.3...v0.3.0) - 2020-05-21

### Changed
- [#5](https://github.com/veeqo/advanced-sneakers-activejob/pull/5) Publisher is extracted to [bunny-publisher](https://github.com/veeqo/bunny-publisher)


## [0.2.3](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.2.2...v0.2.3) - 2020-04-06

### Added
- [#4](https://github.com/veeqo/advanced-sneakers-activejob/pull/4) Support for custom adapter per job

### Changed
- [#3](https://github.com/veeqo/advanced-sneakers-activejob/pull/3) Refactored support for ActiveJob prefix


## [0.2.2](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.2.1...v0.2.2) - 2020-04-05

### Fixed
-  Cleanup of `puts` and logger mistakenly introduced in version `0.2.1`

## [0.2.1](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.2.0...v0.2.1) - 2020-04-05

### Added
-  [#2](https://github.com/veeqo/advanced-sneakers-activejob/pull/2) Support queue name prefixes


## [0.2.0](https://github.com/veeqo/advanced-sneakers-activejob/compare/v0.1.0...v0.2.0) - 2020-03-23

### Added
- [#1](https://github.com/veeqo/advanced-sneakers-activejob/pull/1) Customizable options for message publishing (`routing_key`, `headers`, etc)


## [0.1.0](https://github.com/veeqo/advanced-sneakers-activejob/releases/tag/v0.1.0) - 2020-03-19

### Added
- `:advanced_sneakers` adapter for ActiveJob
