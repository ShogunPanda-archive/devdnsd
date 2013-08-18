# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module DevDNSd
  # Exceptions for {DevDNSd DevDNSd}.
  module Errors
    # This exception is raised if a {Rule Rule} is invalid.
    class InvalidRule < ::ArgumentError
    end
  end
end