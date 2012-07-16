# encoding: utf-8
#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "rubygems"
require "bundler/setup"
require "coverage_helper"
require "devdnsd"
require "net/dns"

require File.expand_path(File.dirname(__FILE__)) + "/../utils/tester"
