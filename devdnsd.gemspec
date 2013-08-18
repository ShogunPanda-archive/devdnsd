# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun_panda@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "./lib/devdnsd/version"

Gem::Specification.new do |gem|
  gem.name = "devdnsd"
  gem.version = DevDNSd::Version::STRING
  gem.authors = ["Shogun"]
  gem.email = ["shogun_panda@cowtech.it"]
  gem.homepage = "http://sw.cow.tc/devdnsd"
  gem.summary = %q{A small DNS server to enable local domain resolution.}
  gem.description = %q{A small DNS server to enable local domain resolution.}

  gem.rubyforge_project = "devdnsd"
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.required_ruby_version = ">= 1.9.3"

  gem.add_dependency("bovem", "~> 3.0.2")
  gem.add_dependency("rubydns", "~> 0.6.4")
  gem.add_dependency("rexec", "~> 1.5.2")
end


