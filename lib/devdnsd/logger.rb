# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module DevDNSd
  # A custom logger for DevDNSd.
  class Logger < ::Logger
    # The start time of first line. This allows to show a `T+0.1234` information into the log.
    mattr_accessor :start_time

    # The file or device to log messages to.
    attr_reader :device

    # Creates a new logger
    # @see http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html
    #
    # @param logdev [String|IO] The log device. This is a filename (String) or IO object (typically STDOUT, STDERR, or an open file).
    # @param shift_age [Fixnum]  Number of old log files to keep, or frequency of rotation (daily, weekly or monthly).
    # @param shift_size [Fixnum] Maximum logfile size (only applies when shift_age is a number).
    def initialize(logdev, shift_age = 0, shift_size = 1048576)
      @device = logdev
      super(logdev, shift_age, shift_size)
    end

    # Creates a new logger
    #
    # @param file [String|IO] The log device. This is a filename (String) or IO object (typically STDOUT, STDERR, or an open file).
    # @param level [Fixnum] The minimum severity to log. See http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html for valid levels.
    # @param formatter [Proc] The formatter to use for logging.
    # @return [Logger] The new logger.
    def self.create(file = nil, level = Logger::INFO, formatter = nil)
      file ||= self.default_file

      begin
        rv = self.new(self.get_real_file(file))
      rescue
        raise DevDNSd::Errors::InvalidConfiguration
      end

      rv.level = level.to_i
      rv.formatter = formatter || self.default_formatter
      rv
    end

    # Translates a file to standard input or standard ouput in some special cases.
    #
    # @param file [String] The string to translate.
    # @return [String|IO] The translated file name.
    def self.get_real_file(file)
      case file
        when "STDOUT" then $stdout
        when "STDERR" then $stderr
        else file
      end
    end

    # The default file for logging.
    # @return [String|IO] The default file for logging.
    def self.default_file
      @default_file ||= $stdout
    end

    # The default formatter for logging.
    # @return [Proc] The default formatter for logging.
    def self.default_formatter
      @default_formatter ||= ::Proc.new {|severity, datetime, progname, msg|
        color = case severity
          when "DEBUG" then :cyan
          when "INFO" then :green
          when "WARN" then :yellow
          when "ERROR" then :red
          when "FATAL" then :magenta
          else :white
        end

        header = ("[%s T+%0.5f] %s:" %[datetime.strftime("%Y/%b/%d %H:%M:%S"), [datetime.to_f - self.start_time.to_f, 0].max, severity.rjust(5)]).bright
        header = header.color(color) if color.present?
        "%s %s\n" % [header, msg]
      }
    end

    # The log time of the first logger. This allows to show a `T+0.1234` information into the log.
    # @return [Time] The log time of the first logger.
    def self.start_time
      @start_time ||= ::Time.now
    end
  end
end