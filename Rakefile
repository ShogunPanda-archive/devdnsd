# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2011 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new("spec")

namespace :spec do
  desc "Run all specs with coverage"
  task :coverage do
    ENV["DEVDNSD_COVERAGE"] = "TRUE"
    Rake::Task["spec"].invoke
  end
end
