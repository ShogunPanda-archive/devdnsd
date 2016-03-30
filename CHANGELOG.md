### 4.0.0 / 2016-03-30

* Refactored `DevDNSd::Application`.
* Changed signatures of `DevDNSd::Rule.create` and `DevDNSd::Rule#initialize`.
* Changed signatures of `DevDNSd::Configuration.add_rule`.
* Removed `DevDNSd::Aliases#is_ipv4?` and `DevDNSd::Aliases#is_ipv6?` aliases.
* Dropped support for Ruby < 2.3.
* Replaced `rexec` with `process-daemon`.
* Updated dependencies.
* Linted code.

### 3.1.2 / 2014-03-29

* Minor fixes.

### 3.1.1 / 2014-03-09

* Minor typo fix.

### 3.1.0 / 2014-03-09

* Added `restart`, `clean` and `status` commands.
* The `address` configuration option is now `bind_addresses` and it supports multiple values.
* Start dropping support for Ruby <2.1 - For now only in the Travis build.

### 3.0.8 / 2014-03-08

* Installation fixes.
* Changed file paths to be more user-friendly.

### 3.0.7 / 2014-03-08

* Show a warning when the configuration file is missing.