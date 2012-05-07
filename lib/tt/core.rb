
require 'andand'

require 'tt/core/core'
require 'tt/core/config'
require 'tt/core/logging'
require 'tt/core/time'

module TimeTracker
  Core.hook_into(self)
end
