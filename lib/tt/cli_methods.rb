module TimeTracker
  module CliMethods
    class Error < StandardError; end
    class Abort < StandardError; end
    
    def self.included(base)
      base.class_eval do
        include InstanceMethods
        extend  ClassMethods
      end
    end
    
    module ClassMethods  
      def command(name, info={})
        commands[name.to_sym] = info
      end
      alias :cmd :command
      
      def commands
        @commands ||= ActiveSupport::OrderedHash.new
      end
      
      def command_list
        arr = []
        commands = self.commands.map {|name, info| [[name, info[:args]].join(" "), info[:desc]] }
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
    
    module InstanceMethods
      def self.included(base)
        base.class_eval do
          attr_reader :program_name, :argv, :stdin, :stdout, :stderr
        end
      end
      
      def initialize(program_name, options={})
        @program_name = program_name
        @argv   = options[:argv]   || ARGV
        @stdin  = options[:stdin]  || $stdin
        @stdout = options[:stdout] || $stdout
        @stderr = options[:stderr] || $stderr
      end
      
      def dispatch
        name, args = @argv[0].to_sym, @argv[1..-1]
        info = self.class.commands[name] or raise_unknown_command_error(name, args, info)
        __send__(name, *args)
      rescue ArgumentError => e
        raise_invalid_invocation_error(name, args, info, e) or raise(e)
      rescue NoMethodError => e
        raise_unknown_command_error(name, args, info, e) or raise(e)
      rescue Exception => e
        #puts "#{e.class}: #{e.message}"
        #puts e.backtrace.join("\n")
        raise(e)
      end
      
    private
      def raise_unknown_command_error(name, args, info, e=nil)
        if !e || e.message =~ /undefined method `#{name}'/
          msg = %{Oops! "#{name}" isn't a command. Try one of these instead:\n}
          msg << "\n"
          msg << self.class.command_list.map {|s| "  #{s}\n" }.join
          msg << "\n"
          raise Error, msg
        end
      end
      
      def raise_invalid_invocation_error(name, args, info, e=nil)
        if !e || (e.message =~ /wrong number of arguments/ && e.backtrace[0].split(":")[2] =~ /in `#{name}'/)
          msg = %{Oops! That isn't the right way to call "#{name}". Try this instead: #{@program_name} #{name} #{info[:args]}}
          raise Error, msg
        end
      end
    end
  end
end