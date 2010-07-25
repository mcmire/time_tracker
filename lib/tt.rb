require 'tt/ruby_ext'

module TimeTracker
  class << self
    attr_accessor :current_project
    
    def config
      # TODO: Maybe this should not be stored in the db, but just in memory or in /tmp
      @config ||= TimeTracker::Config.find()
    end
  end
  autoload :Cli, 'tt/cli'
  autoload :Config, 'tt/config'
  autoload :Project, 'tt/project'
  autoload :Task, 'tt/task'
end