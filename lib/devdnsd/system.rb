# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

# A small DNS server to enable local .dev domain resolution.
module DevDNSd
  # System management methods.
  module System
    extend ActiveSupport::Concern

    # Returns the name of the daemon.
    #
    # @return [String] The name of the daemon.
    def daemon_name
      config ? File.basename(config.pid_file, ".pid") : "devdnsd"
    end

    alias_method :name, :daemon_name

    # Returns the standard location of the PID file.
    #
    # @return [String] The standard location of the PID file.
    def working_directory
      config ? File.dirname(config.pid_file) : Dir.pwd
    end
    alias_method :runtime_directory, :working_directory

    # Returns the complete path of the PID file.
    #
    # @return [String] The complete path of the PID file.
    def process_file_path
      config ? config.pid_file : Dir.pwd + "devdnsd.pid"
    end

    # Returns the complete path of the log file.
    #
    # @return [String] The complete path of the log file.
    def log_file_path
      config.log_file
    end

    # Returns the standard location of the log file.
    #
    # @return [String] The standard location of the log file.
    def log_directory
      File.dirname(config.log_file)
    end

    # Starts the server in background.
    #
    # @return [Boolean] `true` if action succeeded, `false` otherwise.
    def action_start
      logger.info(i18n.starting)

      prepare_start

      @config.foreground ? perform_server : self.class.start
      true
    end

    # Stops the server in background.
    #
    # @return [Boolean] `true` if action succeeded, `false` otherwise.
    def action_stop
      self.class.stop
      true
    end

    # Restarts the server in background.
    #
    # @return [Boolean] `true` if action succeeded, `false` otherwise.
    def action_restart
      action_stop
      action_start
      true
    end

    # Shows the status of the server
    #
    # @return [Boolean] `true` if action succeeded, `false` otherwise.
    def action_status
      status = self.class.status
      status = :crashed if status == :unknown && self.class.crashed?

      log_status(self.class.controller.pid, status)
    end

    private

    # :nodoc:
    def prepare_start
      if !Process.respond_to?(:fork)
        logger.warn(i18n.no_fork)
        @config.foreground = true
      elsif @command.options[:foreground].value
        @config.foreground = true
      end
    end
  end
end
