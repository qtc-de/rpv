# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## v1.3.0 - Apr 07, 2025

### Added

* Add support for pointer conformance
* Add support for NDR expressions in method params
* Add support for NDR correlation operators
* Add support for NDR ranges

### Changed

* Refactor checks for known structs
* Fix bug when updating security callbacks
* Fix doubling of `size_is` for `NdrConformantString`
* Fix incorrect offset in NDR variable expressions
* Fix incorrect handling of teneray operator in NDR expressions
* Fix handling of varying correlation descriptors
* Fix duplicate handle parameter for certain interfaces
* Fix handling of system handles
* Fix union default arm formatting


## v1.2.1 - Mar 29, 2025

### Changed

* Make rpv compatible with current `v` version
* Fix wrong architecture for x86 examples


## v1.2.0 - July 29, 2024

### Added

* Add RPC interface version information to `RpcInterfaceInfo`
* Add support for loading PDB symbols of method parameters (not in use yet)

### Changed

* Fix incorrect module locations for modules with uppercase filenames


## v1.1.1 - July 19, 2024

### Added

* Add some PDB related debug logging

### Changed

* Updated GitHub actions in workflow files


## v1.1.0 - July 17, 2024

### Added

* Add offset property to `RpcMethod`
* Add offset property to `SecurityCallback`

### Changed

* Fix type errors caused by newer v versions
* Fix incorrect attr syntax in newer v versions
* Fix incorrect address of security callbacks
* Rename `base` property of `RpcMethod` to `addr`
* Rename `base` property of `SecurityCallback` to `addr`


## v1.0.1 - Sep 24, 2023

### Changed

* Fix a small bug in NDR union arm type parsing
* Internal improvements (pipeline, README, ...)


## v1.0.0 - Sep 08, 2023

Initial Release :)
