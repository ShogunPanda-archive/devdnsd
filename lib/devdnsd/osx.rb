# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A small DNS server to enable local .dev domain resolution.
module DevDNSd
  # OSX management methods.
  module OSX
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
      system("#{command} 2>&1 > /dev/null")
    end

    # Updates DNS cache.
    #
    # @return [Boolean] `true` if command succeeded, `false` otherwise.
    def dns_update
      @logger.info(i18n.dns_update)

      script = Tempfile.new("devdnsd-dns-cache-script")
      script.write("dscacheutil -flushcache 2>&1 > /dev/null\n")
      script.write("killall -9 mDNSResponder 2>&1 > /dev/null\n")
      script.write("killall -9 mDNSResponderHelper 2>&1 > /dev/null\n")
      script.close

      Kernel.system("/usr/bin/osascript -e 'do shell script \"sh #{script.path}\" with administrator privileges' 2>&1 > /dev/null")
      script.unlink
    end

    # Checks if we are running on MacOS X.
    #
    # System services are only available on that platform.
    #
    # @return [Boolean] `true` if the current platform is MacOS X, `false` otherwise.
    def osx?
      ::RbConfig::CONFIG['host_os'] =~ /^darwin/
    end
    alias_method :is_osx?, :osx?

    # Adds aliases to an interface.
    #
    # @param options [Hash] The options provided by the user.
    # @return [Boolean] `true` if action succeeded, `false` otherwise.
    def action_add(options)
      manage_aliases(:add, i18n.add_empty, options)
    end

    # Removes aliases from an interface.
    #
    # @param options [Hash] The options provided by the user.
    # @return [Boolean] `true` if action succeeded, `false` otherwise.
    def action_remove(options)
      manage_aliases(:remove, i18n.remove_empty, options)
    end

    # Installs the application into the autolaunch.
    #
    # @return [Boolean] `true` if action succeeded, `false` otherwise.
    def action_install
      manage_installation(launch_agent_path, resolver_path, :create_resolver, :create_agent, :load_agent)
    end

    # Uninstalls the application from the autolaunch.
    #
    # @return [Boolean] `true` if action succeeded, `false` otherwise.
    def action_uninstall
      manage_installation(launch_agent_path, resolver_path, :delete_resolver, :unload_agent, :delete_agent)
    end

    private

    # :nodoc:
    def log_status(pid, status)
      logger.info(status == :running ? replace_markers(i18n.status_running(pid)) : replace_markers(i18n.send("status_#{status}")))
    end

    # :nodoc:
    def manage_installation(launch_agent, resolver_path, first_operation, second_operation, third_operation)
      rv = check_agent_available

      logger.warn(replace_markers(i18n.admin_privileges_warning))
      rv = send(first_operation, launch_agent, resolver_path) if rv
      rv = send(second_operation, launch_agent, resolver_path) if rv
      rv = send(third_operation, launch_agent, resolver_path) if rv
      dns_update
      rv
    end

    # :nodoc:
    def delete_file(file, before_message, error_message)
      logger.info(i18n.send(before_message, file))
      ::File.delete(file)
      true
    rescue
      logger.warn(i18n.send(error_message))
      false
    end

    # :nodoc:
    def check_agent_available
      rv = true
      unless osx?
        logger.fatal(i18n.no_agent)
        rv = false
      end

      rv
    end

    # :nodoc:
    def create_resolver(_, resolver_path)
      logger.info(replace_markers(i18n.resolver_creating(resolver_path)))

      script_file = create_resolver_script(resolver_path)
      Kernel.system("/usr/bin/osascript -e 'do shell script \"sh #{script_file.path}\" with administrator privileges' 2>&1 > /dev/null")
      script_file.unlink
      true
    rescue
      logger.error(i18n.resolver_creating_error)
      false
    end

    # :nodoc:
    def create_resolver_script(resolver_path)
      script = "mkdir -p '#{File.dirname(resolver_path)}'\nrm -rf '#{resolver_path}'\necho 'nameserver 127.0.0.1\\nport #{@config.port}' >> '#{resolver_path}'"
      f = Tempfile.new("devdnsd-install-script")
      f.write(script)
      f.close
      f
    end

    # :nodoc:
    def delete_resolver(_, resolver_path)
      logger.info(i18n.resolver_deleting(resolver_path))
      Kernel.system("/usr/bin/osascript -e 'do shell script \"rm #{resolver_path}\" with administrator privileges' 2>&1 > /dev/null")
      true
    rescue
      logger.warn(i18n.resolver_deleting_error)
      false
    end

    # :nodoc:
    def create_agent(launch_agent, _)
      logger.info(replace_markers(i18n.agent_creating(launch_agent)))
      program, args = prepare_agent

      ::File.open(launch_agent, "w") do |f|
        f.write({"KeepAlive" => true, "Label" => "it.cowtech.devdnsd", "Program" => program, "ProgramArguments" => args, "RunAtLoad" => true}.to_plist)
        f.flush
      end

      true
    rescue
      logger.error(i18n.agent_creating_error)
      false
    end

    # :nodoc:
    def prepare_agent
      [
        (::Pathname.new(Dir.pwd) + $PROGRAM_NAME).to_s,
        (ARGV ? ARGV[0, ARGV.length - 1] : [])
      ]
    end

    # :nodoc:
    def delete_agent(launch_agent, _)
      delete_file(launch_agent, :agent_deleting, :agent_deleting_error)
    end

    # :nodoc:
    def load_agent(launch_agent, _)
      toggle_agent(launch_agent, "load", :agent_loading, :agent_loading_error, :error)
    end

    # :nodoc:
    def unload_agent(launch_agent, _)
      toggle_agent(launch_agent, "unload", :agent_unloading, :agent_unloading_error, :warn)
    end

    # :nodoc:
    def toggle_agent(launch_agent, operation, info_message, error_message, error_level)
      logger.info(i18n.send(info_message, launch_agent))
      raise RuntimeError unless File.exist?(launch_agent)
      execute_command("launchctl #{operation} -w \"#{launch_agent}\" > /dev/null 2>&1")
      true
    rescue
      logger.send(error_level, i18n.send(error_message))
      false
    end

    # :nodoc:
    def replace_markers(message)
      @command.application.console.replace_markers(message)
    end
  end
end
