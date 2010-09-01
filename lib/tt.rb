# Note that this file doesn't require any of the gems tt needs.
# Look in bin/tt or spec/spec_helper for that.

require 'tt/mongo_mapper'
require 'tt/extensions/ruby'
require 'tt/extensions/term_ansicolor'
require 'tt/columnator'

require 'tt/commander'
require 'tt/cli/repl'
require 'tt/cli'
require 'tt/config'
require 'tt/project'
require 'tt/task'
require 'tt/time_period'

require 'tt/service'
require 'tt/service/pivotal_tracker'

module TimeTracker
  class << self
    attr_writer :current_project, :external_service
    
    def config
      # TODO: Maybe this should not be stored in the db, but just in memory or in /tmp
      @config || reload_config
    end
    
    # TODO: config.reload
    def reload_config
      @config = TimeTracker::Config.find()
    end
    
    def current_project
      TimeTracker::Project.find(TimeTracker.config["current_project_id"])
    end
    
    def external_service
      return @external_service if @external_service
      if config["external_service"] && config["external_service_options"]
        @external_service = TimeTracker::Service.get_service(config["external_service"]).new(config["external_service_options"])
      end
    end
  end
end