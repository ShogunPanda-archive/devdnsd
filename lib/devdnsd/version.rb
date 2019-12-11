# encoding: utf-8
#
# This file is part of the devdnsd gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

module DevDNSd
  # The current version of DevDNSd, according to semantic versioning.
  #
  # @see http://semver.org
  module Version
    # The major version.
    MAJOR = 4

    # The minor version.
    MINOR = 0

    # The patch version.
    PATCH = 1

    # The current version number of DevDNSd.
    STRING = [MAJOR, MINOR, PATCH].compact.join(".")
  end
end
