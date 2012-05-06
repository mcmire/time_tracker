
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/date/conversions'
require 'active_support/core_ext/date/zones'
require 'active_support/core_ext/time/calculations'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/time/zones'

# TODO: Make this configurable
Time.zone = "Central Time (US & Canada)"

require 'tt/extensions/ruby'
require 'tt/extensions/date_time_formats'
