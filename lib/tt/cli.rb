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
      die "Right, but which project do you want to switch to?" if not project_name
      proj = TimeTracker::Project.first(:name => project_name) || TimeTracker::Project.create!(:name => project_name)
      TimeTracker.config.update("current_project_id", proj.id)
      @stdout.puts %{Switched to project "#{project_name}".}
    end
    
    desc "start TASK", "Creates a new task, and starts the clock on it."
    def start(task_name=nil)
      die "Right, but what do you want to call the new task?" if not task_name
      proj = TimeTracker::Project.find TimeTracker.config["current_project_id"]
      die "Try switching to a project first." if not proj
      task = proj.tasks.first(:name => task_name) || proj.tasks.build(:name => task_name)
      die "You're already working on that task." if task.started?
      task.started_at = Time.now
      task.save!
      @stdout.puts %{Started clock for "#{task_name}".}
      num_tasks = TimeTracker::Task.count
      @stdout.puts %{(You're now working on #{num_tasks} tasks.)} if num_tasks.size > 1
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