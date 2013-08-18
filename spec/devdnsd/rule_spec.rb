# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe DevDNSd::Rule do
  describe "#new" do
    it "should create a default rule" do
      rule = DevDNSd::Rule.new
      expect(rule.match).to eq(/.+/)
      expect(rule.reply).to eq("127.0.0.1")
      expect(rule.type).to eq(:A)
      expect(rule.options).to eq({})
      expect(rule.block).to be_nil
    end

    it "should create a rule with arguments and no block" do
      rule = DevDNSd::Rule.new("MATCH", "REPLY", "TYPE", {a: :b})
      expect(rule.match).to eq("MATCH")
      expect(rule.reply).to eq("REPLY")
      expect(rule.type).to eq("TYPE")
      expect(rule.options).to eq({a: :b})
      expect(rule.block).to be_nil
    end

    it "should create a rule with arguments and a block" do
      rule = DevDNSd::Rule.new("MATCH", "REPLY", "TYPE") do end
      expect(rule.match).to eq("MATCH")
      expect(rule.reply).to be_nil
      expect(rule.type).to eq("TYPE")
      expect(rule.options).to eq({})
      expect(rule.block).not_to be_nil
    end
  end

  describe "#is_regexp?" do
    it "should return true for a regexp pattern" do
      expect(DevDNSd::Rule.create(/.+/, "127.0.0.1").is_regexp?).to be_true
    end

    it "should return false otherwise" do
      expect(DevDNSd::Rule.create("RULE", "127.0.0.1").is_regexp?).to be_false
    end
  end

  describe "#has_block?" do
    it "should return true when a block is present" do
      expect(DevDNSd::Rule.create("RULE"){}.has_block?).to be_true
    end

    it "should return false otherwise" do
      expect(DevDNSd::Rule.create("RULE", "127.0.0.1").has_block?).to be_false
    end
  end

  describe "#match_host" do
    describe "with a string pattern" do
      it "should return true when hostname matches" do
        expect(DevDNSd::Rule.create("match.dev", "127.0.0.1").match_host("match.dev")).to be_true
      end

      it "should return false when hostname doesn't match" do
        expect(DevDNSd::Rule.create("match.dev", "127.0.0.1").match_host("unmatch.dev")).to be_false
      end
    end

    describe "with a regexp pattern" do
      it "should return a MatchData when hostname matches" do
        expect(DevDNSd::Rule.create(/^match/, "127.0.0.1").match_host("match.dev")).to be_a(MatchData)
      end

      it "should return nil when hostname doesn't match" do
        expect(DevDNSd::Rule.create(/^match/, "127.0.0.1").match_host("unmatch.dev")).to be_nil
      end
    end
  end

  describe "::create" do
    it "should not allow rules without sufficient arguments" do
      expect{ DevDNSd::Rule.create("RULE") }.to raise_error(DevDNSd::Errors::InvalidRule)
      expect{ DevDNSd::Rule.create("RULE", "REPLY", "TYPE", "ARG") }.to raise_error(DevDNSd::Errors::InvalidRule)
    end

    it "should create a rule with host and reply" do
      rule = DevDNSd::Rule.create("MATCH", "REPLY")
      expect(rule.match).to eq("MATCH")
      expect(rule.reply).to eq("REPLY")
      expect(rule.type).to eq(:A)
      expect(rule.block).to be_nil
    end

    it "should create a rule with host, reply and type" do
      rule = DevDNSd::Rule.create("MATCH", "REPLY", "TYPE", {a: :b})
      expect(rule.match).to eq("MATCH")
      expect(rule.reply).to eq("REPLY")
      expect(rule.type).to eq("TYPE")
      expect(rule.options).to eq({a: :b})
      expect(rule.block).to be_nil
    end

    it "should create a rule with host, type and a reply block" do
      rule = DevDNSd::Rule.create("MATCH", "TYPE", "UNUSED") do end
      expect(rule.match).to eq("MATCH")
      expect(rule.reply).to be_nil
      expect(rule.type).to eq("TYPE")
      expect(rule.options).to eq({})
      expect(rule.block).not_to be_nil
    end
  end

  describe "#resource_class" do
    it "should return a single class" do
      expect(DevDNSd::Rule.create("MATCH", "REPLY", :A).resource_class).to eq(Resolv::DNS::Resource::IN::A)
    end

    it "should return an array of classes" do
      expect(DevDNSd::Rule.create("MATCH", "REPLY", [:A, :MX]).resource_class).to eq([Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::MX])
    end

    it "should fail for a invalid class" do
      expect { DevDNSd::Rule.create("MATCH", "REPLY", :INVALID).resource_class }.to raise_error(DevDNSd::Errors::InvalidRule)
    end
  end

  describe "::resource_class_to_symbol" do
    it "should convert a class a symbol" do
      expect(DevDNSd::Rule.resource_class_to_symbol(Resolv::DNS::Resource::IN::A)).to eq(:A)
      expect(DevDNSd::Rule.resource_class_to_symbol(Resolv)).to eq(:Resolv)
    end
  end

  describe "::symbol_to_resource_class" do
    it "should convert a symbol to a resource class" do
      expect(DevDNSd::Rule.symbol_to_resource_class(:A, :en)).to eq(Resolv::DNS::Resource::IN::A)
    end

    it "should fail for a invalid class" do
      expect { DevDNSd::Rule.symbol_to_resource_class(:Invalid, :en) }.to raise_error(DevDNSd::Errors::InvalidRule)
    end
  end
end