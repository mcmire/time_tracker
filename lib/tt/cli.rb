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
      die "Right, but which project do you want to switch to?" unless project_name
      if curr_proj = TimeTracker::Project.find(TimeTracker.config["current_project_id"]) and
      running_task = curr_proj.tasks.running.last
        running_task.pause!
        @stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.running_time}.)}
      end
      proj = TimeTracker::Project.first(:name => project_name) || TimeTracker::Project.create!(:name => project_name)
      TimeTracker.config.update("current_project_id", proj.id)
      @stdout.puts %{Switched to project "#{proj.name}".}
      if paused_task = proj.tasks.paused.last
        paused_task.resume!
        @stdout.puts %{(Resuming "#{paused_task.name}".)}
      end
    end
    
    desc "start TASK", "Creates a new task, and starts the clock on it."
    def start(task_name=nil)
      die "Right, but what's the name of your task?" unless task_name
      curr_proj = TimeTracker::Project.find(TimeTracker.config["current_project_id"])
      die "Try switching to a project first." unless curr_proj
      task = curr_proj.tasks.first(:name => task_name) || curr_proj.tasks.build(:name => task_name)
      die "Aren't you already working on that task?" if task.running?
      if running_task = curr_proj.tasks.running.last
        running_task.pause!
        @stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.running_time}.)}
      end
      task.save!
      @stdout.puts %{Started clock for "#{task.name}".}
    end
    
    desc "stop [TASK]", "Stops the clock on a task, or the last task if no tasks given"
    def stop(task_name=:last)
      curr_proj = TimeTracker::Project.find TimeTracker.config["current_project_id"]
      die "Try switching to a project first." unless curr_proj
      die "You haven't started a task under this project yet." if curr_proj.tasks.empty?
      if task_name == :last
        task = curr_proj.tasks.running.last
        die "It looks like all the tasks under this project are stopped." unless task
      elsif task_name =~ /^\d+$/
        task = curr_proj.tasks.first(:number => task_name.to_i)
        die "It looks like that task doesn't exist." unless task
        die "I think you've stopped that task already." if task.stopped?
      else
        task = curr_proj.tasks.first(:name => task_name)
        die "It looks like that task doesn't exist." unless task
        die "I think you've stopped that task already." if task.stopped?
      end
      task.stop!
      @stdout.puts %{Stopped clock for "#{task.name}", at #{task.running_time}.}
      if paused_task = curr_proj.tasks.paused.last
        paused_task.resume!
        @stdout.puts %{(Resuming "#{paused_task.name}".)}
      end
    end
    
    desc "current", "List current tasks"
    def current
      
    end
    
    desc "completed", "List completed tasks"
    def completed
      
    end
  end
end