require 'yaml'
require 'fileutils'

module IntegrationExampleMethods
  extend self
  
=begin
  # Forks a ruby interpreter with same type as ourself.
  # juby will fork jruby, ruby will fork ruby etc.
  # Stolen from RSpec
  def forked_ruby(args, stderr=nil)
    config       = ::Config::CONFIG
    interpreter  = File::join(config['bindir'], config['ruby_install_name']) + config['EXEEXT']
    cmd = "#{interpreter} #{args}"
    cmd << " 2> #{stderr}" unless stderr.nil?
    #puts "Running command: <#{cmd}>"
    # Set TEST environment variable here so that the test database will be used instead of the real one
    `TEST=1 #{cmd}`
  end
  
  # Stolen from RSpec
  def ruby(args)
    stderr_file = Tempfile.new('tt')
    stderr_file.close
    Dir.chdir(working_dir) do
      @stdout = forked_ruby("-I #{tt_lib} #{args}", stderr_file.path)
    end
    @stderr = IO.read(stderr_file.path)
    @exit_code = $?.to_i
  end
=end
  
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
  
  # Stolen from RSpec
  def stdout
    @stdout#.strip
  end

  # Stolen from RSpec
  def stderr
    @stderr#.strip
  end
  
  def output
    stdout + stderr
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
  
  def capture_output
    old_stdout = $stdout
    old_stderr = $stderr
    # Use a separate thread to keep changes to $stdout and $stderr contained
    time_zone = Time.zone
    thr = Thread.new do
      # Since the time zone only holds for the current thread, we have to re-set it
      Time.zone = time_zone
      begin
        $stdout = File.open(File.join(working_dir, "stdout.txt"), "w")
        $stderr = File.open(File.join(working_dir, "stderr.txt"), "w")
        yield
      rescue SystemExit => e
        STDOUT.puts "Got an exit" if Ribeye.debug?
        # do nothing
      rescue => e
        STDOUT.puts "Got a: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}" if Ribeye.debug?
        # do nothing
      ensure
        # write to the files
        $stdout.close
        $stderr.close
      end
    end
    #Process.waitpid(pid)
    thr.join
    @stdout = File.read(File.join(working_dir, "stdout.txt"))
    @stderr = File.read(File.join(working_dir, "stderr.txt"))
  ensure
    old_stdout.write(@stdout) if Ribeye.debug?
    old_stderr.write(@stderr) if Ribeye.debug?
    $stdout = old_stdout
    $stderr = old_stderr
  end
  
  def tt(args)
    time1 = Time.now_without_mock_time
    freezing_time_and_skipping_ahead do
      args = parse_args(args)
      capture_output do
        time3 = Time.now_without_mock_time
        TimeTracker::Cli.start(args)
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