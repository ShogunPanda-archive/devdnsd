# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "rubydns"
require "process/daemon"
require "mustache"
require "ipaddr"
require "plist"
require "tempfile"
require "bovem"

require "devdnsd/version" unless defined?(DevDNSd::Version)
require "devdnsd/aliases"
require "devdnsd/server"
require "devdnsd/system"
require "devdnsd/osx"
require "devdnsd/application"
require "devdnsd/configuration"
require "devdnsd/errors"
require "devdnsd/rule"

Celluloid.logger = nil

# DevDNSd is not supported on JRuby
DevDNSd::Application.check_ruby_implementation
