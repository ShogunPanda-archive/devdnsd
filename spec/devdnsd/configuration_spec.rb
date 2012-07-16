# encoding: utf-8
#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"
require "tempfile"

describe DevDNSd::Configuration do
  class DevDNSd::Application
    def logger
      DevDNSd::Logger.new("/dev/null")
    end
  end

  let(:new_application) {
    app = DevDNSd::Application.new
    app.logger = DevDNSd::Logger.create("/dev/null", DevDNSd::Logger::DEBUG)
    app
  }
  describe "#initialize" do
    it "sets default arguments and rules" do
      config = DevDNSd::Configuration.new
      config.address.should == "0.0.0.0"
      config.port.should == 7771
      config.tld.should == "dev"
      config.log_file.should == "/var/log/devdnsd.log"
      config.log_level.should == Logger::INFO
      config.rules.count.should == 1
      config.foreground.should == false
    end

    it "reads a valid configuration file" do
      file = Tempfile.new('devdnsd-test')
      file.write("config.port = 7772")
      file.close

      config = DevDNSd::Configuration.new(file.path, new_application)
      config.port.should == 7772
      file.unlink
    end

    it "reject an invalid configuration" do
      file = Tempfile.new('devdnsd-test')
      file.write("config.port = ")
      file.close

      expect { config = DevDNSd::Configuration.new(file.path, new_application)}.to raise_error(DevDNSd::Errors::InvalidConfiguration)
      file.unlink
    end

    it "allows overrides" do
      file = Tempfile.new('devdnsd-test')
      file.write("config.port = 7772")
      file.close

      config = DevDNSd::Configuration.new(file.path, new_application, {:foreground => true, :port => 7773})
      config.port.should == 7773
      config.foreground = true
      file.unlink
    end
  end

  describe "#add_rule" do
    it "should add a good rule" do
      config = DevDNSd::Configuration.new
      config.add_rule("RULE", "127.0.0.1")
      config.rules.count.should == 2
    end

    it "should reject a bad rule" do
      config = DevDNSd::Configuration.new
      expect { config.add_rule("RULE") }.to raise_error(DevDNSd::Errors::InvalidRule)
    end
  end
end