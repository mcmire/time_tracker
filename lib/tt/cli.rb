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
        @stdout.puts %{(Resuming clock for "#{paused_task.name}".)}
      end
    end
    
    desc "start TASK", "Creates a new task, and starts the clock for it."
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
    
    desc "stop [TASK]", "Stops the clock for a task, or the last task if no task given"
    def stop(task_name=:last)
      curr_proj = TimeTracker::Project.find TimeTracker.config["current_project_id"]
      die "Try switching to a project first." unless curr_proj
      die "You haven't started working on anything yet." if curr_proj.tasks.empty?
      if task_name == :last
        task = curr_proj.tasks.running.last
        die "It doesn't look like you're working on anything at the moment." unless task
      elsif task_name =~ /^\d+$/
        task = curr_proj.tasks.first(:number => task_name.to_i)
        die "I don't think that task exists." unless task
        die "I think you've stopped that task already." if task.stopped?
      else
        task = curr_proj.tasks.first(:name => task_name)
        die "I don't think that task exists." unless task
        die "I think you've stopped that task already." if task.stopped?
      end
      task.stop!
      @stdout.puts %{Stopped clock for "#{task.name}", at #{task.running_time}.}
      if paused_task = curr_proj.tasks.paused.last
        paused_task.resume!
        @stdout.puts %{(Resuming clock for "#{paused_task.name}".)}
      end
    end
    
    desc "resume [TASK]", "Resumes the clock for a task, or the last task if no task given"
    def resume(task_name=:last)
      curr_proj = TimeTracker::Project.find TimeTracker.config["current_project_id"]
      if task_name == :last
        die "You haven't started working on anything yet." if curr_proj.tasks.empty?
        task = curr_proj.tasks.stopped.last
        die "Aren't you still working on something?" unless task
      elsif task_name =~ /^\d+$/
        if task = TimeTracker::Task.first(:number => task_name.to_i)        
          if task.project_id != curr_proj.id
            curr_proj = task.project
            TimeTracker.config.update("current_project_id", curr_proj.id.to_s)
            @stdout.puts %{(Switching to project "#{curr_proj.name}".)}
          end
          die "Yes, you're still working on that task." if task.running?
        else
          die "I don't think that task exists."
        end
      else
        task = curr_proj.tasks.first(:name => task_name)
        unless task
          tasks = TimeTracker::Task.stopped.where(:name => task_name, :project_id.ne => curr_proj.id)
          if tasks.any?
            # Might be better to do this w/ native Ruby driver
            # See <http://groups.google.com/group/mongomapper/browse_thread/thread/1a5a5b548123e07e/0c65f3e770e04f29>
            projects = tasks.map(&:project).uniq.
                       map {|p| %{"#{p.name}"} }.
                       to_sentence(:two_words_connector => " or ", :last_word_connector => ", or ")
            die "That task doesn't exist here. Perhaps you meant to switch to #{projects}?"
          else
            die "I don't think that task exists." 
          end
        end
        die "Yes, you're still working on that task." if task.running?
      end
      if running_task = curr_proj.tasks.running.last
        running_task.pause!
        @stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.running_time}.)}
      end
      task.resume!
      @stdout.puts %{Resumed clock for "#{task.name}".}
    end
    
    desc "current", "List current tasks"
    def current
      
    end
    
    desc "completed", "List completed tasks"
    def completed
      
    end
  end
end