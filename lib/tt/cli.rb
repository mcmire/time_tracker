module TimeTracker
  class Cli < Thor
    attr_reader :stdout, :stderr
    def initialize(stdout=$stdout, stderr=$stderr)
      @stdout = stdout
      @stderr = stderr
      super()
    end
    
    no_tasks do
      def puts(*args)
        @stdout.puts(*args)
      end
    
      def print(*args)
        @stdout.print(*args)
      end
    end
    
    desc "start TASK", "Starts the clock on a task"
    def start(task)
      TimeTracker::Task.create!(
        :project => TimeTracker.current_project,
        :name => task
      )
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