#
# This file is part of the devdns gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module DevDnsd
  class Rule
    attr_accessor :match, :type, :reply, :block

    def initialize
      @match = /.+/
      @type = :A
      @reply = "127.0.0.1"
      @block = nil
    end

    def self.create(*args, &block)
      rv = self.new

      abort("You must specify at least a rule and a host. Optionally you can add a record type. (default: A)") if ![2,3].include?(args.length)

      rv.match = args[0]

      if !block.nil? then
        # The third argument is ignored
        rv.type = args[1].to_sym
        rv.block = block
      else
        rv.reply = args[1]
        rv.type = args[2].to_sym if args.length == 3
      end

      rv
    end
  end
end