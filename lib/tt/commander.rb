require 'highline'

module TimeTracker
  class Commander
    class Error < StandardError; end
    class UnknownCommandError < Error; end
    class InvalidInvocationError < Error; end
    class Abort < StandardError; end
    class Break < StandardError
      attr_reader :message
      def initialize(value)
        @message = value
      end
    end

    class << self
      def execute(options={})
        new(options).execute!
      end

      def command(name, info={})
        if info[:subcommands] && !info[:args]
          info[:args] = '{' + info[:subcommands].join("|") + '}'
        end
        commands[name.to_s] = info
      end
      alias :cmd :command

      def commands
        @commands ||= {}
      end

      def command_list
        arr = []
        commands = self.commands.keys.sort.map do |name|
          info = self.commands[name]
          [ [name, info[:args]].join(" "), info[:desc] ]
        end
        width = commands.map {|(usage, desc)| usage.length }.max
        width = 25 if width < 25
        commands.each do |(usage, desc)|
          line = ""
          line << "%-#{width}s" % usage
          line << "   # #{desc}"
          arr << line
        end
        arr
      end
    end

    attr_reader :program_name, :argv, :stdin, :stdout, :stderr, :highline, :current_command

    def initialize(options={})
      @program_name = options[:program_name] || $0
      @argv = options[:argv] || ARGV
      @stdin = options[:stdin] || $stdin
      @stdout = options[:stdout] || $stdout
      @stderr = options[:stderr] || $stderr
      @highline = ::HighLine.new(@stdin, @stdout)
    end

    def execute!
      if @argv.include?("--help") or @argv.include?("-h")
        help
        exit
      end

      name, args = @argv[0], @argv[1..-1]
      begin
        run_command!(name, *args)
      rescue NoMethodError => e
        if e.message =~ /undefined method `#{name}'/
          raise_unknown_command_error(name)
        else
          raise(e)
        end
      rescue ArgumentError => e
        if e.message =~ /wrong number of arguments/ && e.backtrace[0].split(":")[2] =~ /in `#{name}'/
          raise_invalid_invocation_error(@current_command)
        else
          raise(e)
        end
      rescue Exception => e
        raise(e)
      end
    end

    def run_command!(name, *args)
      info = self.class.commands[name] or raise_unknown_command_error(name)
      @current_command = {:name => name}.merge(info)
      if @current_command[:subcommands] && args.any? && !@current_command[:subcommands].include?(args.first)
        raise_invalid_invocation_error(@current_command)
      end
      __send__(name, *args)
    rescue Abort => e
      # All we're trying to do here is exit the command method,
      # not necessarily the whole program
      stderr.puts(e.message) if e.message.present?
      return
    rescue Error => e
      handle_command_error(e)
    end

    def handle_command_error(e)
      if $RUNNING_TESTS == :units
        raise(e)
      else
        stderr.puts(e.message)
        if self.class.respond_to?(:within_repl?) and !self.class.within_repl?
          exit 1
        end
      end
    end

    cmd :help, :desc => "Prints the available tasks"
    def help
      stdout.puts "Available tasks:"
      print_available_tasks
    end

  private
    def raise_unknown_command_error(name)
      msg = %{Oops! "#{name}" isn't a command. Try one of these instead:\n}
      msg << "\n"
      msg << self.class.command_list.map {|s| "  #{s}\n" }.join
      msg << "\n"
      raise UnknownCommandError, msg
    end

    def raise_invalid_invocation_error(cmd)
      msg = %{Oops! That isn't the right way to call "#{cmd[:name]}". Try this instead: #{@program_name} #{cmd[:name]} #{cmd[:args]}}
      raise InvalidInvocationError, msg
    end

    def print_available_tasks
      stdout.puts "\n"
      stdout.puts self.class.command_list.map {|str| "  #{str}\n" }.join
      stdout.puts "\n"
    end
  end
end
