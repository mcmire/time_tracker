module TimeTracker
  class Cli < Commander
    module Repl
      # Override method in Commander
      def execute!
        if @argv.reject {|a| a =~ /^-/ }.empty?
          start_repl
        else
          super
        end
      end
      
    private
      def within_repl?
        @within_repl
      end

      def start_repl
        @within_repl = true
        require 'readline'
        require 'term/ansicolor'
        stdout.puts "Welcome to TimeTracker."
        if curr_proj = TimeTracker.current_project
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
    end
  end
end