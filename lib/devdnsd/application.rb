# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A small DNS server to enable local .dev domain resolution.
module DevDNSd
  # Methods for the {Application Application} class.
  module ApplicationMethods
    # System management methods.
    module System
      extend ActiveSupport::Concern

      # Class methods.
      module ClassMethods
        # Returns the name of the daemon.
        #
        # @return [String] The name of the daemon.
        def daemon_name
          File.basename(self.instance.config.pid_file, ".pid")
        end

        # Returns the standard location of the PID file.
        #
        # @return [String] The standard location of the PID file.
        def pid_directory
          File.dirname(self.instance.config.pid_file)
        end

        # Returns the complete path of the PID file.
        #
        # @return [String] The complete path of the PID file.
        def pid_fn
          self.instance.config.pid_file
        end
      end

      # Gets the path for the resolver file.
      #
      # @param tld [String] The TLD to manage.
      # @return [String] The path for the resolver file.
      def resolver_path(tld = nil)
        tld ||= @config.tld
        "/etc/resolver/#{tld}"
      end

      # Gets the path for the launch agent file.
      #
      # @param name [String] The base name for the agent.
      # @return [String] The path for the launch agent file.
      def launch_agent_path(name = "it.cowtech.devdnsd")
        ENV["HOME"] + "/Library/LaunchAgents/#{name}.plist"
      end

      # Executes a shell command.
      #
      # @param command [String] The command to execute.
      # @return [Boolean] `true` if command succeeded, `false` otherwise.
      def execute_command(command)
        system(command)
      end

      # Updates DNS cache.
      #
      # @return [Boolean] `true` if command succeeded, `false` otherwise.
      def dns_update
        @logger.info(self.i18n.dns_update)
        self.execute_command("dscacheutil -flushcache")
      end

      # Checks if we are running on MacOS X.
      #
      # System services are only available on that platform.
      #
      # @return [Boolean] `true` if the current platform is MacOS X, `false` otherwise.
      def is_osx?
        ::RbConfig::CONFIG['host_os'] =~ /^darwin/
      end

      # Starts the server in background.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_start
        self.get_logger.info(self.i18n.starting)

        if !Process.respond_to?(:fork) then
          self.logger.warn(self.i18n.no_fork)
          @config.foreground = true
        end

        @config.foreground ? self.perform_server : RExec::Daemon::Controller.start(self.class)
        true
      end

      # Stops the server in background.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_stop
        RExec::Daemon::Controller.stop(self.class)
        true
      end

      # Installs the application into the autolaunch.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_install
        manage_installation(self.launch_agent_path, self.resolver_path, :create_resolver, :create_agent, :load_agent)
      end

      # Uninstalls the application from the autolaunch.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_uninstall
        manage_installation(self.launch_agent_path, self.resolver_path, :delete_resolver, :unload_agent, :delete_agent)
      end

      private
        # Manages a OSX agent.
        #
        # @param launch_agent [String] The agent path.
        # @param resolver_path [String] The resolver path.
        # @param first_operation [Symbol] The first operation to execute.
        # @param second_operation [Symbol] The second operation to execute.
        # @param third_operation [Symbol] The third operation to execute.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def manage_installation(launch_agent, resolver_path, first_operation, second_operation, third_operation)
          rv = true

          rv = check_agent_available
          rv = send(first_operation, launch_agent, resolver_path) if rv
          rv = send(second_operation, launch_agent, resolver_path) if rv
          rv = send(third_operation, launch_agent, resolver_path) if rv
          self.dns_update
          rv
        end

        # Deletes a file
        #
        # @param file [String] The file to delete.
        # @param before_message [Symbol] The message to show before deleting.
        # @param error_message [Symbol] The message to show in case of errors.
        # @return [Boolean] `true` if the file have been deleted, `false` otherwise.
        def delete_file(file, before_message, error_message)
          begin
            self.logger.info(self.i18n.send(before_message, file))
            ::File.delete(file)
            true
          rescue => e
            self.logger.warn(self.i18n.send(error_message))
            false
          end
        end

        # Checks if agent is enabled (that is, we are on OSX).
        #
        # @return [Boolean] `true` if the agent is enabled, `false` otherwise.
        def check_agent_available
          rv = true
          if !self.is_osx? then
            logger.fatal(self.i18n.no_agent)
            rv = false
          end

          rv
        end

        # Creates a OSX resolver.
        #
        # @param launch_agent [String] The agent path.
        # @param resolver_path [String] The resolver path.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def create_resolver(launch_agent, resolver_path)
          begin
            self.logger.info(self.i18n.resolver_creating(resolver_path))
            write_resolver(resolver_path)
            true
          rescue
            self.logger.error(self.i18n.resolver_creating_error)
            false
          end
        end

        # Writes a OSX resolver.
        #
        # @param resolver_path [String] The resolver path.
        def write_resolver(resolver_path)
          ::File.open(resolver_path, "w") {|f|
            f.write("nameserver 127.0.0.1\n")
            f.write("port #{@config.port}")
            f.flush
          }
        end

        # Deletes a OSX resolver.
        #
        # @param launch_agent [String] The agent path.
        # @param resolver_path [String] The resolver path.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def delete_resolver(launch_agent, resolver_path)
          delete_file(resolver_path, :resolver_deleting, :resolver_deleting_error)
        end

        # Creates a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param resolver_path [String] The resolver path.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def create_agent(launch_agent, resolver_path)
          begin
            self.logger.info(self.i18n.agent_creating(launch_agent))
            write_agent(launch_agent)
            self.execute_command("plutil -convert binary1 \"#{launch_agent}\"")
            true
          rescue
            self.logger.error(self.i18n.agent_creating_error)
            false
          end
        end


        # Writes a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        def write_agent(launch_agent)
          ::File.open(launch_agent, "w") {|f|
            f.write({"KeepAlive" => true, "Label" => "it.cowtech.devdnsd", "Program" => (::Pathname.new(Dir.pwd) + $0).to_s, "ProgramArguments" => ($ARGV ? $ARGV[0, $ARGV.length - 1] : []), "RunAtLoad" => true}.to_json)
            f.flush
          }
        end

        # Deletes a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param resolver_path [String] The resolver path.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def delete_agent(launch_agent, resolver_path)
          delete_file(launch_agent, :agent_deleting, :agent_deleting_error)
        end

        # Loads a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param resolver_path [String] The resolver path.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def load_agent(launch_agent, resolver_path)
          begin
            self.logger.info(self.i18n.agent_loading(launch_agent))
            self.execute_command("launchctl load -w \"#{launch_agent}\" > /dev/null 2>&1")
            true
          rescue
            self.logger.error(self.i18n.agent_loading_error)
            false
          end
        end

        # Unoads a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param resolver_path [String] The resolver path.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def unload_agent(launch_agent, resolver_path)
          begin
            self.logger.info(self.i18n.agent_unloading(launch_agent))
            self.execute_command("launchctl unload -w \"#{launch_agent}\" > /dev/null 2>&1")
            true
          rescue => e
            self.logger.warn(self.i18n.agent_unloading_error)
            false
          end
        end
    end

    # Methods to process requests.
    module Server
      # Starts the DNS server.
      #
      # @return [Object] The result of stop callbacks.
      def perform_server
        application = self
        RubyDNS::run_server(listen: [[:udp, @config.address, @config.port.to_integer]]) do
          self.logger = application.logger

          match(/.+/, DevDNSd::Application::ANY_CLASSES) do |match_data, transaction|
            transaction.append_question!
            application.config.rules.each { |rule| application.process_rule_in_classes(rule, match_data, transaction) } # During debugging, wrap the inside of the block with a begin rescue and PRINT the exception because RubyDNS hides it.
          end

          # Default DNS handler and event handlers
          otherwise { |transaction| transaction.failure!(:NXDomain) }
          self.on(:start) { application.on_start }
          self.on(:stop) { application.on_stop }
        end
      end

      # Processes a DNS rule.
      #
      # @param rule [Rule] The rule to process.
      # @param type [Symbol] The type of the query.
      # @param match_data [MatchData|nil] If the rule pattern was a Regexp, then this holds the match data, otherwise `nil` is passed.
      # @param transaction [RubyDNS::Transaction] The current DNS transaction (http://rubydoc.info/gems/rubydns/RubyDNS/Transaction).
      def process_rule(rule, type, match_data, transaction)
        reply, type = perform_process_rule(rule, type, match_data, transaction)
        self.logger.debug(reply ? self.i18n.reply(reply, type) : self.i18n.no_reply)

        if reply then
          transaction.respond!(*finalize_reply(reply, rule, type))
        elsif reply == false then
          false
        else
          nil
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
        resource_classes = resource_classes & [transaction.resource_class] if transaction.resource_class != DevDNSd::Application::ANY_REQUEST

        if resource_classes.present? then
          resource_classes.each do |resource_class| # Now for every class
            matches = rule.match_host(match_data[0])
            self.process_rule(rule, resource_class, rule.is_regexp? ? matches : nil, transaction) if matches
          end
        end
      end

      private
        # Performs the processing of a rule.
        #
        # @param rule [Rule] The rule to process.
        # @param type [Symbol] The type of query.
        # @param match_data [MatchData|nil] If the rule pattern was a Regexp, then this holds the match data, otherwise `nil` is passed.
        # @param transaction [RubyDNS::Transaction] The current DNS transaction (http://rubydoc.info/gems/rubydns/RubyDNS/Transaction).
        # @return [Array] The type and reply to the query.
        def perform_process_rule(rule, type, match_data, transaction)
          type = DevDNSd::Rule.resource_class_to_symbol(type)
          reply = !rule.block.nil? ? rule.block.call(match_data, type, transaction) : rule.reply
          reply = match_data[0].gsub(rule.match, reply.gsub("$", "\\")) if rule.match.is_a?(::Regexp) && reply && match_data[0]

          self.logger.debug(self.i18n.match(rule.match, type))
          [reply, type]
        end

        # Finalizes a query to return to the client.
        #
        # @param reply [String] The reply to send to the client.
        # @param rule [Rule] The rule to process.
        # @param type [Symbol] The type of query.
        def finalize_reply(reply, rule, type)
          rv = []
          rv << rule.options.delete(:preference).to_integer(10) if type == :MX
          rv << ([:A, :AAAA].include?(type) ? reply : Resolv::DNS::Name.create(reply))
          rv << rule.options.merge({resource_class: DevDNSd::Rule.symbol_to_resource_class(type, @locale)})
          rv
        end
    end
  end

  # The main DevDNSd application.
  #
  # @attribute [r] config
  #   @return [Configuration] The {Configuration Configuration} of this application.
  # @attribute [r] command
  #   @return [Mamertes::Command] The Mamertes command.
  # @attribute logger
  #   @return [Bovem::Logger] The logger for this application.
  # @attribute [r] locale
  #   @return [Symbol|nil] The current application locale.
  class Application < RExec::Daemon::Base
    # Class for ANY DNS request.
    ANY_REQUEST = Resolv::DNS::Resource::IN::ANY

    # List of classes handled in case of DNS request with resource class ANY.
    ANY_CLASSES = [Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA, Resolv::DNS::Resource::IN::ANY, Resolv::DNS::Resource::IN::CNAME, Resolv::DNS::Resource::IN::HINFO, Resolv::DNS::Resource::IN::MINFO, Resolv::DNS::Resource::IN::MX, Resolv::DNS::Resource::IN::NS, Resolv::DNS::Resource::IN::PTR, Resolv::DNS::Resource::IN::SOA, Resolv::DNS::Resource::IN::TXT]

    include Lazier::I18n
    include DevDNSd::ApplicationMethods::System
    include DevDNSd::ApplicationMethods::Server

    attr_reader :config
    attr_reader :command
    attr_accessor :logger
    attr_reader :locale

    # Creates a new application.
    #
    # @param command [Mamertes::Command] The current Mamertes command.
    # @param locale [Symbol] The locale to use for the application.
    def initialize(command, locale)
      self.i18n_setup(:devdnsd, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"))
      self.i18n = locale

      @locale = locale
      @command = command
      options = @command.application.get_options.reject {|k,v| v.nil? }

      # Setup logger
      Bovem::Logger.start_time = Time.now
      @logger = Bovem::Logger.create(Bovem::Logger.get_real_file(options["log_file"]) || Bovem::Logger.default_file, Logger::INFO)

      # Open configuration
      read_configuration(options)

      self
    end

    # Gets the current logger of the application.
    #
    # @return [Logger] The current logger of the application.
    def get_logger
      @logger ||= Bovem::Logger.create(@config.foreground ? Bovem::Logger.default_file : @config.log_file, @config.log_level, @log_formatter)
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
    # @param command [Mamertes::Command] The current Mamertes command.
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
      self.instance.perform_server
    end

    # Stops the application.
    def self.quit
      ::EventMachine.stop rescue nil
    end

    # Check if the current implementation supports DevDNSd.
    def self.check_ruby_implementation
      if defined?(Rubinius) || defined?(JRuby) then
        Kernel.puts(Lazier::Localizer.new(:devdnsd, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/")).i18n.no_jruby_rubinius)
        Kernel.exit(0)
      end
    end

    private
      # Reads configuration.
      #
      # @param options [Hash] The configuration to read.
      def read_configuration(options)
        begin
          @config = DevDNSd::Configuration.new(options["configuration"], options, @logger)
          @logger = nil
          @logger = self.get_logger
        rescue Bovem::Errors::InvalidConfiguration => e
          @logger ? @logger.fatal(e.message) : Bovem::Logger.create("STDERR").fatal(self.i18n.logging_failed(log_file))
          raise ::SystemExit
        end
      end
  end
end
