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
      TimeTracker.config["current_project_id"].must == project.id
    end
    it "creates the given project if it doesn't already exist" do
      @cli.switch("some project")
      TimeTracker::Project.count.must == 1
      TimeTracker.config["current_project_id"].must_not be_nil
    end
  end
  
  describe '#start' do
    it "starts the clock for a task, creating it under the current project first" do
      project = TimeTracker::Project.create!(:name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      Timecop.freeze(@time) do
        @cli.start("some task")
      end
      TimeTracker::Task.count.must == 1
      task = TimeTracker::Task.first
      task.project.name.must == "some project"
      task.name.must == "some task"
      task.started_at.must == @time
    end
    it "bails if no name given" do
      expect { @cli.start }.to raise_error("Right, but what do you want to call the new task?")
    end
    it "bails if no project has been set yet" do
      expect { @cli.start("some task") }.to raise_error("Try switching to a project first.")
    end
    it "bails if there's a task under the current project but it's already started" do
      project = TimeTracker::Project.new(:name => "some project")
      project.tasks.create!(:name => "some task", :started_at => Time.now)
      TimeTracker.config.update("current_project_id", project.id.to_s)
      expect { @cli.start("some task") }.to raise_error("You're already working on that task.")
    end
    it "bails if there's a task under the current project but it's already finished"
  end
  
end