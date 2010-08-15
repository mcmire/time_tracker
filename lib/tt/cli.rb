module TimeTracker
  class Cli < Thor
    class Error < StandardError; end
    
    # Is this needed anymore?
    namespace :default
    
    class << self
      attr_accessor :stdin, :stdout, :stderr
      
      def stdin
        $stdin
      end
      
      def stdout
        $stdout
      end
      
      def stderr
        $stderr
      end
      
      def within_repl?
        @within_repl
      end
      
      def build(stdin, stdout, stderr)
        cli = new()
        cli.stdin  = stdin
        cli.stdout = stdout
        cli.stderr = stderr
        cli
      end
      
      def run(argv)
        if argv.reject {|a| a =~ /^-/ }.empty?
          start_repl
        else
          start(argv)
        end
      end
      
      REPL_REGEX = /(?:^|[ ])(?:"([^"]+)"|'([^']+)'|([^ ]+))/
      
      def start_repl
        @within_repl = true
        require 'readline'
        require 'term/ansicolor'
        stdout.puts "Welcome to TimeTracker."
        if curr_proj = TimeTracker::Project.find(TimeTracker.config["current_project_id"])
          stdout.puts %{You're currently in the "#{curr_proj.name}" project.}
        end
        stdout.puts "What would you like to do?"
        load_history
        stdout.sync = true
        loop do
          begin
            stdout.print Color.bold + Color.yellow
            #stdout.print "> "
            #line = stdin.gets.chomp
            line = Readline.readline("> ")
            stdout.print Color.clear
            #stdout.puts "ok"
            end_repl if line =~ /^(exit|quit|q)$/
            Readline::HISTORY << line
            Readline::HISTORY.unshift if Readline::HISTORY.size > 100
            args = line.scan(REPL_REGEX).map {|a| a.compact.first }
            start(args)
          rescue Interrupt => e
            stdout.print Color.clear
            stdout.puts 'Type "exit", "quit", or "q" to quit.'
            #end_repl(true)
          rescue Exception => e
            raise(e)
          end
        end
      end
      
      def end_repl(interrupted=false)
        stdout.puts if interrupted
        stdout.puts "Thanks for playing!"
        save_history
        exit
      end
      
      def history_file
        File.join(ENV["HOME"], ".tt_history")
      end
      
      def load_history
        #puts "Loading history..."
        File.open(history_file, "r") do |f|
          f.each {|line| Readline::HISTORY << line }
        end
      rescue Errno::ENOENT
      end
      
      def save_history
        #puts "Saving history..."
        File.open(history_file, "w") do |f|
          Readline::HISTORY.each {|line| f.puts(line) }
        end
      end
      
      # Override Thor's handle_argument_error method to customize the message
      def handle_argument_error(task, error)
        raise Thor::InvocationError, "Oops! That isn't the right way to call #{task.name.inspect}. Try this instead: #{self.banner(task)}."
      end
      
      # Override Thor's handle_no_task_error method to customize the message
      def handle_no_task_error(task)
        stderr.puts "Oops! #{task.inspect} isn't a valid command. Try one of these instead:"
        # don't feel like hacking thor to get the instance, so let's cheat
        shell = Thor::Base.shell.new
        help(shell)
        exit 1
      end
    end
    
    attr_accessor :stdin, :stdout, :stderr
    
    def initialize(*args)
      # These are just the default values for normal use;
      # if you want to override these, use .build
      @stdin  = $stdin
      @stdout = $stdout
      @stderr = $stderr
      super
    end
    
    no_tasks do
      def handle_error(e)
        if $RUNNING_TESTS == :units
          raise(e)
        else
          stderr.puts(e.message)
          exit 1 unless self.class.within_repl?
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
      raise Error, "Right, but which project do you want to switch to?" unless project_name
      if curr_proj = TimeTracker::Project.find(TimeTracker.config["current_project_id"]) and
      running_task = curr_proj.tasks.last_running
        running_task.pause!
        stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
      end
      proj = TimeTracker::Project.first(:name => project_name) || TimeTracker::Project.create!(:name => project_name)
      TimeTracker.config.update("current_project_id", proj.id)
      stdout.puts %{Switched to project "#{proj.name}".}
      if paused_task = proj.tasks.last_paused
        paused_task.resume!
        stdout.puts %{(Resuming clock for "#{paused_task.name}".)}
      end
    rescue Error => e
      handle_error(e)
    rescue Exception => e
      raise(e)
    end
    
    desc "start TASK", "Creates a new task, and starts the clock for it."
    def start(task_name=nil)
      raise Error, "Right, but what's the name of your task?" unless task_name
      curr_proj = TimeTracker::Project.find(TimeTracker.config["current_project_id"])
      raise Error, "Try switching to a project first." unless curr_proj
      task = curr_proj.tasks.first(:name => task_name)
      raise Error, "Aren't you already working on that task?" if task && task.running?
      task ||= curr_proj.tasks.build(:name => task_name)
      if running_task = curr_proj.tasks.last_running
        running_task.pause!
        stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
      end
      task.save!
      stdout.puts %{Started clock for "#{task.name}".}
    rescue Error => e
      handle_error(e)
    rescue Exception => e
      raise(e)
    end
    
    desc "stop [TASK]", "Stops the clock for a task, or the last task if no task given"
    def stop(task_name=:last)
      curr_proj = TimeTracker::Project.find TimeTracker.config["current_project_id"]
      raise Error, "Try switching to a project first." unless curr_proj
      raise Error, "It doesn't look like you've started any tasks yet." if curr_proj.tasks.empty?
      if task_name == :last
        task = curr_proj.tasks.last_running
        raise Error, "It doesn't look like you're working on anything at the moment." unless task
      elsif task_name =~ /^\d+$/
        task = curr_proj.tasks.first(:number => task_name.to_i)
        raise Error, "I don't think that task exists." unless task
        raise Error, "I think you've stopped that task already." if task.stopped?
      else
        task = curr_proj.tasks.first(:name => task_name)
        raise Error, "I don't think that task exists." unless task
        raise Error, "I think you've stopped that task already." if task.stopped?
      end
      task.stop!
      stdout.puts %{Stopped clock for "#{task.name}", at #{task.total_running_time}.}
      if paused_task = curr_proj.tasks.last_paused
        paused_task.resume!
        stdout.puts %{(Resuming clock for "#{paused_task.name}".)}
      end
    rescue Error => e
      handle_error(e)
    rescue Exception => e
      raise(e)
    end
    
    desc "resume [TASK]", "Resumes the clock for a task, or the last task if no task given"
    def resume(task_name=nil)
      raise Error, "Yes, but which task do you want to resume? (I'll accept a number or a name.)" unless task_name
      curr_proj = TimeTracker::Project.find TimeTracker.config["current_project_id"]
      raise Error, "Try switching to a project first." unless curr_proj
      raise Error, "It doesn't look like you've started any tasks yet." unless TimeTracker::Task.exists?
      already_paused = false
      if task_name =~ /^\d+$/
        if task = TimeTracker::Task.first(:number => task_name.to_i)        
          if task.project_id != curr_proj.id
            if running_task = curr_proj.tasks.last_running
              running_task.pause!
              stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
              already_paused = true
            end
            curr_proj = task.project
            TimeTracker.config.update("current_project_id", curr_proj.id.to_s)
            stdout.puts %{(Switching to project "#{curr_proj.name}".)}
          end
          raise Error, "Aren't you working on that task already?" if task.running?
        else
          raise Error, "I don't think that task exists."
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
            raise Error, "That task doesn't exist here. Perhaps you meant to switch to #{projects}?"
          else
            raise Error, "I don't think that task exists." 
          end
        end
        raise Error, "Aren't you working on that task already?" if task.running?
      end
      if running_task = curr_proj.tasks.last_running and !already_paused
        running_task.pause!
        stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
      end
      task.resume!
      stdout.puts %{Resumed clock for "#{task.name}".}
    rescue Error => e
      handle_error(e)
    rescue Exception => e
      raise(e)
    end

    LIST_SUBCOMMANDS = ["lastfew", "completed", "all", "today", "this week"]
    desc "list {#{LIST_SUBCOMMANDS.join("|")}}", "List tasks"
    def list(*args)
      type = args.join(" ")
      type = "lastfew" if type.empty?
      
      raise_invalid_argument_error unless LIST_SUBCOMMANDS.include?(type)
      
      unless TimeTracker::Task.exists?
        stdout.puts "It doesn't look like you've started any tasks yet."
        return
      end
      
      records = []
      case type
      when "lastfew"
        records = TimeTracker::TimePeriod.sort(:ended_at.desc).limit(5).to_a
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
      
      group_by_date = (type != "lastfew" && type != "today")
      include_day = (
        type == "lastfew" &&
        #!group_by_date &&
        records.grep(TimeTracker::TimePeriod).any? {|record| record.started_at.to_date != record.ended_at.to_date }
      )
      reverse = (type != "this week")
      if include_day
        alignments = [:right, :none, :right, :none, :right, :none, :right, :none, :none, :right, :none, :none, :none]
      else
        alignments = [:left, :right, :left, :none, :left, :right, :left, :none, :none, :right, :none, :none, :none]
      end
      info_arrays = records.map do |record|
        record.info(
          :include_day => include_day,
          :reverse => reverse,
          :where_date => (lambda {|date| date == Date.today } if type == "today")
        )
      end
      #pp :alignments => alignments,
      #   :info_arrays => info_arrays,
      #   :group_by_date => group_by_date,
      #   :include_day => include_day
      columnator = Columnator.new(info_arrays, :alignments => alignments)
      unless include_day
        columnator.each_row = lambda do |data, block|
          data.each do |pairs|
            pairs.each do |pair|
              block.call(pair[1])
            end
          end
        end
        columnator.generate_out = lambda do |data, block|
          data.map do |pairs|
            pairs.map do |pair|
              [pair[0], block.call(pair[1])]
            end
          end
        end
      end
      columnated_rows = columnator.columnate
      #pp :columnated_rows => columnated_rows
      
      stdout.puts
      stdout.puts(header)
      stdout.puts
      
      if group_by_date
        grouped_lines = columnated_rows.inject(ActiveSupport::OrderedHash.new) do |hash, pairs|
          for pair in pairs
            (hash[pair[0]] ||= []) << pair[1]
          end
          hash
        end
        grouped_lines.each_with_index do |(date, lines), i|
          stdout.puts date.to_s(:relative_date) + ":"
          lines.each {|line| stdout.puts("  " + line) }
          stdout.puts unless i == grouped_lines.size-1
        end
      elsif include_day
        columnated_rows.each do |line|
          stdout.puts(line)
        end
      else
        columnated_rows.each do |pairs|
          pairs.each do |pair|
            stdout.puts(pair[1])
          end
        end
      end
      stdout.print "\n"
    rescue Error => e
      handle_error(e)
    rescue Exception => e
      raise(e)
    end
    
    desc "search QUERY...", "Search for a task by name"
    def search(*args)
      raise Error, "Okay, but what do you want to search for?" if args.empty?
      re = Regexp.new(args.map {|a| Regexp.escape(a) }.join("|"))
      tasks = TimeTracker::Task.where(:name => re).sort(:last_started_at.desc).to_a
      #pp :tasks => tasks
      stdout.puts "Search results:"
      rows = tasks.map {|task| task.info_for_search }
      alignments = [:none, :right, :none, :none, :left, :none, :left, :none, :none, :right]
      lines = Columnator.columnate(rows, :alignments => alignments, :write_to => :array)
      for line in lines
        stdout.puts(line)
      end
    rescue Error => e
      handle_error(e)
    rescue Exception => e
      raise(e)
    end
    
    desc "clear", "Clears everything"
    def clear
      TimeTracker::Project.delete_all
      TimeTracker::Task.delete_all
      TimeTracker::TimePeriod.delete_all
      TimeTracker::Config.collection.drop
      stdout.puts "Everything cleared."
    end
  end
end