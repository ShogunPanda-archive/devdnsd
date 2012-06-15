#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# TODO: Fix offline behavior

module DevDnsd
  class Application < RExec::Daemon::Base
    def self.instance(globals = {}, locals = {}, args = [])
      @@instance ||= Application.new(globals, locals, args)
    end

    attr_reader :config, :args, :logger

    def initialize(globals, locals, args)
      @args = {
          :global => globals,
          :local => locals,
          :args => args
      }

      # Setup logger
      @log_start = Time.now.to_f
      @log_formatter = Proc.new {|severity, datetime, progname, msg|
        log = "[%s.%s] %s: %s\n" % [datetime.strftime("%Y-%m-%d %H:%M:%S"), datetime.usec, severity, msg]
      }
      @logger = self.create_logger($stdout, Logger::INFO, @log_formatter)
      @logger.info("Starting DevDNSd ...")

      # Open configuration
      @config = DevDnsd::Configuration.new(@args[:global][:config], self, {:foreground => @args[:local][:foreground], :log_file => @args[:global][:log_file], :log_level => @args[:global][:log_level], :tld => @args[:global][:tld]})

      self
    end

    def self.run
      self.instance.perform_server
    end

    def create_logger(file = $stdout, level = Logger::INFO, formatter = nil)
      rv = Logger.new(file)
      rv.level = level.to_i
      rv.formatter = formatter if !formatter.nil?
      rv
    end

    def perform_server
      server = RubyDNS::run_server(:listen => [[:udp, @config.address, @config.port]]) do
        @logger = Application.instance.logger

        Application.instance.config.rules.each do |rule|
          match(rule.match, rule.type) do |match_data, transaction|
            begin
              @logger.debug("Found match on #{rule.match} with type #{rule.type}")
              reply = rule.block.nil? ? rule.reply : rule.block.call(match_data, transaction)
              @logger.debug(reply ? "Reply is #{reply}." : "No reply found.")
              transaction.respond!(reply) if reply
            rescue Exception => e
            end
          end
        end

        # Default DNS handler
        otherwise do |transaction|
          transaction.passthrough!(Resolv::DNS.new)
        end
      end
    end

    def dns_update
      @logger.info("Flushing DNS cache and resolvers ...")
      system("dscacheutil -flushcache")
    end

    def action_start
      @logger = self.create_logger(@config.foreground ? $stdout : @config.log_file, @config.log_level, @log_formatter)

      if @config.foreground then
        self.perform_server
      else
        RExec::Daemon::Controller.start(DevDnsd::Application)
      end
    end

    def action_stop
      RExec::Daemon::Controller.stop(DevDnsd::Application)
    end

    def action_install
      @logger = self.create_logger($stdout, @config.log_level, @log_formatter)

      resolver_file = "/etc/resolver/#{@config.tld}"
      launch_agent = ENV["HOME"] + "/Library/LaunchAgents/it.cowtech.devdnsd.plist"

      # Install the resolver
      begin
        @logger.info("Installing the resolver in #{resolver_file} ...")

        open(resolver_file, "w") {|f|
          f.write("nameserver 127.0.0.1\n")
          f.write("port #{@config.port}")
        }
      rescue => e
        @logger.error("Cannot create the resolver file.")
        return
      end

      begin
        @logger.info("Creating the launch agent in #{launch_agent} ...")

        args = $ARGV[0, $ARGV.length - 1]

        plist = {"KeepAlive" => true, "Label" => "it.cowtech.devdnsd", "Program" => (Pathname.new(Dir.pwd) + $0).to_s, "ProgramArguments" => args, "RunAtLoad" => true}
        plist.save_plist(launch_agent)
      rescue => e
        @logger.error("Cannot create the launch agent.")
        return
      end

      begin
        @logger.info("Loading the launch agent ...")
        system("launchctl load -w \"#{launch_agent}\"")
      rescue => e
        @logger.error("Cannot load the agent.")
        return
      end

      self.dns_update
    end

    def action_uninstall
      @logger = self.create_logger($stdout, @config.log_level, @log_formatter)

      resolver_file = "/etc/resolver/#{@config.tld}"
      launch_agent = ENV["HOME"] + "/Library/LaunchAgents/it.cowtech.devdnsd.plist"

      # Remove the resolver
      begin
        @logger.info("Deleting the resolver #{resolver_file} ...")
        File.delete(resolver_file)
      rescue => e
        @logger.error("Cannot delete the resolver file.")
        return
      end

      # Unload the launch agent.
      begin
        system("launchctl unload -w \"#{launch_agent}\"")
      rescue => e
        @logger.error("Cannot unload the launch agent.")
        return
      end

      begin
        @logger.info("Deleting the launch agent #{launch_agent} ...")
        File.delete(launch_agent)
      rescue => e
        @logger.error("Cannot delete the launch agent.")
        return
      end

      self.dns_update
    end
  end
end