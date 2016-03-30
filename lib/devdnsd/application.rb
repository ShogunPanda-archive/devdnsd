# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A small DNS server to enable local .dev domain resolution.
module DevDNSd
  # The main DevDNSd application.
  #
  # @attribute [r] config
  #   @return [Configuration] The {Configuration Configuration} of this application.
  # @attribute [r] server
  #   @return [RubyDNS::RuleBasedServer] The server of this application.
  # @attribute [r] command
  #   @return [Bovem::Command] The Bovem command.
  # @attribute logger
  #   @return [Bovem::Logger] The logger for this application.
  # @attribute [r] locale
  #   @return [Symbol|nil] The current application locale.
  # @attribute [r] :i18n
  #   @return [Bovem::I18n] A localizer object.
  class Application < Process::Daemon
    # Class for ANY DNS request.
    ANY_REQUEST = Resolv::DNS::Resource::IN::ANY

    # List of classes handled in case of DNS request with resource class ANY.
    ANY_CLASSES = [
      Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA, Resolv::DNS::Resource::IN::ANY, Resolv::DNS::Resource::IN::CNAME,
      Resolv::DNS::Resource::IN::HINFO, Resolv::DNS::Resource::IN::MINFO, Resolv::DNS::Resource::IN::MX, Resolv::DNS::Resource::IN::NS,
      Resolv::DNS::Resource::IN::PTR, Resolv::DNS::Resource::IN::SOA, Resolv::DNS::Resource::IN::TXT
    ].freeze

    include DevDNSd::System
    include DevDNSd::Aliases
    include DevDNSd::Server

    attr_reader :config
    attr_reader :command
    attr_accessor :logger
    attr_reader :locale
    attr_reader :i18n
    attr_reader :server

    # Creates a new application.
    #
    # @param command [Bovem::Command] The current Bovem command.
    # @param locale [Symbol] The locale to use for the application.
    def initialize(command, locale)
      @i18n = Bovem::I18n.new(locale, root: "devdnsd", path: ::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/")
      @locale = locale
      @command = command
      options = @command.application.get_options.reject { |_, v| v.nil? }.merge(@command.get_options.reject { |_, v| v.nil? })

      # Setup logger
      create_logger(options)

      # Open configuration
      read_configuration(options)

      super(working_directory)
      self
    end

    # Stops the server.
    def shutdown
      server.actors.first.links.each(&:terminate) if server
    end

    # Gets the current logger of the application.
    #
    # @param force [Boolean] If to force recreation of the logger.
    # @return [Logger] The current logger of the application.
    def logger(force = false)
      @logger = nil if force
      @logger ||= Bovem::Logger.create(@config.foreground ? $stdout : @config.log_file, level: @config.log_level, formatter: @log_formatter)
    end

    # This method is called when the server starts. By default is a no-op.
    #
    # @return [NilClass] `nil`.
    def on_start
    end

    # This method is called when the server stop.
    #
    # @return [NilClass] `nil`.
    def on_stop
    end

    # Returns a unique (singleton) instance of the application.
    #
    # @param command [Bovem::Command] The current Bovem command.
    # @param locale [Symbol] The locale to use for the application.
    # @param force [Boolean] If to force recreation of the instance.
    # @return [Application] The unique (singleton) instance of the application.
    def self.instance(command = nil, locale = nil, force = false)
      @instance = nil if force
      @instance ||= DevDNSd::Application.new(command, locale) if command
      @instance
    end

    # Runs the application in foreground.
    #
    # @see #perform_server
    def self.run
      instance.perform_server
    end

    # Stops the application.
    def self.quit
      instance.shutdown
    rescue
      Kernel.exit(1)
    end

    # Check if the current implementation supports DevDNSd.
    def self.check_ruby_implementation
      if defined?(JRuby)
        Kernel.puts(Bovem::I18n.new(root: "devdnsd", path: ::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/").no_jruby)
        Kernel.exit(0)
      end
    end

    private

    # :nodoc:
    def create_logger(options)
      warn_failure = false
      orig_file = file = Bovem::Logger.get_real_file(options["log_file"]) || Bovem::Logger.default_file

      if file.is_a?(String)
        file, warn_failure = load_logger(File.absolute_path(File.expand_path(file)), options)
      end

      finalize_create_logger(file, orig_file, warn_failure)
    end

    # :nodoc:
    def load_logger(file, options)
      warn_failure = false

      begin
        FileUtils.mkdir_p(File.dirname(file))
        @logger = Bovem::Logger.create(file, level: ::Logger::INFO)
      rescue
        options["log_file"] = "STDOUT"
        file = $stdout
        warn_failure = true
      end

      [file, warn_failure]
    end

    # :nodoc:
    def finalize_create_logger(file, orig_file, warn_failure)
      @logger = Bovem::Logger.create(file, level: ::Logger::INFO)
      @logger.warn(replace_markers(i18n.logging_failed(orig_file))) if @logger && warn_failure
      @logger
    end

    # :nodoc:
    def read_configuration(options)
      path = ::File.absolute_path(File.expand_path(options["configuration"]))

      begin
        @config = DevDNSd::Configuration.new(path, options, @logger)
        ensure_directory_for(@config.log_file) if @config.log_file.is_a?(String)
        ensure_directory_for(@config.pid_file)
        @logger = logger(true)
      rescue Bovem::Errors::InvalidConfiguration => e
        log_failed_configuration(path, e)
        shutdown
      end
    end

    # :nodoc:
    def ensure_directory_for(path)
      FileUtils.mkdir_p(File.dirname(path))
    rescue
      @logger.warn(replace_markers(i18n.invalid_directory(File.dirname(path))))
      shutdown
      Kernel.exit(1)
    end

    # :nodoc:
    def log_failed_configuration(path, exception)
      logger = Bovem::Logger.create($stderr)
      logger.fatal(exception.message)
      logger.warn(replace_markers(i18n.application_create_config(path)))
    end
  end
end
