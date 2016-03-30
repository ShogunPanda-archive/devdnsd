# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module DevDNSd
  # This class encapsulate a rule for matching an hostname.
  #
  # @attribute match
  #   @return [String|Regexp] The pattern to match. Default: `/.+/`.
  # @attribute type
  #   @return [Symbol] The type of request to match. Default: `:A`. @see .create
  # @attribute reply
  #   @return [String] The IP or hostname to reply back to the client. Default: `127.0.0.1`. @see .create
  # @attribute options
  #   @return [Hash] A list of options for the request. Default is an empty hash. Supported key are `:priority` and `:ttl`, both integers
  # @attribute block
  #   @return [Proc] An optional block to compute the reply instead of using the `reply` parameter. @see .create
  class Rule
    attr_accessor :match
    attr_accessor :type
    attr_accessor :reply
    attr_accessor :options
    attr_accessor :block

    # Class methods
    class << self
      # Creates a new rule.
      #
      # @param match [String|Regexp] The pattern to match.
      # @param reply [String|Symbol] The IP or hostname to reply back to the client. It can be omitted (and it will be ignored) if a block is provided.
      # @param type [Symbol] The type of request to match.
      # @param options [Hash] A list of options for the request.
      # @param block [Proc] An optional block to compute the reply instead of using the `reply` parameter.
      # @return [Rule] The new rule.
      def create(match: /.+/, reply: "127.0.0.1", type: :A, options: {}, &block)
        new(match: match, reply: reply, type: type, options: options, &block)
      end

      # Converts a class to the correspondent symbol.
      #
      # @param klass [Class] The class to convert.
      # @return [Symbol] The symbol representation of the class.
      def resource_class_to_symbol(klass)
        klass.to_s.gsub(/(.+::)?(.+)/, "\\2").to_sym
      end

      # Converts a symbol to the correspondent DNS resource class.
      #
      # @param symbol [Symbol] The symbol to convert.
      # @param locale [Symbol] The locale to use for the messages.
      # @return [Symbol] The class associated to the symbol.
      def symbol_to_resource_class(symbol, locale = nil)
        symbol = symbol.to_s.upcase

        begin
          "Resolv::DNS::Resource::IN::#{symbol}".constantize
        rescue ::NameError
          i18n = Bovem::I18n.new(locale, root: "devdnsd", path: ::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/")
          raise(DevDNSd::Errors::InvalidRule, i18n.rule_invalid_resource(symbol))
        end
      end
    end

    # Creates a new rule.
    #
    # @param match [String|Regexp] The pattern to match.
    # @param reply [String|Symbol] The IP or hostname to reply back to the client. It can be omitted (and it will be ignored) if a block is provided.
    # @param type [Symbol] The type of request to match.
    # @param options [Hash] A list of options for the request.
    # @param block [Proc] An optional block to compute the reply instead of using the `reply` parameter.
    # @see .create
    def initialize(match: /.+/, reply: "127.0.0.1", type: :A, options: {}, &block)
      setup(match, reply, type, options, block)
      validate_rule
    end

    # Returns the resource class(es) for the current rule.
    #
    # @return [Array|Class] The class(es) for the current rule.
    def resource_class
      classes = @type.ensure_array(no_duplicates: true, compact: true, flatten: true) { |cls| self.class.symbol_to_resource_class(cls, options[:locale]) }
      classes.length == 1 ? classes.first : classes
    end

    # Checks if the rule is a regexp.
    #
    # @return [Boolean] `true` if the rule is a Regexp, `false` otherwise.
    def regexp?
      @match.is_a?(::Regexp)
    end
    alias_method :is_regexp?, :regexp?

    # Checks if the rule is a regexp.
    #
    # @return [Boolean] `true` if the rule has a block, `false` otherwise.
    def block?
      @block.present?
    end
    alias_method :has_block?, :block?

    # Matches a hostname to the rule.
    #
    # @param hostname [String] The hostname to match.
    # @return [MatchData|Boolean|Nil] Return `true` or MatchData (if the pattern is a regexp) if the rule matches, `false` or `nil` otherwise.
    def match_host(hostname)
      regexp? ? @match.match(hostname) : (@match == hostname)
    end

    private

    # :nodoc:
    def setup(match, reply, type, options, block)
      @match = match

      if block.present? # reply acts like a type, type is ignored
        @type = type || :A
        @reply = nil
      else # reply acts like a reply
        @reply = reply || "127.0.0.1"
        @type = type || :A
      end

      @options = options
      @block = block
      locale = options.is_a?(Hash) ? options[:locale] : :en
      @i18n = Bovem::I18n.new(locale, root: "devdnsd", path: ::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/")
    end

    # Validates a newly created rule.
    def validate_rule
      raise(DevDNSd::Errors::InvalidRule, @i18n.rule_invalid_call) if @reply.blank? && @block.nil?
      raise(DevDNSd::Errors::InvalidRule, @i18n.rule_invalid_options) unless @options.is_a?(::Hash)
    end
  end
end
