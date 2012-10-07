# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A small DNS server to enable local .dev domain resolution.
module DevDNSd
  # The main DevDNSd application.
  class Application < RExec::Daemon::Base
    # Class for ANY DNS request.
    ANY_REQUEST = Resolv::DNS::Resource::IN::ANY

    # List of classes handled in case of DNS request with resource class ANY.
    ANY_CLASSES = [Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA, Resolv::DNS::Resource::IN::ANY, Resolv::DNS::Resource::IN::CNAME, Resolv::DNS::Resource::IN::HINFO, Resolv::DNS::Resource::IN::MINFO, Resolv::DNS::Resource::IN::MX, Resolv::DNS::Resource::IN::NS, Resolv::DNS::Resource::IN::PTR, Resolv::DNS::Resource::IN::SOA, Resolv::DNS::Resource::IN::TXT]

    # The {Configuration Configuration} of this application.
    attr_reader :config

    # The Mamertes command.
    attr_reader :command

    # The logger for this application.
    attr_accessor :logger

    # Creates a new application.
    #
    # @param command [Mamertes::Command] The current Mamertes command.
    def initialize(command)
      @command = command
      application = @command.application

      # Setup logger
      Bovem::Logger.start_time = Time.now
      @logger = Bovem::Logger.create(Bovem::Logger.get_real_file(application.options["log-file"].value) || Bovem::Logger.default_file, Logger::INFO)

      # Open configuration
      begin
        overrides = {
          :foreground => command.name == "start" ? command.options["foreground"].value : false,
          :tld => application.options["tld"].value,
          :port => application.options["port"].value,
          :pid_file => application.options["pid-file"].value,
          :log_file => application.options["log-file"].value,
          :log_level => application.options["log-level"].value
        }.reject {|k,v| v.nil? }

        @config = DevDNSd::Configuration.new(application.options["configuration"].value, overrides, @logger)

        @logger = nil
        @logger = self.get_logger
      rescue Bovem::Errors::InvalidConfiguration, DevDNSd::Errors::InvalidRule => e
        @logger ? @logger.fatal(e.message) : Bovem::Logger.create("STDERR").fatal("Cannot log to #{config.log_file}. Exiting...")
        raise ::SystemExit
      end

      self
    end

    # Returns the name of the daemon.
    #
    # @return [String] The name of the daemon.
    def self.daemon_name
      File.basename(self.instance.config.pid_file, ".pid")
    end

    # Returns the standard location of the PID file.
    #
    # @return [String] The standard location of the PID file.
    def self.pid_directory
      File.dirname(self.instance.config.pid_file)
    end

    # Returns the complete path of the PID file.
    #
    # @return [String] The complete path of the PID file.
    def self.pid_fn
      self.instance.config.pid_file
    end

    # Check if we are running on MacOS X.
    # System services are only available on that platform.
    #
    # @return [Boolean] `true` if the current platform is MacOS X, `false` otherwise.
    def is_osx?
      ::Config::CONFIG['host_os'] =~ /^darwin/
    end

    # Gets the current logger of the application.
    #
    # @return [Logger] The current logger of the application.
    def get_logger
      @logger ||= Bovem::Logger.create(@config.foreground ? Bovem::Logger.default_file : @config.log_file, @config.log_level, @log_formatter)
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
      @logger.info("Flushing DNS cache and resolvers ...")
      self.execute_command("dscacheutil -flushcache")
    end

    # Starts the DNS server.
    #
    # @return [Object] The result of stop callbacks.
    def perform_server
      RubyDNS::run_server(:listen => [[:udp, @config.address, @config.port.to_integer]]) do
        self.logger = DevDNSd::Application.instance.logger

        match(/.+/, DevDNSd::Application::ANY_CLASSES) do |match_data, transaction|
          transaction.append_question!

          DevDNSd::Application.instance.config.rules.each do |rule|
            begin
              # Get the subset of handled class that is valid for the rule
              resource_classes = DevDNSd::Application::ANY_CLASSES & rule.resource_class.ensure_array
              resource_classes = resource_classes & [transaction.resource_class] if transaction.resource_class != DevDNSd::Application::ANY_REQUEST

              if resource_classes.present? then
                resource_classes.each do |resource_class| # Now for every class
                  matches = rule.match_host(match_data[0])
                  DevDNSd::Application.instance.process_rule(rule, resource_class, rule.is_regexp? ? matches : nil, transaction) if matches
                end
              end
            rescue ::Exception => e
              raise e
            end
          end
        end

        # Default DNS handler
        otherwise do |transaction|
          transaction.failure!(:NXDomain)
        end

        # Attach event handlers
        self.on(:start) do
          DevDNSd::Application.instance.on_start
        end

        self.on(:stop) do
          DevDNSd::Application.instance.on_stop
        end
      end
    end

    # Processes a DNS rule.
    #
    # @param rule [Rule] The rule to process.
    # @param type [Class] The type of request.
    # @param match_data [MatchData|nil] If the rule pattern was a Regexp, then this holds the match data, otherwise `nil` is passed.
    # @param transaction [Transaction] The current DNS transaction (http://rubydoc.info/gems/rubydns/RubyDNS/Transaction).
    # @return A reply for the request if matched, otherwise `false` or `nil`.
    def process_rule(rule, type, match_data, transaction)
      is_regex = rule.match.is_a?(::Regexp)
      type = DevDNSd::Rule.resource_class_to_symbol(type)

      DevDNSd::Application.instance.logger.debug("Found match on #{rule.match} with type #{type}.")

      if !rule.block.nil? then
        reply = rule.block.call(match_data, type, transaction)
      else
        reply = rule.reply
      end

      if is_regex && reply && match_data[0] then
        reply = match_data[0].gsub(rule.match, reply.gsub("$", "\\"))
      end

      DevDNSd::Application.instance.logger.debug(reply ? "Reply is #{reply} with type #{type}." : "No reply found.")

      if reply then
        options = rule.options

        final_reply = []

        case type
          when :MX
            preference = options.delete(:preference)
            preference = preference.nil? ? 10 : preference.to_integer(10)
            final_reply << preference
        end

        if [:A, :AAAA].include?(type) then
          final_reply << reply
        else
          final_reply << Resolv::DNS::Name.create(reply)
        end

        final_reply << options.merge({:resource_class => DevDNSd::Rule.symbol_to_resource_class(type)})
        transaction.respond!(*final_reply)
      elsif reply == false then
        false
      else
        reply
      end
    end

    # Starts the server in background.
    #
    # @return [Boolean] `true` if action succedeed, `false` otherwise.
    def action_start
      logger = self.get_logger

      logger.info("Starting DevDNSd ...")

      if @config.foreground then
        self.perform_server
      else
        RExec::Daemon::Controller.start(self.class)
      end

      true
    end

    # Stops the server in background.
    #
    # @return [Boolean] `true` if action succedeed, `false` otherwise.
    def action_stop
      RExec::Daemon::Controller.stop(self.class)

      true
    end

    # Installs the server into the system.
    #
    # @return [Boolean] `true` if action succedeed, `false` otherwise.
    def action_install
      logger = get_logger

      if !self.is_osx? then
        logger.fatal("Install DevDNSd as a local resolver is only available on MacOSX.")
        return false
      end

      resolver_file = self.resolver_path
      launch_agent = self.launch_agent_path

      # Installs the resolver
      begin
        logger.info("Installing the resolver in #{resolver_file} ...")

        open(resolver_file, "w") {|f|
          f.write("nameserver 127.0.0.1\n")
          f.write("port #{@config.port}")
          f.flush
        }
      rescue => e
        logger.error("Cannot create the resolver file.")
        return false
      end

      begin
        logger.info("Creating the launch agent in #{launch_agent} ...")

        args = $ARGV ? $ARGV[0, $ARGV.length - 1] : []

        plist = {"KeepAlive" => true, "Label" => "it.cowtech.devdnsd", "Program" => (::Pathname.new(Dir.pwd) + $0).to_s, "ProgramArguments" => args, "RunAtLoad" => true}
        ::File.open(launch_agent, "w") {|f|
          f.write(plist.to_json)
          f.flush
        }
        self.execute_command("plutil -convert binary1 \"#{launch_agent}\"")
      rescue => e
        logger.error("Cannot create the launch agent.")
        return false
      end

      begin
        logger.info("Loading the launch agent ...")
        self.execute_command("launchctl load -w \"#{launch_agent}\" > /dev/null 2>&1")
      rescue => e
        logger.error("Cannot load the launch agent.")
        return false
      end

      self.dns_update

      true
    end

    # Uninstalls the server from the system.
    #
    # @return [Boolean] `true` if action succedeed, `false` otherwise.
    def action_uninstall
      logger = self.get_logger

      if !self.is_osx? then
        logger.fatal("Install DevDNSd as a local resolver is only available on MacOSX.")
        return false
      end

      resolver_file = self.resolver_path
      launch_agent = self.launch_agent_path

      # Remove the resolver
      begin
        logger.info("Deleting the resolver #{resolver_file} ...")
        ::File.delete(resolver_file)
      rescue => e
        logger.warn("Cannot delete the resolver file.")
        return false
      end

      # Unload the launch agent.
      begin
        self.execute_command("launchctl unload -w \"#{launch_agent}\" > /dev/null 2>&1")
      rescue => e
        logger.warn("Cannot unload the launch agent.")
      end

      # Delete the launch agent.
      begin
        logger.info("Deleting the launch agent #{launch_agent} ...")
        ::File.delete(launch_agent)
      rescue => e
        logger.warn("Cannot delete the launch agent.")
        return false
      end

      self.dns_update

      true
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
    # @param force [Boolean] If to force recreation of the instance.
    # @return [Application] The unique (singleton) instance of the application.
    def self.instance(command = nil, force = false)
      @instance = nil if force
      @instance ||= DevDNSd::Application.new(command) if command
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
      ::EventMachine.stop
    end
  end
end
