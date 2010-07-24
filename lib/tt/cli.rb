require 'thor'

module TimeTracker
  class Cli < Thor
    namespace :default
    
    attr_accessor :stdout, :stderr
    
    def self.build(stdout, stderr)
      cli = new()
      cli.stdout = stdout
      cli.stderr = stderr
      cli
    end
    
    def initialize(*args)
      @stdout = $stdout
      @stderr = $stderr
      super
    end
    
    no_tasks do
      def puts(*args)
        @stdout.puts(*args)
      end
    
      def print(*args)
        @stdout.print(*args)
      end
      
      def die(msg)
        if $RUNNING_TESTS == :units
          raise(msg)
        else
          @stderr.puts msg
          exit 1
        end
      end
    end
    
    desc "switch PROJECT", "Switches to a certain project. The project is created if it does not already exist."
    def switch(project_name=nil)
      die "I'm sorry, *which* project did you want to switch to?" if not project_name
      proj = TimeTracker::Project.first(:name => project_name) || TimeTracker::Project.create!(:name => project_name)
      TimeTracker.config.update("current_project_id", proj.id)
      @stdout.puts %{Switched to project "#{project_name}".}
    end
    
    desc "start TASK", "Starts the clock on a task. The task is created if it does not already exist."
    def start(task_name)
      proj = TimeTracker::Project.find TimeTracker.config["current_project_id"]
      die "Try switching to a project first." if not proj
      task = proj.tasks.first(:name => task_name) || proj.tasks.build(:name => task_name)
      task.started_at = Time.now
      task.save!
      @stdout.puts %{Started clock for "#{task_name}".}
    end
    
    desc "stop [TASK]", "Stops the clock on a task"
    def stop(task=:last)
      
    end
    
    desc "current", "List current tasks"
    def current
      
    end
    
    desc "completed", "List completed tasks"
    def completed
      
    end
  end
end