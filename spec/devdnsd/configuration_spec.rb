# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "spec_helper"
require "tempfile"

describe DevDNSd::Configuration do
  describe "#initialize" do
    it "sets default arguments and rules" do
      config = DevDNSd::Configuration.new
      expect(config.bind_addresses).to eq(["0.0.0.0"])
      expect(config.port).to eq(7771)
      expect(config.tld).to eq("dev")
      expect(config.log_file).to eq(File.absolute_path(File.expand_path("~/.devdnsd/daemon.log")))
      expect(config.log_level).to eq(::Logger::INFO)
      expect(config.rules.count).to eq(1)
      expect(config.foreground).to eq(false)
    end

    it "should log to standard output or standard error" do
      expect(DevDNSd::Configuration.new(nil, log_file: "STDOUT").log_file).to eq($stdout)
      expect(DevDNSd::Configuration.new(nil, log_file: "STDERR").log_file).to eq($stderr)
    end
  end

  describe "#add_rule" do
    it "should add a good rule" do
      config = DevDNSd::Configuration.new
      config.add_rule(match: "RULE", reply: "127.0.0.1")
      expect(config.rules.count).to eq(2)
    end

    it "should reject a bad rule" do
      config = DevDNSd::Configuration.new
      expect { config.add_rule(match: "RULE", options: "ARG") }.to raise_error(DevDNSd::Errors::InvalidRule)
    end
  end
end
