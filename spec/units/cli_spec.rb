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
      project = Factory(:project, :name => "some project")
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
    it "auto-pauses any task that's running in the current project before switching to the given one" do
      project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      time1 = Time.utc(2010, 1, 1, 0, 0, 0)
      time2 = Time.utc(2010, 1, 1, 0, 1, 0)
      task = Factory(:task, :project => project, :name => "some task", :created_at => time1)
      Timecop.freeze(time2) do
        @cli.switch("another project")
      end
      task.reload
      task.stopped_at.must == time2
      task.must be_paused
      stdout.must == %{(Pausing clock for "some task", at 1m.)\nSwitched to project "another project".}
    end
    it "auto-resumes a task that had been paused in this project prior to switching to another one" do
      project1 = Factory(:project, :name => "some project")
      task = Factory(:task, :project => project1, :name => "some task", :stopped_at => Time.now, :paused => true)
      project2 = Factory(:project, :name => "another project")
      TimeTracker.config.update("current_project_id", project2.id.to_s)
      @cli.switch("some project")
      task.reload
      task.stopped_at.must == nil
      task.must_not be_paused
      stdout.must == %{Switched to project "some project".\n(Resuming clock for "some task".)}
    end
  end
  
  describe '#start' do
    it "bails if no name given" do
      expect { @cli.start }.to raise_error("Right, but what's the name of your task?")
    end
    it "bails if no project has been set yet" do
      TimeTracker.config["current_project_id"]
      expect { @cli.start("some task") }.to raise_error("Try switching to a project first.")
    end
    it "bails if there's already task under the current project that hasn't been stopped yet" do
      project = TimeTracker::Project.new(:name => "some project")
      Factory(:task, :project => project, :name => "some task", :stopped_at => nil)
      TimeTracker.config.update("current_project_id", project.id.to_s)
      expect { @cli.start("some task") }.to raise_error("Aren't you already working on that task?")
    end
    it "starts the clock for a task, creating it under the current project first" do
      project = Factory(:project, :name => "some project")
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
    it "auto-pauses any task that's currently running before starting a new one" do
      project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      time1 = Time.utc(2010, 1, 1, 0, 0, 0)
      time2 = Time.utc(2010, 1, 1, 0, 1, 0)
      task1 = Factory(:task, :project => project, :name => "some task", :created_at => time1)
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
    context "with no argument" do
      it "bails if no project has been set yet" do
        expect { @cli.stop }.to raise_error("Try switching to a project first.")
      end
      it "bails if no tasks have been created under this project yet" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        expect { @cli.stop }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "stops the last running task in the current project" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        task2 = Factory(:task, :project => project, :name => "another task", :created_at => Time.now, :stopped_at => Time.now)
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop
        end
        task1.reload
        task1.stopped_at.must == stopped_at
        stdout.must == %{Stopped clock for "some task", at 3h:29m.}
      end
      it "bails if tasks are under this project but they're all stopped" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "some task", :created_at => Time.now, :stopped_at => Time.now)
        expect { @cli.stop }.to raise_error("It doesn't look like you're working on anything at the moment.")
      end
      it "auto-resumes the last task under this project that was paused" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :stopped_at => Time.now, :paused => true)
        task2 = Factory(:task, :project => project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop
        end
        task1.reload
        task1.stopped_at.must == nil
        task1.must_not be_paused
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming clock for "some task".)}
      end
    end
    context "given a string" do
      it "bails if no project has been set yet" do
        expect { @cli.stop("some task") }.to raise_error("Try switching to a project first.")
      end
      it "bails if no tasks have been created under this project yet" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        expect { @cli.stop("some task") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "stops the given task by name" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29)
        Timecop.freeze(stopped_at) do
          @cli.stop("some task")
        end
        task1.reload
        task1.stopped_at.must == stopped_at
        stdout.must == %{Stopped clock for "some task", at 3h:29m.}
      end
      it "bails if a task can't be found by the given name" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "another task")
        expect { @cli.stop("some task") }.to raise_error("I don't think that task exists.")
      end
      it "bails if a task can be found by that name but it's already been stopped" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "some task", :stopped_at => Time.now)
        expect { @cli.stop("some task") }.to raise_error("I think you've stopped that task already.")
      end
      it "auto-resumes the last task under this project that was paused" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :stopped_at => Time.now, :paused => true)
        task2 = Factory(:task, :project => project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop("another task")
        end
        task1.reload
        task1.stopped_at.must == nil
        task1.must_not be_paused
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming clock for "some task".)}
      end
    end
    context "given a number" do
      it "bails if no project has been set yet" do
        expect { @cli.stop("1") }.to raise_error("Try switching to a project first.")
      end
      it "bails if no tasks have been created under this project yet" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        expect { @cli.stop("1") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "stops the given task by task number" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        task2 = Factory(:task, :project => project, :name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 2, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29)
        Timecop.freeze(stopped_at) do
          @cli.stop("1")
        end
        task1.reload
        task1.stopped_at.must == stopped_at
        stdout.must == %{Stopped clock for "some task", at 3h:29m.}
      end
      it "bails if a task can't be found by the given task number" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "another task")
        expect { @cli.stop("2") }.to raise_error("I don't think that task exists.")
      end
      it "bails if a task can be found by that number but it's already been stopped" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "some task", :number => "1", :stopped_at => Time.now)
        expect { @cli.stop("1") }.to raise_error("I think you've stopped that task already.")
      end
      it "auto-resumes the last task under this project that was paused" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1", :stopped_at => Time.now, :paused => true)
        task2 = Factory(:task, :project => project, :name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop("2")
        end
        task1.reload
        task1.stopped_at.must == nil
        task1.must_not be_paused
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming clock for "some task".)}
      end
    end
  end
  
  describe '#resume' do
    # XXX: Should we really allow this?
    context "with no argument" do
      it "bails if no tasks exist in this project" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        expect { @cli.resume }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "bails if all tasks in this project are running" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task = Factory(:task, :project => project, :name => "some task")
        expect { @cli.resume }.to raise_error("Aren't you still working on something?")
      end
      it "resumes the last stopped task in the current project" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task = Factory(:task, :project => project, :name => "some task", :stopped_at => Time.now)
        @cli.resume
        task.reload
        task.stopped_at.must == nil
        stdout.must == %{Resumed clock for "some task".}
      end
      it "auto-pauses any task that's already running before resuming the last stopped task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :stopped_at => Time.now)
        task2 = Factory(:task, :project => project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.resume
        end
        task2.reload
        task2.stopped_at.must == stopped_at
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".}
      end
    end
    context "given a string" do
      it "bails if no tasks exist at all" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        expect { @cli.resume("some task") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "resumes the given task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :stopped_at => Time.local(2010, 1, 1, 0, 0, 0))
        @cli.resume("some task")
        task1.reload
        task1.stopped_at.must == nil
        stdout.must == %{Resumed clock for "some task".}
      end
      it "bails if the given task can't be found in this project" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "some task")
        expect { @cli.resume("another task") }.to raise_error("I don't think that task exists.")
      end
      it "bails if a task can be found by that name but it's in other projects" do
        project1 = Factory(:project, :name => "some project")
        Factory(:task, :project => project1, :name => "some task", :stopped_at => Time.now)
        project2 = Factory(:project, :name => "another project")
        Factory(:task, :project => project2, :name => "some task", :stopped_at => Time.now)
        project3 = Factory(:project, :name => "a different project")
        TimeTracker.config.update("current_project_id", project3.id.to_s)
        expect { @cli.resume("some task") }.to raise_error(%{That task doesn't exist here. Perhaps you meant to switch to "some project" or "another project"?})
      end
      it "bails if the given task is already running" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task")
        expect { @cli.resume("some task") }.to raise_error("Yes, you're still working on that task.")
      end
      it "auto-pauses any task that's already running before resuming the given task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :stopped_at => Time.now)
        task2 = Factory(:task, :project => project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.resume("some task")
        end
        task2.reload
        task2.stopped_at.must == stopped_at
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".}
      end
    end
    context "given a number" do
      it "bails if no tasks exist at all" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        expect { @cli.resume("1") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "resumes the given task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1", :stopped_at => Time.local(2010, 1, 1, 0, 0, 0))
        @cli.resume("1")
        task1.reload
        task1.stopped_at.must == nil
        stdout.must == %{Resumed clock for "some task".}
      end
      it "bails if the given task can't be found" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "some task")
        expect { @cli.resume("2") }.to raise_error("I don't think that task exists.")
      end
      it "bails if the given task is already running" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1")
        expect { @cli.resume("1") }.to raise_error("Yes, you're still working on that task.")
      end
      it "auto-switches to another project if given task is present there" do
        project1 = Factory(:project, :name => "some project")
        task = Factory(:task, :project => project1, :name => "some task", :number => "1", :stopped_at => Time.now)
        project2 = Factory(:project, :name => "another project")
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        @cli.resume("1")
        TimeTracker.config["current_project_id"].must == project1.id.to_s
        stdout.must == %{(Switching to project "some project".)\nResumed clock for "some task".}
      end
      it "auto-pauses any task that's already running before auto-switching to another project" do
        project1 = Factory(:project, :name => "some project")
        task1 = Factory(:task, :project => project1, :name => "some task", :number => "1", :stopped_at => Time.now)
        project2 = Factory(:project, :name => "another project")
        task2 = Factory(:task, :project => project2, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.resume("1")
        end
        task2.reload
        task2.stopped_at.must == stopped_at
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\n(Switching to project "some project".)\nResumed clock for "some task".}
      end
      it "auto-pauses any task that's already running before resuming the given task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1", :stopped_at => Time.now)
        task2 = Factory(:task, :project => project, :name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.resume("1")
        end
        task2.reload
        task2.stopped_at.must == stopped_at
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".}
      end
    end
  end
  
  describe '#list' do
    context "lastfew subcommand", :shared => true do
      it "prints a list of the last 5 tasks, ordered by last updated time" do
        project1 = Factory(:project, :name => "some project")
        project2 = Factory(:project, :name => "another project")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "some task",
          :created_at => Time.local(2010),
          :stopped_at => Time.local(2010, 1, 1, 0, 29, 0),
          :paused => true,
          :updated_at => Time.local(2010, 1, 2)
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project2, 
          :name => "another task", 
          :created_at => Time.local(2010), 
          :stopped_at => Time.local(2010, 1, 1, 0, 32, 0), 
          :paused => true, 
          :updated_at => Time.local(2010, 1, 1)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project1, 
          :name => "yet another task", 
          :updated_at => Time.local(2010, 1, 3)
        )
        @cli.list(*@args)
        stdout.must == <<-EOT.strip
Last 5 tasks:
#3. yet another task [some project] <==
#1. some task [some project] (paused at 29m)
#2. another task [another project] (paused at 32m)
        EOT
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list(*@args)
        stdout.must == "It doesn't look like you've started any tasks yet."
      end
    end
    context "lastfew" do
      before do
        @args = ["lastfew"]
      end
      it_should_behave_like "lastfew subcommand"
    end
    context "implied lastfew" do
      before do
        @args = []
      end
      it_should_behave_like "lastfew subcommand"
    end
    context "completed" do
      it "prints a list of all the stopped tasks, ordered by last updated time" do
        project1 = Factory(:project, :name => "some project")
        project2 = Factory(:project, :name => "another project")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "some task",
          :created_at => Time.local(2010),
          :stopped_at => Time.local(2010, 1, 1, 0, 32, 0),
          :updated_at => Time.local(2010, 1, 1, 3)
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project2, 
          :name => "another task", 
          :created_at => Time.local(2010), 
          :stopped_at => Time.local(2010, 1, 1, 0, 29, 0),
          :updated_at => Time.local(2010, 1, 1, 4)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project1, 
          :name => "yet another task", 
          :updated_at => Time.local(2010, 1, 3)
        )
        @cli.list("completed")
        stdout.must == <<-EOT.strip
Completed tasks:
#2. another task [another project] (stopped at 29m)
#1. some task [some project] (stopped at 32m)
        EOT
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list("completed")
        stdout.must == "It doesn't look like you've started any tasks yet."
      end
    end
    context "all" do
      it "prints a list of all tasks, ordered by last updated time" do
        project1 = Factory(:project, :name => "project 1")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "task 1",
          :created_at => Time.local(2010),
          :stopped_at => Time.local(2010, 1, 1, 0, 32, 0),
          :updated_at => Time.local(2010, 1, 1, 3),
          :paused => true
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project1, 
          :name => "task 2", 
          :created_at => Time.local(2010), 
          :stopped_at => Time.local(2010, 1, 1, 0, 29, 0),
          :updated_at => Time.local(2010, 1, 1, 1)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project1, 
          :name => "task 3", 
          :updated_at => Time.local(2010, 1, 1, 4)
        )
        project2 = Factory(:project, :name => "project 2")
        task4 = Factory(:task,
          :number => "4",
          :project => project2,
          :name => "task 4",
          :created_at => Time.local(2010),
          :stopped_at => Time.local(2010, 1, 1, 3, 0, 0),
          :updated_at => Time.local(2010, 1, 1, 10),
          :paused => true
        )
        task5 = Factory(:task,
          :number => "5",
          :project => project2, 
          :name => "task 5", 
          :created_at => Time.local(2010), 
          :stopped_at => Time.local(2010, 1, 1, 18, 0, 0),
          :updated_at => Time.local(2010, 1, 1, 8)
        )
        @cli.list("all")
        stdout.must == <<-EOT.strip
All tasks:
#4. task 4 [project 2] (paused at 3h)
#5. task 5 [project 2] (stopped at 18h)
#3. task 3 [project 1] <==
#1. task 1 [project 1] (paused at 32m)
#2. task 2 [project 1] (stopped at 29m)
        EOT
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list("all")
        stdout.must == "It doesn't look like you've started any tasks yet."
      end
    end
    context "today" do
      it "prints a list of tasks updated today, ordered by last updated time" do
        Timecop.freeze(2010, 1, 2)
        project1 = Factory(:project, :name => "project 1")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "task 1",
          :created_at => Time.local(2010),
          :stopped_at => Time.local(2010, 1, 1, 0, 32, 0),
          :updated_at => Time.local(2010, 1, 2, 3),
          :paused => true
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project1, 
          :name => "task 2", 
          :created_at => Time.local(2010), 
          :stopped_at => Time.local(2010, 1, 1, 0, 29, 0),
          :updated_at => Time.local(2010, 1, 1, 1)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project1, 
          :name => "task 3", 
          :updated_at => Time.local(2010, 1, 2, 4)
        )
        project2 = Factory(:project, :name => "project 2")
        task4 = Factory(:task,
          :number => "4",
          :project => project2,
          :name => "task 4",
          :created_at => Time.local(2010),
          :stopped_at => Time.local(2010, 1, 1, 3, 0, 0),
          :updated_at => Time.local(2010, 1, 1, 10),
          :paused => true
        )
        task5 = Factory(:task,
          :number => "5",
          :project => project2, 
          :name => "task 5", 
          :created_at => Time.local(2010), 
          :stopped_at => Time.local(2010, 1, 1, 18, 0, 0),
          :updated_at => Time.local(2010, 1, 1, 8)
        )
        @cli.list("today")
        stdout.must == <<-EOT.strip
Today's tasks:
#3. task 3 [project 1] <==
#1. task 1 [project 1] (paused at 32m)
        EOT
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list("today")
        stdout.must == "It doesn't look like you've started any tasks yet."
      end
    end
    context "this week" do
      it "prints a list of tasks updated this week, ordered by last updated time" do
        Timecop.freeze(2010, 7, 30)
        project1 = Factory(:project, :name => "project 1")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "task 1",
          :created_at => Time.local(2010),
          :stopped_at => Time.local(2010, 1, 1, 0, 32, 0),
          :updated_at => Time.local(2010, 7, 29, 3),
          :paused => true
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project1, 
          :name => "task 2", 
          :created_at => Time.local(2010), 
          :stopped_at => Time.local(2010, 1, 1, 0, 29, 0),
          :updated_at => Time.local(2010, 7, 20, 1)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project1, 
          :name => "task 3", 
          :updated_at => Time.local(2010, 7, 31, 4)
        )
        project2 = Factory(:project, :name => "project 2")
        task4 = Factory(:task,
          :number => "4",
          :project => project2,
          :name => "task 4",
          :created_at => Time.local(2010),
          :stopped_at => Time.local(2010, 1, 1, 3, 0, 0),
          :updated_at => Time.local(2010, 7, 24, 10),
          :paused => true
        )
        task5 = Factory(:task,
          :number => "5",
          :project => project2, 
          :name => "task 5", 
          :created_at => Time.local(2010), 
          :stopped_at => Time.local(2010, 1, 1, 18, 0, 0),
          :updated_at => Time.local(2010, 7, 26, 8)
        )
        @cli.list("this week")
        stdout.must == <<-EOT.strip
This week's tasks:
#3. task 3 [project 1] <==
#1. task 1 [project 1] (paused at 32m)
#5. task 5 [project 2] (stopped at 18h)
        EOT
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list("this week")
        stdout.must == "It doesn't look like you've started any tasks yet."
      end
    end
    context "unknown command" do
      it "fails with an ArgumentError" do
        expect { @cli.list("yourmom") }.to raise_error(ArgumentError)
      end
    end
  end
  
end