# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "./lib/devdnsd/version"

Gem::Specification.new do |gem|
  gem.name = "devdnsd"
  gem.version = DevDNSd::Version::STRING
  gem.authors = ["Shogun"]
  gem.email = ["shogun_panda@me.com"]
  gem.homepage = "http://github.com/ShogunPanda/devdnsd"
  gem.summary = %q{A small DNS server to enable local domain resolution.}
  gem.description = %q{A small DNS server to enable local domain resolution.}

  gem.rubyforge_project = "devdnsd"
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]
  #gem.platform = Gem::Platform::CURRENT

  gem.add_dependency("rubydns", "~> 0.4.0")
  gem.add_dependency("cowtech-extensions", "~> 2.1.0")
  gem.add_dependency("gli", "~> 1.6.0")
  gem.add_dependency("rexec", "~> 1.4.1")
  gem.add_dependency("rainbow", "~> 1.1.0")

  gem.add_development_dependency("rspec", "~> 2.11.0")
  gem.add_development_dependency("simplecov", "~> 0.6.0")
  gem.add_development_dependency("pry", "~> 0.9.9")
  gem.add_development_dependency("net-dns", "~> 0.7.0")
  gem.add_development_dependency("yard", "~> 0.8.0")
  gem.add_development_dependency("redcarpet", "~> 2.1.0")
  gem.add_development_dependency("github-markup", "~> 0.7.0")
end


