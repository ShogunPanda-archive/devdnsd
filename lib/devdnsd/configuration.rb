# encoding: utf-8
#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module DevDNSd
  # This class holds the configuration of the applicaton.
  class Configuration
    # If to run the server in foreground. Default: `false`.
    attr_accessor :foreground

    # The address to listen to. Default: `0.0.0.0`.
    attr_accessor :address

    # The port to listen to. Default: `7771`.
    attr_accessor :port

    # The TLD to manage. Default: `dev`.
    attr_accessor :tld

    # The file to log to. Default: `/var/log/devdnsd.log`.
    attr_accessor :log_file

    # The minimum severity to log. Default: `Logger::INFO`.
    attr_accessor :log_level

    # The rules of the server. By default, every hostname is resolved with `127.0.0.1`.
    attr_accessor :rules

    # Creates a new configuration.
    # A configuration file is a plain Ruby file with a top-level {Configuration config} object.
    #
    # Example:
    #
    # ```ruby
    # config.add_rule("match.dev", "10.0.0.1")
    # ```
    #
    # @param file [String] The file to read.
    # @param application [Application] The application which this configuration is attached to.
    # @param overrides [Hash] A set of values which override those set in the configuration file.
    def initialize(file = nil, application = nil, overrides = {})
      @address = "0.0.0.0"
      @port = 7771
      @tld = "dev"
      @log_file = "/var/log/devdnsd.log"
      @log_level = ::Logger::INFO
      @rules = []
      @foreground = false

      if file.present?
        begin
          # Open the file
          path = ::Pathname.new(file).realpath
          application.logger.info("Using configuration file #{path}.") if application
          self.tap do |config|
            eval(::File.read(path))
          end

          @log_file = $stdout if @log_file == "STDOUT"
          @log_file = $stderr if @log_file == "STDERR"
        rescue ::Errno::ENOENT, ::LoadError
        rescue ::Exception => e
          raise DevDNSd::Errors::InvalidConfiguration.new("Config file #{file} is not valid.")
        end
      end

      # Apply overrides
      if overrides.is_a?(::Hash) then
        overrides.each_pair do |k, v|
          self.send("#{k}=", v) if self.respond_to?("#{k}=") && !v.nil?
        end
      end

      # Make sure some arguments are of correct type
      @port = @port.to_integer
      @log_level = @log_level.to_integer

      # Add a default rule
      self.add_rule(/.+/, "127.0.0.1") if @rules.length == 0
    end

    # Adds a rule to the configuration.
    #
    # @param args [Array] The rule's arguments.
    # @param block [Proc] An optional block for the rule.
    # @return [Array] The current set of rule.
    # @see Rule.create
    def add_rule(*args, &block)
      @rules << DevDNSd::Rule.create(*args, &block)
    end
  end
end