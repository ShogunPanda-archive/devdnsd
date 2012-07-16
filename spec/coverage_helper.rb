# encoding: utf-8
#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "simplecov"
require "pathname"

if ENV["DEVDNSD_COVERAGE"] == "TRUE" then
  root = Pathname.new(File.dirname(__FILE__)) + ".."

  SimpleCov.start do
    add_filter do |src_file|
      path = Pathname.new(src_file.filename).relative_path_from(root).to_s
      path =~ /^lib\/devdnsd\/patches/ || path !~ /^(bin|lib)/
    end
  end
end