# encoding: utf-8
#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "rubygems"
require "rubydns"
require "gli"
require "rexec/daemon"
require "pathname"
require "rainbow"
require "cowtech-extensions"
require "rbconfig"

Cowtech::Extensions.load!

require "devdnsd/application"
require "devdnsd/configuration"
require "devdnsd/errors"
require "devdnsd/logger"
require "devdnsd/rule"
require "devdnsd/version" if !defined?(DevDNSd::Version)