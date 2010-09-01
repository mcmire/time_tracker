module TimeTracker
  class Cli < Commander
    include TimeTracker::Cli::Repl
    
    def self.ribeye_debug?
      defined?(Ribeye) && Ribeye.respond_to?(:debug) && Ribeye.debug?
    end
    
    WRONG_ANSWERS = [
      "I'm sorry, I didn't understand you. Try that again:",
      "I'm not sure what you mean. Try again:",
      "Okay, but that's not a valid answer. Again?",
      "Must be the static. Let's try that again:"
    ]
    
    REPL_REGEX = /(?:^|[ ])(?:"([^"]+)"|'([^']+)'|([^ ]+))/
    
    cmd :add, :args => "{task|project} NAME", :desc => "Adds a task or a project."
    def add(what, name=nil)
      case what
      when "project"
        raise Error, "Right, but what do you want to call the new project?" unless name
        TimeTracker.external_service.andand.pull_projects
        if project = TimeTracker::Project.first(:name => name)
          raise Error, "It looks like this project already exists."
        else
          project = TimeTracker::Project.create!(:name => name)
          stdout.puts %{Project "#{project.name}" created.}
        end
      when "task"
        raise Error, "Right, but what do you want to call the new task?" unless name
        curr_proj = get_current_project()
        TimeTracker.external_service.andand.pull_tasks(curr_proj)
        if existing_task = curr_proj.tasks.find_by_name(name)
          if existing_task.unstarted?
            raise Error, "It looks like you've already added that task. Perhaps you'd like to upvote it instead?"
          elsif existing_task.paused?
            raise Error, "Aren't you still working on that task?"
          elsif existing_task.running?
            raise Error, "Aren't you already working on that task?"
          end
        end
        task = curr_proj.tasks.create!(:name => name)
        stdout.puts %{Task "#{task.name}" created.}
      end
    end
    
    cmd :switch, :args => "PROJECT", :desc => "Switches to a certain project. The project is created if it does not already exist."
    def switch(project_name=nil)
      raise Error, "Right, but which project do you want to switch to?" unless project_name
      TimeTracker.external_service.andand.pull_projects
      project = TimeTracker::Project.first(:name => project_name)
      unless project
        project = yes_or_no "I can't find this project. Did you want to create it? (y/n)" do
          TimeTracker::Project.create!(:name => project_name)
        end
      end
      if curr_proj = TimeTracker.current_project
        TimeTracker.external_service.andand.pull_tasks(curr_proj)
        if running_task = curr_proj.tasks.last_running
          running_task.pause!
          stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
        end
      end
      TimeTracker.config.update("current_project_id", project.id)
      stdout.puts %{Switched to project "#{project.name}".}
      if paused_task = project.tasks.last_paused
        paused_task.resume!
        stdout.puts %{(Resuming clock for "#{paused_task.name}".)}
      end
    end
    
    cmd :start, :args => "TASK", :desc => "Creates a new task, and starts the clock for it."
    def start(task_name=nil)
      raise Error, "Right, but which task do you want to start?" unless task_name
      curr_proj = get_current_project()
      TimeTracker.external_service.andand.pull_tasks(curr_proj)
      if task = curr_proj.tasks.not_stopped.first(:name => task_name)
        if message = task.invalid_message_for_transition_to("start")
          raise Error, message
        end
      end
      unless task
        task = yes_or_no "I can't find this task. Did you want to create it? (y/n)" do
          curr_proj.tasks.build(:name => task_name)
        end
      end
      if running_task = curr_proj.tasks.last_running
        running_task.pause!
        stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
      end
      task.start!
      stdout.puts %{Started clock for "#{task.name}".}
    end
    
    cmd :stop, :args => "[TASK]", :desc => "Stops the clock for a task, or the last task if no task given"
    def stop(arg=:last)
      curr_proj = get_current_project()
      TimeTracker.external_service.andand.pull_tasks(curr_proj)
      raise Error, "It doesn't look like you've started any tasks yet." if curr_proj.tasks.empty?
      if arg == :last
        task = curr_proj.tasks.last_running
        raise Error, "It doesn't look like you're working on anything at the moment." unless task
      else
        task = find_task(arg, "stop")
      end
      was_paused = task.paused?
      task.stop!
      if was_paused
        stdout.puts %{Stopped clock for "#{task.name}".}
      else
        stdout.puts %{Stopped clock for "#{task.name}", at #{task.total_running_time}.}
      end
      if paused_task = curr_proj.tasks.last_paused
        paused_task.resume!
        stdout.puts %{(Resuming clock for "#{paused_task.name}".)}
      end
    end
    
    cmd :resume, :args => "[TASK]", :desc => "Resumes the clock for a task, or the last task if no task given"
    def resume(arg=nil)
      raise Error, "Yes, but which task do you want to resume? (I'll accept a number or a name.)" unless arg
      curr_proj = get_current_project()
      TimeTracker.external_service.andand.pull_tasks(curr_proj)
      raise Error, "It doesn't look like you've started any tasks yet." unless TimeTracker::Task.exists?
      already_paused = false
      task = find_task(arg, "resume")
      if running_task = curr_proj.tasks.last_running
        running_task.pause!
        stdout.puts %{(Pausing clock for "#{running_task.name}", at #{running_task.total_running_time}.)}
      end
      if task.project_id != curr_proj.id
        curr_proj = task.project
        TimeTracker.config.update("current_project_id", curr_proj.id.to_s)
        stdout.puts %{(Switching to project "#{curr_proj.name}".)}
      end
      task.resume!
      stdout.puts %{Resumed clock for "#{task.name}".}
    end
    
    cmd :upvote, :args => "[TASK]", :desc => "Records the number of times you've been asked to do a certain task."
    def upvote(task_name=nil)
      raise Error, "Yes, but which task do you want to upvote? (I'll accept a number or a name.)" unless task_name
      curr_proj = get_current_project()
      TimeTracker.external_service.andand.pull_tasks(curr_proj)
      if task_name =~ /^\d+$/
        unless task = curr_proj.tasks.first(:number => task_name.to_i)
          raise Error, "I don't think that task exists."
        end
      else
        matching_tasks = curr_proj.tasks.where(:name => task_name).sort(:created_at.desc).to_a
        if matching_tasks.any?
          unless task = matching_tasks.find(&:unstarted?)
            task = matching_tasks.first
          end
        else
          raise Error, "I don't think that task exists."
        end
      end
      if task.running? || task.paused?
        raise Error, "There isn't any point in upvoting a task you're already working on."
      end
      if task.stopped?
        raise Error, "There isn't any point in upvoting a task you've already completed."
      end
      task.upvote!
      stdout.puts %{This task now has #{task.num_votes} votes.\n}
    end

    LIST_SUBCOMMANDS = ["lastfew", "completed", "all", "today", "this week"]
    cmd :list, :args => '{'+LIST_SUBCOMMANDS.join("|")+'}', :desc => "List tasks"
    def list(*args)
      type = args.join(" ")
      type = "lastfew" if type.empty?
      
      raise_invalid_invocation_error(@current_command) unless LIST_SUBCOMMANDS.include?(type)
      
      unless TimeTracker::Task.exists?
        stdout.puts "It doesn't look like you've started any tasks yet."
        return
      end
      
      TimeTracker.external_service.andand.pull_tasks
      
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
    end
    
    cmd :search, :args => "QUERY...", :desc => "Search for a task by name"
    def search(*args)
      raise Error, "Okay, but what do you want to search for?" if args.empty?
      TimeTracker.external_service.andand.pull_tasks
      re = Regexp.new(args.map {|a| Regexp.escape(a) }.join("|"))
      tasks = TimeTracker::Task.where(:name => re).sort(:last_started_at.desc).to_a
      #pp :tasks => tasks
      stdout.puts "Search results:"
      rows = tasks.map {|task| task.info_for_search }
      alignments = [:none, :right, :none, :none, :left, :none, :left, :none, :none, :right]
      lines = Columnator.columnate(rows, :alignments => alignments)
      for line in lines
        stdout.puts(line)
      end
    end
    
    cmd :configure, :desc => "Configures tt"
    def configure
      yes_or_no "Do you want to sync projects and tasks with Pivotal Tracker? (y/n) " do
        if TimeTracker::Project.exists? || TimeTracker::Task.exists?
          stderr.puts "Actually -- you can't do that if you've already created a project or task. Sorry."
          raise Abort
        end
        keep_prompting "What's your API key?" do |answer|
          if answer.blank?
            print_wrong_answer
            false
          else
            service = TimeTracker::Service::PivotalTracker.new(:api_key => answer)
            if service.valid?
              stdout.puts "Great, you're all set up to use tt with Pivotal Tracker now!"
              TimeTracker.external_service = service
              TimeTracker.config.update_many(
                "external_service" => "pivotal_tracker",
                "external_service_options" => {"api_key" => answer}
              )
              true
            else
              stderr.print "Hmm, I'm not able to connect using that key. Try that again: "
              stderr.flush
              false
            end
          end
        end
      end
    end
    
    cmd :clear, :desc => "Clears everything"
    def clear
      TimeTracker::Project.delete_all
      TimeTracker::Task.delete_all
      TimeTracker::TimePeriod.delete_all
      TimeTracker::Config.collection.drop
      stdout.puts "Everything cleared."
    end
    
  private
    def debug_stdout
      $RUNNING_TESTS == :integration ? $orig_stdout : stdout
    end
  
    # Override method in Commander
    def handle_command_error(e)
      if $RUNNING_TESTS == :units
        raise(e)
      else
        stderr.puts(e.message)
        exit 1 unless within_repl?
      end
    end
    
    def get_current_project
      curr_proj = TimeTracker.current_project
      raise Error, "Try switching to a project first." unless curr_proj
      curr_proj
    end
    
    def find_task(arg, next_event)
      # Note that we look in other projects only for resume, since it's impossible
      # to have started a task we want to stop without that task being in the same
      # project that we are in right now (since switching to another project
      # would have stopped it automatically anyway)
      
      curr_proj = TimeTracker.current_project
      event = TimeTracker::Task.state_machine.events[next_event]
      if arg =~ /^\d+$/
        tasks = (next_event == "resume" ? TimeTracker::Task : curr_proj.tasks)
        unless task = tasks.first(:number => arg.to_i)
          raise Error, "I don't think that task exists."
        end
      else
        matching_tasks = curr_proj.tasks.where(:name => arg).sort(:created_at.desc).to_a
        if matching_tasks.any?
          unless task = matching_tasks.find {|task| event.allowed_previous_states.include?(task.state) }
            task = matching_tasks.first
          end
        elsif next_event != "resume"
          raise Error, "I don't think that task exists." 
        else
          tasks = TimeTracker::Task.where(:state => event.allowed_previous_states, :name => arg, :project_id.ne => curr_proj.id)
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
      end
      if message = event.invalid_message_for_transition_from(task.state)
        raise Error, message
      end
      return task
    end
  
    def print_wrong_answer
      answer = WRONG_ANSWERS[@wrong_answer_index]
      stderr.print(answer + " ")
      stderr.flush
    ensure
      @wrong_answer_index += 1
      @wrong_answer_index %= WRONG_ANSWERS.size
    end
    
    def keep_prompting(msg)
      msg += " " unless msg =~ /[ ]$/
      @wrong_answer_index = 0
      debug_stdout.puts "Writing to stdout in child..." if self.class.ribeye_debug?
      stdout.print(msg)
      stdout.flush
      ret = nil
      num_blank_answers = 0
      loop do
        debug_stdout.puts "Reading stdin in child..." if self.class.ribeye_debug?
        answer = stdin.gets.to_s.strip
        debug_stdout.puts "Answer: #{answer.inspect}" if self.class.ribeye_debug?
        #if answer.blank?
        #  print_wrong_answer
        #  num_blank_answers += 1
        #  if num_blank_answers == 2
        #    stderr.puts "Okay, never mind then."
        #    raise Abort
        #  end
        #  next
        #end
        ret = yield(answer)
        break if ret or $RUNNING_TESTS == :units
      end
      ret
    end
    
    def yes_or_no(msg, &block)
      keep_prompting(msg) do |answer|
        case answer
        when /^y(es)?$/i
          yield
        when /^n(o)?$/i
          stdout.puts %{Okay, never mind then.}
          raise Abort
        else
          print_wrong_answer
          false
        end
      end
    end
  end
end