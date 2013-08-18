# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun_panda@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "rubygems"
require "bovem"
require "rubydns"
require "rexec/daemon"
require "mustache"
require "ipaddr"
require "fiber"

Lazier.load!(:object)

require "devdnsd/application"
require "devdnsd/configuration"
require "devdnsd/errors"
require "devdnsd/rule"
require "devdnsd/version" if !defined?(DevDNSd::Version)

# DevDNSd is not supported on JRuby
DevDNSd::Application.check_ruby_implementation