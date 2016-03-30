# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module DevDNSd
  # This class holds the configuration of the application.
  class Configuration < Bovem::Configuration
    # If to run the server in foreground. Default: `false`.
    property :foreground, default: false

    # The addresses to listen to. Default: `["0.0.0.0"]`.
    property :bind_addresses, default: ["0.0.0.0"]

    # The port to listen to. Default: `7771`.
    property :port, default: 7771

    # The TLD to manage. Default: `dev`.
    property :tld, default: "dev"

    # The PID file to use. Default: `~/.devdnsd/daemon.pid`.
    property :pid_file, default: "~/.devdnsd/daemon.pid"

    # The file to log to. Default: `/var/log/daemon.log`.
    property :log_file, default: "~/.devdnsd/daemon.log"

    # The minimum severity to log. Default: `Logger::INFO`.
    property :log_level, default: Logger::INFO

    # The rules of the server. By default, every hostname is resolved with `127.0.0.1`.
    property :rules, default: []

    # The default interface to manage for aliases. Default: `lo0`.
    property :interface, default: "lo0"

    # The default list of aliases to add. Default: `[]`.
    property :addresses, default: []

    # The starting address for sequential aliases. Default: `10.0.0.1`.
    property :start_address, default: "10.0.0.1"

    # The number of aliases to add. Default: `5`.
    property :aliases, default: 5

    # The command to run for adding an alias. Default: `sudo ifconfig {{interface}} alias {{address}}`.
    property :add_command, default: "sudo ifconfig {{interface}} alias {{address}}"

    # The command to run for removing an alias. Default: `sudo ifconfig {{interface}} alias {{address}}`.
    property :remove_command, default: "sudo ifconfig {{interface}} -alias {{address}}"

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
      self.log_file = resolve_log_file

      self.pid_file = File.absolute_path(File.expand_path(pid_file))
      self.port = port.to_integer
      self.log_level = log_level.to_integer

      # Add a default rule
      add_rule(match: /.+/, reply: "127.0.0.1") if rules.blank?
    end

    # Adds a rule to the configuration.
    #
    # @param match [String|Regexp] The pattern to match.
    # @param reply [String|Symbol] The IP or hostname to reply back to the client. It can be omitted (and it will be ignored) if a block is provided.
    # @param type [Symbol] The type of request to match.
    # @param options [Hash] A list of options for the request.
    # @param block [Proc] An optional block to compute the reply instead of using the `reply` parameter.
    # @return [Array] The current set of rule.
    def add_rule(match: /.+/, reply: "127.0.0.1", type: :A, options: {}, &block)
      rules << DevDNSd::Rule.create(match: match, reply: reply, type: type, options: options, &block)
    end

    private

    # :nodoc:
    def resolve_log_file
      case log_file
      when "STDOUT" then $stdout
      when "STDERR" then $stderr
      else File.absolute_path(File.expand_path(log_file))
      end
    end
  end
end
