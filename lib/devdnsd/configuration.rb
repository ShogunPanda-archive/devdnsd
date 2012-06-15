#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module DevDnsd
  class Configuration
    attr_accessor :foreground, :address, :port, :tld, :log_file, :log_level, :rules

    def initialize(file, application, overrides = {})
      @address = "0.0.0.0"
      @port = 7771
      @tld = "dev"
      @log_file = "/var/log/devdnsd.log"
      @log_level = Logger::INFO
      @rules = []
      @foreground = false

      begin
        # Open the file
        path = Pathname.new(file).realpath
        application.logger.info("Using configuration file #{path}.")
        self.tap do |config|
          eval(File.read(path))
        end

        @log_file = $stdout if @log_file == "STDOUT"
        @log_file = $stderr if @log_file == "STDERR"
      rescue Errno::ENOENT, LoadError
      rescue Exception
        abort("Config file #{file} is not valid.")
      end

      # Apply overrides
      if overrides.is_a?(Hash) then
        overrides.each_pair do |k, v|
          self.send("#{k}=", v) if self.respond_to?("#{k}=") && !v.nil?
        end
      end

      # Add a default rule
      self.add_rule(/.+/, "127.0.0.1") if @rules.length == 0
    end

    def add_rule(*args, &block)
      @rules << DevDnsd::Rule.create(*args, &block)
    end
  end
end