# encoding: utf-8
#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe DevDNSd::Rule do
  describe "#new" do
    it("should create a default rule") do
      rule = DevDNSd::Rule.new
      rule.match.should == /.+/
      rule.reply.should == "127.0.0.1"
      rule.type.should == :A
      rule.options.should == {}
      rule.block.should be_nil
    end

    it("should create a rule with arguments and no block") do
      rule = DevDNSd::Rule.new("MATCH", "REPLY", "TYPE", {:a => :b})
      rule.match.should == "MATCH"
      rule.reply.should == "REPLY"
      rule.type.should == "TYPE"
      rule.options.should == {:a => :b}
      rule.block.should be_nil
    end

    it("should create a rule with arguments and a block") do
      rule = DevDNSd::Rule.new("MATCH", "REPLY", "TYPE") do end
      rule.match.should == "MATCH"
      rule.reply.should be_nil
      rule.type.should == "TYPE"
      rule.options.should == {}
      rule.block.should_not be_nil
    end
  end

  describe "#is_regexp?" do
    it("should return true for a regexp pattern") do DevDNSd::Rule.create(/.+/, "127.0.0.1").is_regexp?.should be_true end
    it("should return false otherwise") do DevDNSd::Rule.create("RULE", "127.0.0.1").is_regexp?.should be_false end
  end

  describe "#has_block?" do
    it("should return true when a block is present") do DevDNSd::Rule.create("RULE"){}.has_block?.should be_true end
    it("should return false otherwise") do DevDNSd::Rule.create("RULE", "127.0.0.1").has_block?.should be_false end
  end

  describe "#match_host" do
    describe "with a string pattern" do
      it("should return true when hostname matches") do DevDNSd::Rule.create("match.dev", "127.0.0.1").match_host("match.dev").should be_true end
      it("should return false when hostname doesn't match") do DevDNSd::Rule.create("match.dev", "127.0.0.1").match_host("unmatch.dev").should be_false end
    end

    describe "with a regexp pattern" do
      it("should return a MatchData when hostname matches") do DevDNSd::Rule.create(/^match/, "127.0.0.1").match_host("match.dev").should be_a(MatchData) end
      it("should return nil when hostname doesn't match") do DevDNSd::Rule.create(/^match/, "127.0.0.1").match_host("unmatch.dev").should be_nil end
    end
  end

  describe "#create" do
    it("should not allow rules without sufficient arguments") do
      expect{ DevDNSd::Rule.create("RULE") }.to raise_error(DevDNSd::Errors::InvalidRule)
      expect{ DevDNSd::Rule.create("RULE", "REPLY", "TYPE", "ARG") }.to raise_error(DevDNSd::Errors::InvalidRule)
    end

    it("should create a rule with host and reply") do
      rule = DevDNSd::Rule.create("MATCH", "REPLY")
      rule.match.should == "MATCH"
      rule.reply.should == "REPLY"
      rule.type.should == :A
      rule.block.should be_nil
    end

    it("should create a rule with host, reply and type") do
      rule = DevDNSd::Rule.create("MATCH", "REPLY", "TYPE", {:a => :b})
      rule.match.should == "MATCH"
      rule.reply.should == "REPLY"
      rule.type.should == "TYPE"
      rule.options.should == {:a => :b}
      rule.block.should be_nil
    end

    it("should create a rule with host, type and a reply block") do
      rule = DevDNSd::Rule.create("MATCH", "TYPE", "UNUSED") do end
      rule.match.should == "MATCH"
      rule.reply.should be_nil
      rule.type.should == "TYPE"
      rule.options.should == {}
      rule.block.should_not be_nil
    end
  end

  describe "#resource_class" do
    it("should return a single class") do DevDNSd::Rule.create("MATCH", "REPLY", :A).resource_class.should == Resolv::DNS::Resource::IN::A end
    it("should return an array of classes") do DevDNSd::Rule.create("MATCH", "REPLY", [:A, :MX]).resource_class.should == [Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::MX] end
    it("should fail for a invalid class") do expect { DevDNSd::Rule.create("MATCH", "REPLY", :INVALID).resource_class }.to raise_error(DevDNSd::Errors::InvalidRule) end
  end

  describe "#resource_class_to_symbol" do
    it("should convert a class a symbol") do
      DevDNSd::Rule.resource_class_to_symbol(Resolv::DNS::Resource::IN::A).should == :A
      DevDNSd::Rule.resource_class_to_symbol(Resolv).should == :Resolv
    end
  end

  describe "#symbol_to_resource_class" do
    it("should convert a symbol to a resource class") do DevDNSd::Rule.symbol_to_resource_class(:A).should == Resolv::DNS::Resource::IN::A end
    it("should fail for a invalid class") do expect { DevDNSd::Rule.symbol_to_resource_class(:Invalid) }.to raise_error(DevDNSd::Errors::InvalidRule) end
  end
end