# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module DevDNSd
  # This class encapsulate a rule for matching an hostname.
  class Rule
    # The pattern to match. Default: `/.+/`.
    attr_accessor :match

    # The type of request to match. Default: `:A`.
    #
    # @see .create
    attr_accessor :type

    # The IP or hostname to reply back to the client. Default: `127.0.0.1`.
    #
    # @see .create
    attr_accessor :reply

    # A list of options for the request. Default is an empty hash.
    attr_accessor :options

    # An optional block to compute the reply instead of using the `reply` parameter.
    #
    # @see .create
    attr_accessor :block

    # Creates a new rule.
    #
    # @param match [String|Regexp] The pattern to match.
    # @param reply [String] The IP or hostname to reply back to the client.
    # @param type [Symbol] The type of request to match.
    # @param options [Hash] A list of options for the request.
    # @param block [Proc] An optional block to compute the reply instead of using the `reply` parameter.
    # @see .create
    def initialize(match = /.+/, reply = "127.0.0.1", type = :A, options = {}, &block)
      reply ||= "127.0.0.1"
      type ||= :A
      @match = match
      @type = type
      @reply = block.blank? ? reply : nil
      @options = options
      @block = block

      raise(DevDNSd::Errors::InvalidRule.new("You must specify at least a rule and a host (also via a block). Optionally you can add a record type (default: A) and the options.")) if @reply.blank? && @block.nil?
      raise(DevDNSd::Errors::InvalidRule.new("You can only use hashs for options.")) if !@options.is_a?(::Hash)
    end

    # Returns the resource class(es) for the current rule.
    #
    # @return [Array|Class] The class(es) for the current rule.
    def resource_class
      classes = self.type.ensure_array.collect {|cls| self.class.symbol_to_resource_class(cls) }.compact.uniq
      classes.length == 1 ? classes.first : classes
    end

    # Checks if the rule is a regexp.
    #
    # @return [Boolean] `true` if the rule is a Regexp, `false` otherwise.
    def is_regexp?
      self.match.is_a?(::Regexp)
    end

    # Checks if the rule is a regexp.
    #
    # @return [Boolean] `true` if the rule has a block, `false` otherwise.
    def has_block?
      self.block.present?
    end

    # Matches a hostname to the rule.
    #
    # @param hostname [String] The hostname to match.
    # @return [MatchData|Boolean|Nil] Return `true` or MatchData (if the pattern is a regexp) if the rule matches, `false` or `nil` otherwise.
    def match_host(hostname)
      self.is_regexp? ? self.match.match(hostname) : (self.match == hostname)
    end

    # Creates a new rule.
    #
    # @param match [String|Regexp] The pattern to match.
    # @param reply_or_type [String|Symbol] The IP or hostname to reply back to the client (or the type of request to match, if a block is provided).
    # @param type [Symbol] The type of request to match. This is ignored if a block is provided.
    # @param options [Hash] A list of options for the request.
    # @param block [Proc] An optional block to compute the reply instead of using the `reply_or_type` parameter. In this case `reply_or_type` is used for the type of the request and `type` is ignored.
    def self.create(match, reply_or_type = nil, type = nil, options = {}, &block)
      raise(DevDNSd::Errors::InvalidRule.new("You must specify at least a rule and a host (also via a block). Optionally you can add a record type (default: A) and the options.")) if reply_or_type.blank? && block.nil?
      raise(DevDNSd::Errors::InvalidRule.new("You can only use hashs for options.")) if !options.is_a?(::Hash)

      rv = self.new(match)
      rv.options = options

      if block.present? then # reply_or_type acts like a type, type is ignored
        rv.type = reply_or_type || :A
        rv.reply = nil
        rv.block = block
      else # reply_or_type acts like a reply
        rv.reply = reply_or_type || "127.0.0.1"
        rv.type = type || :A
      end

      rv
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
    # @return [Symbol] The class associated to the symbol.
    def self.symbol_to_resource_class(symbol)
      symbol = symbol.to_s.upcase

      begin
        "Resolv::DNS::Resource::IN::#{symbol}".constantize
      rescue ::NameError
        raise(DevDNSd::Errors::InvalidRule.new("Invalid resource class #{symbol}."))
      end
    end
  end
end
