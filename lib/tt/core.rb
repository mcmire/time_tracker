
require 'tt/config'
require 'tt/logging'

module TimeTracker
  class << self
    attr_writer :current_project, :external_service

    def setup
      load config_path("environments/#{config.environment}.rb")
    end

    def world
      # TODO: Maybe this should not be stored in the db, but just in memory or in /tmp
      @world || reload_world
    end

    # TODO: world.reload
    def reload_world
      @world = TimeTracker::Models::World.find()
    end

    def current_project
      TimeTracker::Project.find(TimeTracker.world["current_project_id"])
    end

    def external_service
      return @external_service if @external_service
      if world["external_service"] && world["external_service_options"]
        @external_service = TimeTracker::Service.get_service(world["external_service"]).new(world["external_service_options"])
      end
    end
  end
end
