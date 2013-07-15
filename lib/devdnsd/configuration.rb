# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module DevDNSd
  # This class holds the configuration of the application.
  class Configuration < Bovem::Configuration
    # If to run the server in foreground. Default: `false`.
    property :foreground, default: false

    # The address to listen to. Default: `0.0.0.0`.
    property :address, default: "0.0.0.0"

    # The port to listen to. Default: `7771`.
    property :port, default: 7771

    # The TLD to manage. Default: `dev`.
    property :tld, default: "dev"

    # The PID file to use. Default: `/var/run/devdnsd.pid`.
    property :pid_file, default: "/var/log/devdnsd.pid"

    # The file to log to. Default: `/var/log/devdnsd.log`.
    property :log_file, default: "/var/log/devdnsd.log"

    # The minimum severity to log. Default: `Logger::INFO`.
    property :log_level, default: Logger::INFO

    # The rules of the server. By default, every hostname is resolved with `127.0.0.1`.
    property :rules, default: []

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
    # @param overrides [Hash] A set of values which override those set in the configuration file.
    # @param logger [Logger] The logger to use for notifications.
    def initialize(file = nil, overrides = {}, logger = nil)
      super(file, overrides, logger)

      # Make sure some arguments are of correct type
      self.log_file = $stdout if log_file == "STDOUT"
      self.log_file = $stderr if log_file == "STDERR"
      self.port = port.to_integer
      self.log_level = log_level.to_integer

      # Add a default rule
      add_rule(/.+/, "127.0.0.1") if rules.blank?
    end

    # Adds a rule to the configuration.
    #
    # @param args [Array] The rule's arguments.
    # @param block [Proc] An optional block for the rule.
    # @return [Array] The current set of rule.
    # @see Rule.create
    def add_rule(*args, &block)
      rules << DevDNSd::Rule.create(*args, &block)
    end
  end
end
