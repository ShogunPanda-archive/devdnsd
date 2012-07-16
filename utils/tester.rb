#!/usr/bin/env ruby
# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

basedir = File.expand_path(File.dirname(__FILE__))
require "rubygems"
require "logger"
require "rainbow"
require "active_support/all"
require "net/dns"
require basedir + "/../lib/devdnsd/logger"

# Patch to avoid resolving of hostname containing numbers.
class Net::DNS::Resolver
  def is_ip_address?(addr)
    catch(:valid_ip) do
      if /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\Z/ =~ addr
        throw(:valid_ip, true) if $~.captures.all? {|i| i.to_i < 256}
      else
        # IPv6 (normal)
        throw(:valid_ip, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*\Z/ =~ addr
        throw(:valid_ip, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*)?\Z/ =~ addr
        throw(:valid_ip, true) if /\A::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*)?\Z/ =~ addr
        # IPv6 (IPv4 compat)
        throw(:valid_ip, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:/ =~ addr && valid_v4?($')
        throw(:valid_ip, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:)?/ =~ addr && valid_v4?($')
        throw(:valid_ip, true) if /\A::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:)?/ =~ addr && valid_v4?($')
      end

      false
    end
  end

  def make_query_packet(string, type, cls)
    if string.is_a?(IPAddr) then
      name = string.reverse
      type = Net::DNS::PTR
      @logger.warn "PTR query required for address #{string}, changing type to PTR"
    elsif is_ip_address?(string) # See if it's an IP or IPv6 address
      begin
        name = IPAddr.new(string.chomp(".")).reverse
        type = Net::DNS::PTR
      rescue ArgumentError
        name = string if valid? string
      end
    else
      name = string if valid? string
    end

    # Create the packet
    packet = Net::DNS::Packet.new(name, type, cls)

    if packet.query?
      packet.header.recursive = @config[:recursive] ? 1 : 0
    end

    # DNSSEC and TSIG stuff to be inserted here

    packet
  end
end

# Resolvs an hostname to a nameserver.
#
# @param [String] The hostname to resolv.
# @param [String] The type of query to issue.
# @param [String] The nameserver to connect to.
# @param [Fixnum] The port to connect to.
# @param [Logger] A logger for the resolver.
# @return [Array|NilClass] Return an array of pair of addresses and types. `nil` is returned if nothing is found.
def devdnsd_resolv(address = "match.dev", type = "ANY", nameserver = "127.0.0.1", port = 7771, logger = nil)
  rv = []

  logger = DevDNSd::Logger.new("/dev/null", DevDNSd::Logger::DEBUG) if !logger
  logger.info("Resolving address #{address.bright} with type #{type.to_s.bright} at nameserver #{nameserver.bright}:#{port.to_s.bright} ...")
  tmpfile = "/tmp/devdnsd-test-tester-#{Time.now.strftime("%Y%m%d-%H:%M:%S")}"

  begin
    resolver = Net::DNS::Resolver.new(:nameservers => nameserver, :port => port.to_i, :recursive => false, :udp_timeout => 1, :log_file => tmpfile)
    response = resolver.search(address, type)

    response.answer.each do |answer|
      type = answer.type.upcase.to_sym
      result = ""

      case type
        when :MX
          result = answer.exchange.gsub(/\.$/, "")
        when :CNAME
          result = answer.cname.gsub(/\.$/, "")
        when :NS
          result = answer.nsdname.gsub(/\.$/, "")
        when :PTR
          result = answer.ptrdname.gsub(/\.$/, "")
        else
          result = answer.address.to_s
      end

      rv << [result, type]
    end

    rv = case rv.length
      when 0 then nil
      when 1 then rv[0]
      else rv
    end
  rescue Exception => e
    logger.error("[#{e.class}] #{e.to_s}")
  end

  File.unlink(tmpfile) if File.exists?(tmpfile)
  logger.info("Resolving ended with result: #{rv.inspect}")
  rv
end

if __FILE__ == $0 then
  address = ARGV[0] || "match.dev"
  type = (ARGV[1] || "ANY").upcase
  nameserver = ARGV[2] || "127.0.0.1"
  port = ARGV[3] || 7771
  logger = DevDNSd::Logger.create($stdout, Logger::DEBUG)

  devdnsd_resolv(address, type, nameserver, port, logger)
end