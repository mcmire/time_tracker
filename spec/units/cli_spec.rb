require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Cli do
  before do
    @stdout = StringIO.new
    @stderr = StringIO.new
    @cli = TimeTracker::Cli.build(@stdout, @stderr)
    @time = Time.utc(2010)
  end
  
  describe '.build' do
    it "allows stdout and stderr to be set" do
      cli = TimeTracker::Cli.build(:stdout, :stderr)
      cli.stdout.must == :stdout
      cli.stderr.must == :stderr
    end
  end
  
  describe '.new' do
    it "initializes stdout and stderr to the default stdout and stderr" do
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
  
  describe '#switch' do
    it "finds the given project and sets the current one to that" do
      project = TimeTracker::Project.create!(:name => "some project")
      @cli.switch("some project")
      TimeTracker::Project.count.must == 1
      TimeTracker.current_project.must == project
    end
    it "creates the given project if it doesn't already exist" do
      @cli.switch("some project")
      TimeTracker::Project.count.must == 1
      TimeTracker.current_project.name.must == "some project"
    end
  end
  
  #describe '#start' do
  #  it "starts the clock for a task, if it exists under the current project" do
  #    project = TimeTracker::Project.new(:name => "some project")
  #    stub(TimeTracker).current_project { project }
  #    project.tasks.create!(:name => "some task")
  #    Timecop.freeze(@time) do
  #      @cli.start("some task")
  #    end
  #    TimeTracker::Task.count.must == 1
  #    task = TimeTracker::Task.first
  #    task.started_at.must == @time
  #  end
  #  xit "creates a new task under the current project if it doesn't exist" do
  #    project = TimeTracker::Project.new(:name => "some project")
  #    stub(TimeTracker).current_project { project }
  #    Timecop.freeze(@time) do
  #      @cli.start("some task")
  #    end
  #    TimeTracker::Task.count.must == 1
  #    task = TimeTracker::Task.first
  #    task.project.name.must == "some project"
  #    task.name.must == "some task"
  #    task.started_at.must == @time
  #  end
  #  #it "bails if there's a task under the current project but it's already started" do
  #  #  project = TimeTracker::Project.new(:name => "some project")
  #  #  stub(TimeTracker).current_project { project }
  #  #  @cli.start("some task")
  #  #end
  #  it "bails if there's a task under the current project but it's already finished"
  #  it "bails if no project has been set yet"
  #  it "bails if no name given"
  #end
  
end