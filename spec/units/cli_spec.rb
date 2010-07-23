require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Cli do
  before do
    @stdout = StringIO.new
    @stderr = StringIO.new
    @cli = TimeTracker::Cli.new(@stdout, @stderr)
  end
  
  describe '.new' do
    it "allows stdout and stderr to be captured" do
      cli = TimeTracker::Cli.new(:stdout, :stderr)
      cli.stdout.must == :stdout
      cli.stderr.must == :stderr
    end
    it "defaults to the default stdout and stderr" do
      cli = TimeTracker::Cli.new
      cli.stdout.must == $stdout
      cli.stderr.must == $stderr
    end
  end
  
  describe '#puts' do
    it "delegates to @stdout" do
      @cli.puts("blah")
      @stdout.string.must == "blah\n"
    end
  end
  
  describe '#print' do
    it "delegates to @stdout" do
      @cli.print("blah")
      @stdout.string.must == "blah"
    end
  end
  
  describe '#start' do
    it "starts the clock for a task, creating it under the current project if it doesn't exist" do
      project = TimeTracker::Project.new(:name => "some project")
      stub(TimeTracker).current_project { project }
      @cli.start("some task")
      task = TimeTracker::Task.first
      task.project.must == project
      task.name.must == "some task"
    end
    it "bails if no project has been set yet"
    it "bails if no name given"
  end
  
end