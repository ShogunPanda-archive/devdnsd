# encoding: utf-8
#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe DevDNSd::Logger do
  before(:each) do
    Sickill::Rainbow.enabled = false
  end

  describe ".create" do
    it("should create a new default logger") do
      logger = DevDNSd::Logger.create
      logger.device.should == DevDNSd::Logger.default_file
      logger.level.should == ::Logger::INFO
      logger.formatter.should == DevDNSd::Logger.default_formatter
    end

    it("should create a logger with a custom file and level") do
      logger = DevDNSd::Logger.create("/dev/null", ::Logger::WARN)
      logger.device.should == "/dev/null"
      logger.level.should == ::Logger::WARN
      logger.formatter.should == DevDNSd::Logger.default_formatter
    end

    it("should create a logger with a custom formatter") do
      formatter = Proc.new {|severity, datetime, progname, msg| msg }
      logger = DevDNSd::Logger.create("/dev/null", ::Logger::WARN, formatter)
      logger.device.should == "/dev/null"
      logger.level.should == ::Logger::WARN
      logger.formatter.should == formatter
    end

    it("should raise exceptions for invalid files") do
      expect { DevDNSd::Logger.create("/invalid/file") }.to raise_error(DevDNSd::Errors::InvalidConfiguration)
    end
  end

  describe ".default_formatter" do
    let(:output) { ::StringIO.new }
    let(:logger) { DevDNSd::Logger.create(output, Logger::DEBUG) }

    def get_last_line(buffer)
      buffer.string.split("\n").last.strip.gsub(/ T\+\d+\.\d+/, "")
    end

    it "should correctly format a DEBUG message" do
      logger.debug("Message.")
      get_last_line(output).should == "[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}] DEBUG: Message."
    end

    it "should correctly format a INFO message" do
      logger.info("Message.")
      get_last_line(output).should == "[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}]  INFO: Message."
    end

    it "should correctly format a WARN message" do
      logger.warn("Message.")
      get_last_line(output).should == "[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}]  WARN: Message."
    end

    it "should correctly format a ERROR message" do
      logger.error("Message.")
      get_last_line(output).should == "[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}] ERROR: Message."
    end

    it "should correctly format a FATAL message" do
      logger.fatal("Message.")
      get_last_line(output).should == "[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}] FATAL: Message."
    end

    it "should correctly format a INVALID message" do
      logger.log(::Logger::UNKNOWN, "Message.")
      get_last_line(output).should == "[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}]   ANY: Message."
    end
  end

  describe ".get_real_file" do
    it("should return the standard ouput") do DevDNSd::Logger.get_real_file("STDOUT").should == $stdout end
    it("should return the standard error") do DevDNSd::Logger.get_real_file("STDERR").should == $stderr end
    it("should return the file") do DevDNSd::Logger.get_real_file("/dev/null").should == "/dev/null" end
  end

  describe ".default_file" do
    it("should return the standard output") do DevDNSd::Logger.default_file.should == $stdout end
  end
end