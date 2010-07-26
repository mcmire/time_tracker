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
      stdout.must == %{Switched to project "some project".}
    end
    it "creates the given project if it doesn't already exist" do
      @cli.switch("some project")
      TimeTracker::Project.count.must == 1
      TimeTracker.config["current_project_id"].must_not be_nil
      stdout.must == %{Switched to project "some project".}
    end
    it "pauses any task that's running in the current project before switching to the given one" do
      project = TimeTracker::Project.create!(:name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      time1 = Time.utc(2010, 1, 1, 0, 0, 0)
      time2 = Time.utc(2010, 1, 1, 0, 1, 0)
      task = project.tasks.create!(:name => "some task", :created_at => time1)
      Timecop.freeze(time2) do
        @cli.switch("another project")
      end
      task.reload
      task.stopped_at.must == time2
      task.must be_paused
      stdout.must == %{(Pausing clock for "some task", at 1m.)\nSwitched to project "another project".}
    end
    it "resumes a task that had been paused in this project prior to switching to another one" do
      project1 = TimeTracker::Project.create!(:name => "some project")
      task = project1.tasks.create!(:name => "some task", :stopped_at => Time.now, :paused => true)
      project2 = TimeTracker::Project.create!(:name => "another project")
      TimeTracker.config.update("current_project_id", project2.id.to_s)
      @cli.switch("some project")
      task.reload
      task.stopped_at.must == nil
      task.must_not be_paused
      stdout.must == %{Switched to project "some project".\n(Resuming "some task".)}
    end
  end
  
  describe '#start' do
    it "bails if no project has been set yet" do
      expect { @cli.start("some task") }.to raise_error("Try switching to a project first.")
    end
    it "bails if no name given" do
      expect { @cli.start }.to raise_error("Right, but what's the name of your task?")
    end
    it "bails if there's already task under the current project that hasn't been stopped yet" do
      project = TimeTracker::Project.new(:name => "some project")
      project.tasks.create!(:name => "some task", :stopped_at => nil)
      TimeTracker.config.update("current_project_id", project.id.to_s)
      expect { @cli.start("some task") }.to raise_error("Aren't you already working on that task?")
    end
    it "starts the clock for a task, creating it under the current project first" do
      project = TimeTracker::Project.create!(:name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      Timecop.freeze(@time) do
        @cli.start("some task")
      end
      TimeTracker::Task.count.must == 1
      task = TimeTracker::Task.sort(:created_at.desc).first
      task.project.name.must == "some project"
      task.name.must == "some task"
      task.created_at.must == @time
      stdout.must == %{Started clock for "some task".}
    end
    it "pauses any task that's currently running before starting a new one" do
      project = TimeTracker::Project.create!(:name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      time1 = Time.utc(2010, 1, 1, 0, 0, 0)
      time2 = Time.utc(2010, 1, 1, 0, 1, 0)
      task1 = project.tasks.create!(:name => "some task", :created_at => time1)
      Timecop.freeze(time2) do
        @cli.start("another task")
      end
      TimeTracker::Task.count.must == 2
      task1.reload
      task1.stopped_at.must == time2
      task2 = TimeTracker::Task.sort(:created_at.desc).first
      task2.project.name.must == "some project"
      task2.name.must == "another task"
      task2.created_at.must == time2
      stdout.must == %{(Pausing clock for "some task", at 1m.)\nStarted clock for "another task".}
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
        task1 = project.tasks.create!(:name => "some task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        task2 = project.tasks.create!(:name => "another task", :created_at => Time.now, :stopped_at => Time.now)
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
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
        project.tasks.create!(:name => "some task", :created_at => Time.now, :stopped_at => Time.now)
        expect { @cli.stop }.to raise_error("It looks like all the tasks under this project are stopped.")
      end
      it "resumes the last task under this project that was paused" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = project.tasks.create!(:name => "some task", :stopped_at => Time.now, :paused => true)
        task2 = project.tasks.create!(:name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop
        end
        task1.reload
        task1.stopped_at.must == nil
        task1.must_not be_paused
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming "some task".)}
      end
    end
    context "given a string" do
      it "stops the given task by name" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = project.tasks.create!(:name => "some task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
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
      it "resumes the last task under this project that was paused" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = project.tasks.create!(:name => "some task", :stopped_at => Time.now, :paused => true)
        task2 = project.tasks.create!(:name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop("another task")
        end
        task1.reload
        task1.stopped_at.must == nil
        task1.must_not be_paused
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming "some task".)}
      end
    end
    context "given a number" do
      it "stops the given task by task number" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = project.tasks.create!(:name => "some task", :number => "1", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        task2 = project.tasks.create!(:name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 2, 0))
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
        project.tasks.create!(:name => "some task", :number => "1", :stopped_at => Time.now)
        expect { @cli.stop("1") }.to raise_error("I think you've stopped that task already.")
      end
      it "resumes the last task under this project that was paused" do
        project = TimeTracker::Project.create!(:name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = project.tasks.create!(:name => "some task", :number => "1", :stopped_at => Time.now, :paused => true)
        task2 = project.tasks.create!(:name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop("2")
        end
        task1.reload
        task1.stopped_at.must == nil
        task1.must_not be_paused
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming "some task".)}
      end
    end
  end
  
end