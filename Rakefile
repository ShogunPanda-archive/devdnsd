# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2011 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new("spec")
RSpec::Core::RakeTask.new("spec:coverage") { |t| t.ruby_opts = "-r./spec/coverage_helper" }

desc "Generate the documentation"
task :docs do
  system("yardoc") || raise("Failed Execution of: yardoc")
end

desc "Get the current release version"
task :version, :with_name do |_, args|
  gem = Bundler::GemHelper.instance.gemspec
  puts [args[:with_name] == "true" ? gem.name : nil, gem.version].compact.join("-")
end

desc "Prepare the release"
task :prerelease => ["spec:coverage", "docs"] do
  ["git add -A", "git commit -am \"Version #{Bundler::GemHelper.instance.gemspec.version}\""].each do |cmd|
    system(cmd) || raise("Failed Execution of: #{cmd}")
  end
end