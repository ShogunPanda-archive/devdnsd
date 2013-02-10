# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
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
  #   @return [Hash] A list of options for the request. Default is an empty hash.
  # @attribute block
  #   @return [Proc] An optional block to compute the reply instead of using the `reply` parameter. @see .create
  class Rule
    attr_accessor :match
    attr_accessor :type
    attr_accessor :reply
    attr_accessor :options
    attr_accessor :block

    include Lazier::I18n

    # Creates a new rule.
    #
    # @param match [String|Regexp] The pattern to match.
    # @param reply [String] The IP or hostname to reply back to the client.
    # @param type [Symbol] The type of request to match.
    # @param options [Hash] A list of options for the request.
    # @param block [Proc] An optional block to compute the reply instead of using the `reply` parameter.
    # @see .create
    def initialize(match = /.+/, reply = "127.0.0.1", type = :A, options = {}, &block)
      self.i18n_setup(:devdnsd, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"))
      self.i18n = options[:locale]
      setup(match, reply, type, options, block)
      validate_rule
    end

    # Returns the resource class(es) for the current rule.
    #
    # @return [Array|Class] The class(es) for the current rule.
    def resource_class
      classes = @type.ensure_array.collect {|cls| self.class.symbol_to_resource_class(cls, options[:locale]) }.compact.uniq
      classes.length == 1 ? classes.first : classes
    end

    # Checks if the rule is a regexp.
    #
    # @return [Boolean] `true` if the rule is a Regexp, `false` otherwise.
    def is_regexp?
      @match.is_a?(::Regexp)
    end

    # Checks if the rule is a regexp.
    #
    # @return [Boolean] `true` if the rule has a block, `false` otherwise.
    def has_block?
      @block.present?
    end

    # Matches a hostname to the rule.
    #
    # @param hostname [String] The hostname to match.
    # @return [MatchData|Boolean|Nil] Return `true` or MatchData (if the pattern is a regexp) if the rule matches, `false` or `nil` otherwise.
    def match_host(hostname)
      self.is_regexp? ? @match.match(hostname) : (@match == hostname)
    end

    # Creates a new rule.
    #
    # @param match [String|Regexp] The pattern to match.
    # @param reply_or_type [String|Symbol] The IP or hostname to reply back to the client (or the type of request to match, if a block is provided).
    # @param type [Symbol] The type of request to match. This is ignored if a block is provided.
    # @param options [Hash] A list of options for the request.
    # @param block [Proc] An optional block to compute the reply instead of using the `reply_or_type` parameter. In this case `reply_or_type` is used for the type of the request and `type` is ignored.
    # @return [Rule] The new rule.
    def self.create(match, reply_or_type = nil, type = nil, options = {}, &block)
      validate_options(reply_or_type, options, block, Lazier::Localizer.new(:devdnsd, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"), options.is_a?(Hash) ? options[:locale] : nil))
      setup(self.new(match), reply_or_type, type, options, block)
    end

    # Converts a class to the correspondent symbol.
    #
    # @param klass [Class] The class to convert.
    # @return [Symbol] The symbol representation of the class.
    def self.resource_class_to_symbol(klass)
      klass.to_s.gsub(/(.+::)?(.+)/, "\\2").to_sym
    end

    # Converts a symbol to the correspondent DNS resource class.
    #
    # @param symbol [Symbol] The symbol to convert.
    # @param locale [Symbol] The locale to use for the messages.
    # @return [Symbol] The class associated to the symbol.
    def self.symbol_to_resource_class(symbol, locale = nil)
      symbol = symbol.to_s.upcase

      begin
        "Resolv::DNS::Resource::IN::#{symbol}".constantize
      rescue ::NameError
        raise(DevDNSd::Errors::InvalidRule.new(Lazier::Localizer.new(:devdnsd, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"), locale).i18n.invalid_class(symbol)))
      end
    end

    private
      # Setups a new rule.
      #
      # @param match [String|Regexp] The pattern to match.
      # @param reply [String] The IP or hostname to reply back to the client.
      # @param type [Symbol] The type of request to match.
      # @param options [Hash] A list of options for the request.
      # @param block [Proc] An optional block to compute the reply instead of using the `reply` parameter.
      def setup(match, reply, type, options, block)
        @match = match
        @type = type || :A
        @reply = block.blank? ? (reply || "127.0.0.1") : nil
        @options = options
        @block = block
      end

      # Validates a newly created rule.
      def validate_rule
        raise(DevDNSd::Errors::InvalidRule.new(self.i18n.rule_invalid_call)) if @reply.blank? && @block.nil?
        raise(DevDNSd::Errors::InvalidRule.new(self.i18n.rule_invalid_options)) if !@options.is_a?(::Hash)
      end

      # Setups a new rule.
      #
      # @param rv [Rule] The rule that is been created.
      # @param reply_or_type [String|Symbol] The IP or hostname to reply back to the client (or the type of request to match, if a block is provided).
      # @param type [Symbol] The type of request to match. This is ignored if a block is provided.
      # @param options [Hash] A list of options for the request.
      # @param block [Proc] An optional block to compute the reply instead of using the `reply_or_type` parameter. In this case `reply_or_type` is used for the type of the request and `type` is ignored.
      # @return [Rule] The new rule.
      def self.setup(rv, reply_or_type, type, options = {}, block)
        rv.options = options
        rv.block = block

        if block.present? then # reply_or_type acts like a type, type is ignored
          rv.type = reply_or_type || :A
          rv.reply = nil
        else # reply_or_type acts like a reply
          rv.reply = reply_or_type || "127.0.0.1"
          rv.type = type || :A
        end

        rv
      end

      # Validate options for a new rule creation.
      #
      # @param reply_or_type [String|Symbol] The IP or hostname to reply back to the client (or the type of request to match, if a block is provided).
      # @param options [Hash] A list of options for the request.
      # @param block [Proc] An optional block to compute the reply instead of using the `reply_or_type` parameter. In this case `reply_or_type` is used for the type of the request and `type` is ignored.
      # @param localizer [Localizer] A localizer object.
      def self.validate_options(reply_or_type, options, block, localizer)
        raise(DevDNSd::Errors::InvalidRule.new(localizer.i18n.rule_invalid_call)) if reply_or_type.blank? && block.nil?
        raise(DevDNSd::Errors::InvalidRule.new(localizer.i18n.rule_invalid_options)) if !options.is_a?(::Hash)
      end
  end
end
