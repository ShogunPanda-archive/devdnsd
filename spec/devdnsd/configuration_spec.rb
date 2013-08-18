# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun_panda@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"
require "tempfile"

describe DevDNSd::Configuration do
  describe "#initialize" do
    it "sets default arguments and rules" do
      config = DevDNSd::Configuration.new
      expect(config.address).to eq("0.0.0.0")
      expect(config.port).to eq(7771)
      expect(config.tld).to eq("dev")
      expect(config.log_file).to eq("/var/log/devdnsd.log")
      expect(config.log_level).to eq(::Logger::INFO)
      expect(config.rules.count).to eq(1)
      expect(config.foreground).to eq(false)
    end
  end

  describe "#add_rule" do
    it "should add a good rule" do
      config = DevDNSd::Configuration.new
      config.add_rule("RULE", "127.0.0.1")
      expect(config.rules.count).to eq(2)
    end

    it "should reject a bad rule" do
      config = DevDNSd::Configuration.new
      expect { config.add_rule("RULE") }.to raise_error(DevDNSd::Errors::InvalidRule)
    end
  end
end
