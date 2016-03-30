# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A small DNS server to enable local .dev domain resolution.
module DevDNSd
  # Methods to handle interfaces aliases.
  module Aliases
    extend ActiveSupport::Concern

    # Manages aliases.
    #
    # @param operation [Symbol] The type of operation. Can be `:add` or `:remove`.
    # @param message [String] The message to show if no addresses are found.
    # @param options [Hash] The options provided by the user.
    # @return [Boolean] `true` if operation succeeded, `false` otherwise.
    def manage_aliases(operation, message, options)
      config = self.config
      options.each { |k, v| config.send("#{k}=", v) if config.respond_to?("#{k}=") }

      addresses = compute_addresses

      if addresses.present?
        # Now, for every address, call the command
        addresses.all? { |address| manage_address(operation, address, options[:dry_run]) }
      else
        @logger.error(message)
        false
      end
    end

    # Adds or removes an alias from the interface.
    #
    # @param type [Symbol] The operation to execute. Can be `:add` or `:remove`.
    # @param address [String] The address to manage.
    # @param dry_run [Boolean] If only show which modifications will be done.
    # @return [Boolean] `true` if operation succeeded, `false` otherwise.
    def manage_address(type, address, dry_run = false)
      rv, command, prefix = setup_management(type, address)

      # Now execute
      if rv
        if !dry_run
          execute_manage(command, prefix, type, address, config)
        else
          log_management(:dry_run, prefix, type, i18n.remove, i18n.add, address, config)
        end
      end

      rv
    end

    # Computes the list of address to manage.
    #
    # @param type [Symbol] The type of addresses to consider. Valid values are `:ipv4`, `:ipv6`, otherwise all addresses are considered.
    # @return [Array] The list of addresses to add or remove from the interface.
    def compute_addresses(type = :all)
      config = self.config
      config.addresses.present? ? filter_addresses(config, type) : generate_addresses(config, type)
    end

    # Checks if an address is a valid IPv4 address.
    #
    # @param address [String] The address to check.
    # @return [Boolean] `true` if the address is a valid IPv4 address, `false` otherwise.
    def ipv4?(address)
      address = address.ensure_string

      mo = /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\Z/.match(address)
      (mo && mo.captures.all? { |i| i.to_i < 256 }) ? true : false
    end
    alias_method :is_ipv4?, :ipv4?

    # Checks if an address is a valid IPv6 address.
    #
    # @param address [String] The address to check.
    # @return [Boolean] `true` if the address is a valid IPv6 address, `false` otherwise.
    def ipv6?(address)
      address = address.ensure_string

      catch(:valid) do
        # IPv6 (normal)
        check_normal_ipv6(address)
        # IPv6 (IPv4 compat)
        check_compat_ipv6(address)

        false
      end
    end

    private

    # :nodoc:
    def setup_management(type, address)
      @addresses ||= compute_addresses
      length = @addresses.length
      length_s = length.to_s.length
      progress = ((@addresses.index(address) || 0) + 1).indexize(length: length_s)
      message = "{mark=blue}[{mark=bright white}#{progress}{mark=reset blue}/{/mark}#{length}{/mark}]{/mark}"

      [true, build_command(type, address), message]
    rescue ArgumentError
      [false]
    end

    # :nodoc:
    def filter_addresses(config, type)
      filters = [:ipv4, :ipv6].select { |i| type == i || type == :all }.compact
      config.addresses.select { |address| filters.any? { |filter| send("#{filter}?", address) } }.compact.uniq
    end

    # :nodoc:
    def generate_addresses(config, type)
      ip = IPAddr.new(config.start_address.ensure_string)
      raise ArgumentError if type != :all && !ip.send("#{type}?")
      Array.new([config.aliases, 1].max) do |_|
        current = ip
        ip = ip.succ
        current
      end
    rescue ArgumentError
      []
    end

    # :nodoc:
    def build_command(type, address)
      template = config.send((type == :remove) ? :remove_command : :add_command)
      Mustache.render(template, {interface: config.interface, address: address.to_s}) + " > /dev/null 2>&1"
    end

    # :nodoc:
    def execute_manage(command, prefix, type, address, config)
      rv = execute_command(command)
      log_management(:run, prefix, type, i18n.removing, i18n.adding, address, config)
      log_management_error(config, address, manage_labels(type)) unless rv
      rv
    end

    # :nodoc:
    def manage_labels(type)
      type == :remove ? [i18n.remove, i18n.from] : [i18n.add, i18n.to]
    end

    # :nodoc:
    def log_management_error(config, address, labels)
      @logger.error(replace_markers(i18n.general_error(labels[0], address, labels[1], config.interface)))
    end

    # :nodoc:
    def log_management(message, prefix, type, remove_label, add_label, address, config)
      labels = (type == :remove ? [remove_label, i18n.from] : [add_label, i18n.to])
      @logger.info(replace_markers(i18n.send(message, prefix, labels[0], address, labels[1], config.interface)))
    end

    # :nodoc:
    def check_compat_ipv6(address)
      throw(:valid, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:/ =~ address && ipv4?($')
      throw(:valid, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:)?/ =~ address && ipv4?($')
      throw(:valid, true) if /\A::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:)?/ =~ address && ipv4?($')
    end

    # :nodoc:
    def check_normal_ipv6(address)
      throw(:valid, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*\Z/ =~ address
      throw(:valid, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*)?\Z/ =~ address
      throw(:valid, true) if /\A::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*)?\Z/ =~ address
    end
  end
end
