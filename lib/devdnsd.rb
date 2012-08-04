# encoding: utf-8
#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "rubygems"
require "bovem"
require "rubydns"
require "gli"
require "rexec/daemon"

Lazier.load!(:object)

require "devdnsd/application"
require "devdnsd/configuration"
require "devdnsd/errors"
require "devdnsd/rule"
require "devdnsd/version" if !defined?(DevDNSd::Version)