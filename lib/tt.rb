module TimeTracker
  class << self
    attr_accessor :current_project
  end
  autoload :Cli, 'tt/cli'
  autoload :Project, 'tt/project'
  autoload :Task, 'tt/task'
end