require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Cli do
  before do
    @stdout = StringIO.new
    @stderr = StringIO.new
    @cli = TimeTracker::Cli.build(@stdout, @stderr)
    @time = Time.utc(2010)
  end
  
  def stdout
    @stdout.string.strip
  end
  
  def stderr
    @stderr.string.strip
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
      stdout.must == %{Started clock for "some task".}
    end
    it "bails if no name given" do
      expect { @cli.start }.to raise_error("Right, but what's the name of your task?")
    end
    it "bails if no project has been set yet" do
      expect { @cli.start("some task") }.to raise_error("Try switching to a project first.")
    end
    it "bails if there's a task under the current project but it's already started" do
      project = TimeTracker::Project.new(:name => "some project")
      project.tasks.create!(:name => "some task", :started_at => Time.now)
      TimeTracker.config.update("current_project_id", project.id.to_s)
      expect { @cli.start("some task") }.to raise_error("Aren't you already working on that task?")
    end
  end
  
  describe '#stop' do
    it "bails if no project has been set yet" do
      expect { @cli.stop }.to raise_error("Try switching to a project first.")
    end
    it "bails if no tasks have been created under this project yet" do
      project = TimeTracker::Project.create!(:name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      expect { @cli.stop }.to raise_error("You haven't started a task under this project yet.")
    end
    context "with no argument" do
      it "stops the last running task" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = project.tasks.create!(:name => "some task", :started_at => Time.local(2010, 1, 1, 0, 0, 0))
        task2 = project.tasks.create!(:name => "another task", :started_at => Time.now, :stopped_at => Time.now)
        stopped_at = Time.local(2010, 1, 1, 3, 29)
        Timecop.freeze(stopped_at) do
          @cli.stop
        end
        task1.reload
        task1.stopped_at.must == stopped_at
        stdout.must == %{Stopped clock for "some task", at 3h:29m.}
      end
      it "bails if tasks are under this project but they're all stopped" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        project.tasks.create!(:name => "some task", :started_at => Time.now, :stopped_at => Time.now)
        expect { @cli.stop }.to raise_error("It looks like all the tasks under this project are stopped.")
      end
    end
    context "given a string" do
      it "stops the given task by name" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = project.tasks.create!(:name => "some task", :started_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29)
        Timecop.freeze(stopped_at) do
          @cli.stop("some task")
        end
        task1.reload
        task1.stopped_at.must == stopped_at
        stdout.must == %{Stopped clock for "some task", at 3h:29m.}
      end
      it "bails if a task can't be found by the given name" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        project.tasks.create!(:name => "another task")
        expect { @cli.stop("some task") }.to raise_error("It looks like that task doesn't exist.")
      end
      it "bails if a task can be found by that name but it's already been stopped" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        project.tasks.create!(:name => "some task", :stopped_at => Time.now)
        expect { @cli.stop("some task") }.to raise_error("I think you've stopped that task already.")
      end
    end
    context "given a number" do
      it "stops the given task by task number" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = project.tasks.create!(:name => "some task", :started_at => Time.local(2010, 1, 1, 0, 0, 0))
        task2 = project.tasks.create!(:name => "another task", :started_at => Time.local(2010, 1, 1, 0, 2, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29)
        Timecop.freeze(stopped_at) do
          @cli.stop("1")
        end
        task1.reload
        task1.stopped_at.must == stopped_at
        stdout.must == %{Stopped clock for "some task", at 3h:29m.}
      end
      it "bails if a task can't be found by the given task number" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        project.tasks.create!(:name => "another task")
        expect { @cli.stop("2") }.to raise_error("It looks like that task doesn't exist.")
      end
      it "bails if a task can be found by that number but it's already been stopped" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        project.tasks.create!(:name => "some task", :stopped_at => Time.now)
        expect { @cli.stop("1") }.to raise_error("I think you've stopped that task already.")
      end
    end
  end
  
end