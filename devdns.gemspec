#
# This file is part of the devdnsd gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "./lib/devdnsd/version"

Gem::Specification.new do |s|
  s.name = "devdnsd"
  s.version = Devdnsd::Version::STRING
  s.authors = ["Shogun"]
  s.email = ["shogun_panda@me.com"]
  s.homepage = "http://github.com/ShogunPanda/devdnsd"
  s.summary = %q{A small DNS server to enable local domain resolution.}
  s.description = %q{A small DNS server to enable local domain resolution.}

  s.rubyforge_project = "devdnsd"
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency("rubydns")
  s.add_dependency("cowtech-extensions")
  s.add_dependency("gli")
  s.add_dependency("rexec")
  s.add_dependency("plist")

  # TODO: Restrict to OSX
end


