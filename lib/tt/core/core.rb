
# XXX: core/core? really??

module TimeTracker
  module Core
    def Core.hook_into(base)
      base.extend(Core)
    end

    attr_accessor :_world_class, :_project_class, :_service_factory
    attr_writer :current_project, :external_service

    def setup
      load config_path("environments/#{config.environment}.rb")
    end

    def world
      _world_class.instance
    end

    def current_project
      _project_class.find(world["current_project_id"])
    end

    def external_service
      return @external_service if @external_service
      if world["external_service"] && world["external_service_options"]
        @external_service = _service_factory.get_service(world["external_service"]).new(world["external_service_options"])
      end
    end

    def _world_class
      @_world_class ||= TimeTracker::Models::World
    end

    def _project_class
      @_project_class ||= TimeTracker::Models::Project
    end

    def _service_factory
      @_service_factory ||= TimeTracker::Service
    end
  end
end
