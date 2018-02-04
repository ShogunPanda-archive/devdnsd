# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

# A small DNS server to enable local .dev domain resolution.
module DevDNSd
  # Methods to process requests.
  module Server
    # Starts the DNS server.
    #
    # @return [Object] The result of stop callbacks.
    def perform_server
      application = self

      @server = RubyDNS.run_server(server_options) do
        self.logger = application.logger

        match(/.+/, DevDNSd::Application::ANY_CLASSES) do |transaction, match_data|
          # During debugging, wrap the inside of the block with a begin rescue and PRINT the exception because RubyDNS hides it.
          application.config.rules.each { |rule| application.process_rule_in_classes(rule, match_data, transaction) }
        end

        # Default DNS handler and event handlers
        otherwise { |transaction| transaction.failure!(:NXDomain) }
        on(:start) { application.on_start }
        on(:stop) { application.on_stop }
      end
    end

    alias_method :startup, :perform_server

    # Processes a DNS rule.
    #
    # @param rule [Rule] The rule to process.
    # @param type [Symbol] The type of the query.
    # @param match_data [MatchData|nil] If the rule pattern was a Regexp, then this holds the match data, otherwise `nil` is passed.
    # @param transaction [RubyDNS::Transaction] The current DNS transaction (http://rubydoc.info/gems/rubydns/RubyDNS/Transaction).
    def process_rule(rule, type, match_data, transaction)
      reply, type = perform_process_rule(rule, type, match_data, transaction)
      logger.debug(reply ? i18n.reply(reply, type) : i18n.no_reply)

      if reply
        transaction.respond!(*finalize_reply(reply, rule, type))
      else
        reply.is_a?(FalseClass) ? false : nil
      end
    end

    # Processes a rule against a set of DNS resource classes.
    #
    # @param rule [Rule] The rule to process.
    # @param match_data [MatchData|nil] If the rule pattern was a Regexp, then this holds the match data, otherwise `nil` is passed.
    # @param transaction [RubyDNS::Transaction] The current DNS transaction (http://rubydoc.info/gems/rubydns/RubyDNS/Transaction).
    def process_rule_in_classes(rule, match_data, transaction)
      # Get the subset of handled class that is valid for the rule
      resource_classes = DevDNSd::Application::ANY_CLASSES & rule.resource_class.ensure_array
      resource_classes &= [transaction.resource_class] if transaction.resource_class != DevDNSd::Application::ANY_REQUEST

      if resource_classes.present?
        resource_classes.each do |resource_class| # Now for every class
          matches = rule.match_host(match_data[0])
          process_rule(rule, resource_class, rule.regexp? ? matches : nil, transaction) if matches
        end
      end
    end

    private

    # :nodoc:
    def server_options
      {asynchronous: !@config.foreground, listen: build_listen_interfaces}
    end

    # :nodoc:
    def build_listen_interfaces
      port = @config.port.to_integer
      @config.bind_addresses.ensure_array { |address| [:udp, address, port] } + @config.bind_addresses.ensure_array { |address| [:tcp, address, port] }
    end

    # :nodoc:
    def perform_process_rule(rule, type, match_data, transaction)
      type = DevDNSd::Rule.resource_class_to_symbol(type)
      reply = execute_rule(transaction, rule, type, match_data)

      logger.debug(i18n.match(rule.match, type))
      [reply, type]
    end

    # :nodoc:
    def execute_rule(transaction, rule, type, match_data)
      reply = rule.block ? rule.block.call(match_data, type, transaction) : rule.reply
      reply = match_data[0].gsub(rule.match, reply.gsub("$", "\\")) if rule.match.is_a?(::Regexp) && reply && match_data && match_data[0]
      reply
    end

    # :nodoc:
    def finalize_reply(reply, rule, type)
      rv = []
      rv << rule.options.delete(:priority).to_integer(10) if type == :MX
      rv << ([:A, :AAAA].include?(type) ? reply : Resolv::DNS::Name.create(reply))
      rv << prepare_reply_options(rule, type)
      rv
    end

    # :nodoc:
    def prepare_reply_options(rule, type)
      rule.options.merge({resource_class: DevDNSd::Rule.symbol_to_resource_class(type, @locale), ttl: validate_ttl(rule.options.delete(:ttl))})
    end

    # :nodoc:
    def validate_ttl(current, default = 300)
      current = current.to_integer
      current > 0 ? current : default
    end
  end
end
