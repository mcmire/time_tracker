module TimeTracker
  class Cli < Thor
    # Is this needed anymore?
    namespace :default
    
    class << self
      def build(stdout, stderr)
        cli = new()
        cli.stdout = stdout
        cli.stderr = stderr
        cli
      end
      
    protected
      # Override Thor's handle_argument_error method to give a nicer message
      def handle_argument_error(task, error)
        raise Thor::InvocationError, "Oops! That isn't the right way to call #{task.name.inspect}. Try this instead: #{self.banner(task)}."
      end
    end
    
    attr_accessor :stdout, :stderr
    
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
      
      def raise_invalid_argument_error
        # We have to do this mad hackery b/c thor doesn't let us get this info straightforwardly
        if thor_task = self.instance_variable_get("@_initializer")[2][:current_task]
          self.class.send(:handle_argument_error, thor_task, nil)
        else
          # okay, must be running a unit test.
          raise ArgumentError
        end
      end
    end
    
    desc "switch PROJECT", "Switches to a certain project. The project is created if it does not already exist."
    def switch(project_name=nil)
      die "Right, but which project do you want to switch to?" unless project_name
      if curr_proj = TimeTracker::Project.find(TimeTracker.config["current_project_id"]) and
      running_task = curr_proj.tasks.last_running
        running_task.pause!
        @stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
      end
      proj = TimeTracker::Project.first(:name => project_name) || TimeTracker::Project.create!(:name => project_name)
      TimeTracker.config.update("current_project_id", proj.id)
      @stdout.puts %{Switched to project "#{proj.name}".}
      if paused_task = proj.tasks.last_paused
        paused_task.resume!
        @stdout.puts %{(Resuming clock for "#{paused_task.name}".)}
      end
    end
    
    desc "start TASK", "Creates a new task, and starts the clock for it."
    def start(task_name=nil)
      die "Right, but what's the name of your task?" unless task_name
      curr_proj = TimeTracker::Project.find(TimeTracker.config["current_project_id"])
      die "Try switching to a project first." unless curr_proj
      task = curr_proj.tasks.first(:name => task_name)
      die "Aren't you already working on that task?" if task && task.running?
      task ||= curr_proj.tasks.build(:name => task_name)
      if running_task = curr_proj.tasks.last_running
        running_task.pause!
        @stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
      end
      task.save!
      @stdout.puts %{Started clock for "#{task.name}".}
    end
    
    desc "stop [TASK]", "Stops the clock for a task, or the last task if no task given"
    def stop(task_name=:last)
      curr_proj = TimeTracker::Project.find TimeTracker.config["current_project_id"]
      die "Try switching to a project first." unless curr_proj
      die "It doesn't look like you've started any tasks yet." if curr_proj.tasks.empty?
      if task_name == :last
        task = curr_proj.tasks.last_running
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
      @stdout.puts %{Stopped clock for "#{task.name}", at #{task.total_running_time}.}
      if paused_task = curr_proj.tasks.last_paused
        paused_task.resume!
        @stdout.puts %{(Resuming clock for "#{paused_task.name}".)}
      end
    end
    
    desc "resume [TASK]", "Resumes the clock for a task, or the last task if no task given"
    def resume(task_name=nil)
      die "Yes, but which task do you want to resume? (I'll accept a number or a name.)" unless task_name
      curr_proj = TimeTracker::Project.find TimeTracker.config["current_project_id"]
      die "It doesn't look like you've started any tasks yet." unless TimeTracker::Task.exists?
      already_paused = false
      if task_name =~ /^\d+$/
        if task = TimeTracker::Task.first(:number => task_name.to_i)        
          if task.project_id != curr_proj.id
            if running_task = curr_proj.tasks.last_running
              running_task.pause!
              @stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
              already_paused = true
            end
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
          tasks = TimeTracker::Task.not_running.where(:name => task_name, :project_id.ne => curr_proj.id)
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
      if running_task = curr_proj.tasks.last_running and !already_paused
        running_task.pause!
        @stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
      end
      task.resume!
      @stdout.puts %{Resumed clock for "#{task.name}".}
    end

    LIST_SUBCOMMANDS = ["lastfew", "completed", "all", "today", "this week"]
    desc "list {#{LIST_SUBCOMMANDS.join("|")}}", "List tasks"
    def list(*args)
      type = args.join(" ")
      type = "lastfew" if type.empty?
      
      raise_invalid_argument_error unless LIST_SUBCOMMANDS.include?(type)
      
      unless TimeTracker::Task.exists?
        @stdout.puts "It doesn't look like you've started any tasks yet."
        return
      end
      
      records = []
      case type
      when "lastfew"
        records = TimeTracker::TimePeriod.limit(5).sort(:ended_at.desc).to_a
        header = "Latest tasks:"
      when "completed"
        records = TimeTracker::TimePeriod.sort(:ended_at.desc).to_a
        header = "Completed tasks:"
      when "all"
        records = TimeTracker::TimePeriod.sort(:ended_at.desc).to_a
        header = "All tasks:"
      when "today"
        records = TimeTracker::TimePeriod.ended_today.sort(:ended_at.desc).to_a
        header = "Today's tasks:"
      when "this week"
        records = TimeTracker::TimePeriod.ended_this_week.sort(:ended_at).to_a
        header = "This week's tasks:"
      end
      
      unless type == "completed"
        if task = TimeTracker::Task.last_running
          records.pop if type == "lastfew" && records.size == 5
          if type == "this week"
            records << task
          else
            records.unshift(task)
          end
        end
      end
      
      raise "Nothing to print?!" if records.empty?
      include_date = (type == "lastfew")
      record_infos = records.map {|record| record.info(:include_date => include_date) }
      if include_date
        alignments = [:right, :none, :right, :none, :right, :none, :right, :none, :none]
      else
        alignments = [:right, :none, :right, :none, :none]
      end
      lines = Columnator.columnate(record_infos, :alignments => alignments, :write_to => :array)
      @stdout.puts
      @stdout.puts(header)
      @stdout.puts
      if type == "lastfew" || type == "today"
        for line in lines
          @stdout.puts(line)
        end
      else
        grouped_lines = ActiveSupport::OrderedHash.new
        lines.each_with_index do |line, i| 
          record = records[i]
          date = (TimeTracker::Task === record ? record.created_at : record.ended_at).to_date
          (grouped_lines[date] ||= []) << [record, line]
        end
        grouped_lines.each_with_index do |(date, recordlines), i|
          @stdout.puts date.to_s(:relative_date) + ":"
          recordlines.each do |record, line|
            @stdout.puts("  " + line)
          end
          @stdout.puts unless i == grouped_lines.size-1
        end
      end
      @stdout.puts
    end
    
    desc "search QUERY", "Search for a task"
    def search(query=nil)
      
    end
    
    desc "clear", "Clears everything"
    def clear
      TimeTracker::Project.delete_all
      TimeTracker::Task.delete_all
      TimeTracker::Config.collection.drop
      @stdout.puts "Everything cleared."
    end
  end
end