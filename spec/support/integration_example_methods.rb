require 'fileutils'

module IntegrationExampleMethods
  extend self
  
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
    @stdout.strip
  end

  # Stolen from RSpec
  def stderr
    @stderr.strip
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
    args_parser_path = File.expand_path(File.dirname(__FILE__) + '/../support/args_parser.rb')
    `ruby #{args_parser_path} #{args}`
    YAML.load_file File.join(working_dir, "argv.yml")
  end
  
  def capture_output
    thr = Thread.new do
      begin
        $stdout = File.open(File.join(working_dir, "stdout.txt"), "w")
        $stderr = File.open(File.join(working_dir, "stderr.txt"), "w")
        yield
      rescue SystemExit => e
        ##STDOUT.puts "Got an exit"
      rescue => e
        ##STDOUT.puts "Got a: #{e.class} - #{e.message}"
        # do nothing
      ensure
        $stdout.close
        $stderr.close
      end
    end
    #Process.waitpid(pid)
    thr.join
    @stdout = File.read(File.join(working_dir, "stdout.txt"))
    @stderr = File.read(File.join(working_dir, "stderr.txt"))
  end
end