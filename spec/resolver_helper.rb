# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun_panda@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# Resolvs an hostname to a nameserver.
#
# @param [String] The hostname to resolv.
# @param [String] The type of query to issue.
# @param [String] The nameserver to connect to.
# @param [Fixnum] The port to connect to.
# @param [Logger] A logger for the resolver.
# @return [Array|NilClass] Return an array of pair of addresses and types. `nil` is returned if nothing is found.
def devdnsd_resolv(address = "match.dev", type = "ANY", nameserver = "127.0.0.1", port = 7771, logger = nil)
  resolver = Fiber.current
  rv = []

  port = port.to_i
  logger = Bovem::Logger.new("/dev/null", Bovem::Logger::DEBUG) if !logger
  logger.info(::Bovem::Console.replace_markers("Resolving address {mark=bright}#{address}{/mark} with type {mark=bright}#{type}{/mark} at nameserver {mark=bright}#{nameserver}{/mark}:{mark=bright}#{port.to_s}{/mark} ..."))

  RubyDNS::Resolver.new([[:udp, nameserver, port], [:tcp, nameserver, port]]).query(address, "Resolv::DNS::Resource::IN::#{type}".constantize) do |response|
    begin
      if response.is_a?(RubyDNS::Message) then
        response.answer.each do |answer|
          type = answer[2].class.to_s.split("::")[-1].to_sym

          name = case type
            when :MX then answer[2].exchange.to_s.gsub(/\.$/, "")
            when :CNAME then answer[2].name.to_s.gsub(/\.$/, "")
            when :NS then answer[2].name.to_s.gsub(/\.$/, "")
            when :PTR then answer[2].name.to_s.gsub(/\.$/, "")
            else answer[2].address.to_s
          end

          rv << [name, type]
        end
      end
    rescue => e
      logger.error("[#{e.class}] #{e.to_s}")
    end

    resolver.resume
  end

  Fiber.yield
  rv.uniq!
  logger.info("Resolving ended with result: #{rv.inspect}")
  rv.length == 1 ? rv[0] : rv
end