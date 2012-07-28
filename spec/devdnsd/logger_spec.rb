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
      expect(logger.device).to eq(DevDNSd::Logger.default_file)
      expect(logger.level).to eq(::Logger::INFO)
      expect(logger.formatter).to eq(DevDNSd::Logger.default_formatter)
    end

    it("should create a logger with a custom file and level") do
      logger = DevDNSd::Logger.create("/dev/null", ::Logger::WARN)
      expect(logger.device).to eq("/dev/null")
      expect(logger.level).to eq(::Logger::WARN)
      expect(logger.formatter).to eq(DevDNSd::Logger.default_formatter)
    end

    it("should create a logger with a custom formatter") do
      formatter = Proc.new {|severity, datetime, progname, msg| msg }
      logger = DevDNSd::Logger.create("/dev/null", ::Logger::WARN, formatter)
      expect(logger.device).to eq("/dev/null")
      expect(logger.level).to eq(::Logger::WARN)
      expect(logger.formatter).to eq(formatter)
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
      expect(get_last_line(output)).to eq("[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}] DEBUG: Message.")
    end

    it "should correctly format a INFO message" do
      logger.info("Message.")
      expect(get_last_line(output)).to eq("[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}]  INFO: Message.")
    end

    it "should correctly format a WARN message" do
      logger.warn("Message.")
      expect(get_last_line(output)).to eq("[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}]  WARN: Message.")
    end

    it "should correctly format a ERROR message" do
      logger.error("Message.")
      expect(get_last_line(output)).to eq("[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}] ERROR: Message.")
    end

    it "should correctly format a FATAL message" do
      logger.fatal("Message.")
      expect(get_last_line(output)).to eq("[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}] FATAL: Message.")
    end

    it "should correctly format a INVALID message" do
      logger.log(::Logger::UNKNOWN, "Message.")
      expect(get_last_line(output)).to eq("[#{::Time.now.strftime("%Y/%b/%d %H:%M:%S")}]   ANY: Message.")
    end
  end

  describe ".get_real_file" do
    it("should return the standard ouput") do 
      expect(DevDNSd::Logger.get_real_file("STDOUT")).to eq($stdout )
    end
    
    it("should return the standard error") do 
      expect(DevDNSd::Logger.get_real_file("STDERR")).to eq($stderr )
    end
    
    it("should return the file") do 
      expect(DevDNSd::Logger.get_real_file("/dev/null")).to eq("/dev/null" )
    end
  end

  describe ".default_file" do
    it("should return the standard output") do
      expect(DevDNSd::Logger.default_file).to eq($stdout)
    end
  end
end