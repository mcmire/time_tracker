module TimeTracker
  class << self
    attr_accessor :current_project
    
    def config
      @config ||= TimeTracker::Config.find()
    end
  end
  autoload :Cli, 'tt/cli'
  autoload :Config, 'tt/config'
  autoload :Project, 'tt/project'
  autoload :Task, 'tt/task'
end