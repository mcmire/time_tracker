# Note that this file doesn't require any of the gems tt needs.
# Look in bin/tt or spec/spec_helper for that.

require 'tt/mongo_mapper'
require 'tt/extensions/ruby'
require 'tt/extensions/term_ansicolor'
require 'tt/columnator'

require 'tt/cli_methods'
require 'tt/cli'
require 'tt/config'
require 'tt/project'
require 'tt/task'
require 'tt/time_period'

module TimeTracker
  class << self
    attr_accessor :current_project
    
    def config
      # TODO: Maybe this should not be stored in the db, but just in memory or in /tmp
      @config || reload_config
    end
    
    def reload_config
      @config = TimeTracker::Config.find()
    end
  end
end