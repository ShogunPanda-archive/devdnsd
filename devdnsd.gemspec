# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "./lib/devdnsd/version"

Gem::Specification.new do |gem|
  gem.name = "devdnsd"
  gem.version = DevDNSd::Version::STRING
  gem.homepage = "http://sw.cowtech.it/devdnsd"
  gem.summary = %q{A small DNS server to enable local domain resolution.}
  gem.description = %q{A small DNS server to enable local domain resolution.}
  gem.rubyforge_project = "devdnsd"

  gem.authors = ["Shogun"]
  gem.email = ["shogun@cowtech.it"]
  gem.license = "MIT"

  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.required_ruby_version = ">= 2.3.0"

  gem.add_dependency("bovem", "~> 4.0")
  gem.add_dependency("rubydns", "~> 1.0")
  gem.add_dependency("process-daemon", "~> 1.0")
  gem.add_dependency("mustache", "~> 1.0")
  gem.add_dependency("plist", "~> 3.2")
end


