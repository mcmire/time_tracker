require 'yaml'
require 'fileutils'
#require 'io/wait'

module IntegrationExampleMethods
  extend self
  
  module TeeIO
    attr_accessor :tee
    
    #[:<<, :puts, :print, :write].each do |writer_method|
    [:write].each do |writer_method|
      define_method(writer_method) do |buf|
        @tee << buf
        super(buf)
      end
    end
  end
  
  # Stolen from RSpec
  def working_dir
    @working_dir ||= begin
      dir = File.expand_path(File.join(File.dirname(__FILE__), "/../../tmp/integration-generated-files"))
      FileUtils.mkdir_p(dir)
      dir
    end
  end
  
  def tt_lib
    @tt_lib ||= File.join(File.dirname(__FILE__), "/../../lib")
  end
  
  def stdout
    @stdout[0]
  end
  
  def stderr
    @stderr[0]
  end
  
  def stdin
    @stdin[1]
  end
  
  def output
    ensure_last_command_finished
    stdout.read + stderr.read
  end

  # Stolen from RSpec
  def exit_code
    @exit_code
  end
  
  # Stolen from RSpec
  def tt_command
    @tt_command ||= File.expand_path(File.dirname(__FILE__) + "/../../bin/tt")
  end
  
  def parse_args(args)
    puts "> tt #{args}".bold.yellow if Ribeye.debug?
    args_parser_path = File.expand_path(File.dirname(__FILE__) + '/../support/args_parser.rb')
    # Temporarily override RUBYOPT so that ruby starts *a lot* faster!
    `RUBYOPT="" ruby #{args_parser_path} #{args}`
    YAML.load_file File.join(working_dir, "argv.yml")
  end
  
  def execute_command
    ensure_last_command_finished
    
    # Much of this was copied from Ruby's popen3 implementation
    
    # pipe[0] is reader, pipe[1] is writer
    @stdout = IO.pipe
    @stderr = IO.pipe
    @stdin  = IO.pipe
    (@pipes ||= []).concat [@stdout, @stderr, @stdin]
    
    $orig_stdout = $stdout.dup
    $orig_stderr = $stderr.dup
    
    # TODO: If the parent process dies suddenly while the child is
    # still active, then an Errno::EPIPE will be thrown
    
    @command_pid = fork do
      @stdin[1].close
      $stdin.reopen(@stdin[0])
      @stdin[0].close
      
      @stdout[0].close
      $stdout.reopen(@stdout[1])
      @stdout[1].close
      if Ribeye.debug?
        $stdout.extend(TeeIO)
        $stdout.tee = $orig_stdout
      end
      
      @stderr[0].close
      $stderr.reopen(@stderr[1])
      @stderr[1].close
      if Ribeye.debug?
        $stderr.extend(TeeIO)
        $stderr.tee = $orig_stderr
      end
      
      #$stdin.sync = true
      #$stdout.sync = true
      #$stderr.sync = true
    
      # Somehow this was lost when we forked
      TimeTracker.reload_config
    
      begin
        yield
      rescue SystemExit => e
        $orig_stdout.puts "Got an exit" if Ribeye.debug?
        # just keep going..
      rescue => e
        $orig_stdout.puts "Got a: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}" if Ribeye.debug?
        # just keep going..
      end
      
      # Don't fire the at_exit block that RSpec adds to auto-run all the tests
      exit!(0)
    end
    puts "Child process: #{@command_pid}" if Ribeye.debug?
    
    @stdin[0].close
    @stdout[1].close
    @stderr[1].close
    
    #@stdin[1].sync = true
    #@stdout[0].sync = true
    #@stderr[0].sync = true
    
    #ensure_last_command_finished
  end
  
  def ensure_last_command_finished
    # If a previous execution of `tt` is still going on, wait for it to finish first.
    # (That it hasn't finished yet probably means it's waiting on stdin.)
    if @command_pid
      puts "Waiting for child process #{@command_pid} to finish..." if Ribeye.debug?
      Process.waitpid(@command_pid) 
      puts "Child process #{@command_pid} done with status #{$?.exitstatus}" if Ribeye.debug?
    end
  rescue Errno::ECHILD
    # oh ok, I guess the child's already dead.
  ensure
    @command_pid = nil
  end
  
  def cleanup_open_io
    ensure_last_command_finished
    @pipes.each do |pipe|
      begin; pipe[0].close; rescue IOError; end
      begin; pipe[1].close; rescue IOError; end
    end
    $orig_stdout.close
    $orig_stderr.close
  end
  
  def tt(args)
    ensure_last_command_finished
    time1 = Time.now_without_mock_time
    freezing_time_and_skipping_ahead do
      args = parse_args(args)
      execute_command do
        time3 = Time.now_without_mock_time
        TimeTracker::Cli.execute(:argv => args, :program_name => "tt")
        time4 = Time.now_without_mock_time
        diff2 = time4 - time3
        #puts "Took: #{diff2} seconds"
      end
    end
    time2 = Time.now_without_mock_time
    diff1 = time2 - time1
    #puts "Took: #{diff1} seconds"
  end
  
  def freezing_time_and_skipping_ahead
    return yield if @overriding_time_travel
    # If we've already mocked Time with Timecop, or if we've changed it since
    # the last time 'tt' was called, then start with that mocked time.
    @frozen_time = Time.mock_time if Time.mock_time && Time.mock_time != @last_mock_time
    @frozen_time ||= Time.zone.local(2010, 1, 1, 0, 0, 0)
    Timecop.freeze(@frozen_time)
    ret = yield
    # Next time 'tt' is run, pretend that 2 minutes have passed.
    # This is so that events don't happen too quickly and ensures that if
    # updated_at for a task is set, it's never the same time as what we
    # froze Time.now at just now.
    @frozen_time += 120
    # Store the value of Time.now as we've mocked it with Timecop so we can
    # verify whether Time.now has been re-mocked the next call to 'tt'.
    @last_mock_time = Time.mock_time
    return ret
  end
  
  def with_manual_time_override
    @overriding_time_travel = true
    ret = yield
    @overriding_time_travel = false
    return ret
  end
end