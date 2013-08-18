#!/usr/bin/env ruby
# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "bovem"
require "rubydns"
require File.dirname(__FILE__) + "/../spec/resolver_helper"

Bovem::Application.create(name: "DevDNSd resolver") do
  option("address", ["a", "address"], {type: String, help: "The address to resolve.", meta: "ADDRESS", default: "match.dev"})
  option("type", ["t", "type"], {type: String, help: "The query to run.", meta: "TYPE", default: "ANY"})
  option("nameserver", ["n", "nameserver"], {type: String, help: "The nameserver to use.", meta: "NAMESERVER", default: "127.0.0.1"})
  option("port", ["p", "port"], {type: Fixnum, help: "The port of the nameserver.", meta: "PORT", default: 7771})

  action do |command|
    opts = command.get_options
    EM.run {
      Fiber.new {
        devdnsd_resolv(opts["address"], opts["type"], opts["nameserver"], opts["port"], Bovem::Logger.create($stdout, Logger::DEBUG))
        EM.stop
      }.resume
    }
  end
end