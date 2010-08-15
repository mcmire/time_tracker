require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Cli do
  before do
    @stdin, @stdout, @stderr = Array.new(3) { StringIO.new }
    @cli = TimeTracker::Cli.build(@stdin, @stdout, @stderr)
    @time = Time.zone.local(2010)
  end
  
  def stdout
    @stdout.string#.strip
  end
  
  def stderr
    @stderr.string#.strip
  end
  
  describe '.build' do
    it "allows stdout and stderr to be set" do
      cli = TimeTracker::Cli.build(:stdin, :stdout, :stderr)
      cli.stdin.must  == :stdin
      cli.stdout.must == :stdout
      cli.stderr.must == :stderr
    end
  end
  
  describe '.new' do
    it "initializes stdout and stderr to the default stdout and stderr" do
      cli = TimeTracker::Cli.new
      cli.stdin.must  == $stdin
      cli.stdout.must == $stdout
      cli.stderr.must == $stderr
    end
  end
  
  describe '#switch' do
    it "finds the given project and sets the current one to that" do
      project = Factory(:project, :name => "some project")
      @cli.switch("some project")
      TimeTracker::Project.count.must == 1
      TimeTracker.config["current_project_id"].must == project.id
      stdout.must == %{Switched to project "some project".\n}
    end
    it "creates the given project if it doesn't already exist" do
      @cli.switch("some project")
      TimeTracker::Project.count.must == 1
      TimeTracker.config["current_project_id"].must_not be_nil
      stdout.must == %{Switched to project "some project".\n}
    end
    it "auto-pauses any task that's running in the current project before switching to the given one" do
      project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      time1 = Time.zone.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.zone.local(2010, 1, 1, 0, 1, 0)
      task = Factory(:task, :project => project, :name => "some task", :created_at => time1)
      Timecop.freeze(time2) do
        @cli.switch("another project")
      end
      task.time_periods.first.ended_at.must == time2
      task.must be_paused
      stdout.must == %{(Pausing clock for "some task", at 1m.)\nSwitched to project "another project".\n}
    end
    it "auto-resumes a task that had been paused in this project prior to switching to another one" do
      project1 = Factory(:project, :name => "some project")
      task = Factory(:task, :project => project1, :name => "some task", :state => "paused")
      project2 = Factory(:project, :name => "another project")
      TimeTracker.config.update("current_project_id", project2.id.to_s)
      @cli.switch("some project")
      task.reload
      task.must be_running
      stdout.must == %{Switched to project "some project".\n(Resuming clock for "some task".)\n}
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
      Factory(:task, :project => project, :name => "some task")
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
      stdout.must == %{Started clock for "some task".\n}
    end
    it "auto-pauses any task that's currently running before starting a new one" do
      project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      time1 = Time.zone.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.zone.local(2010, 1, 1, 0, 1, 0)
      task1 = Factory(:task, :project => project, :name => "some task", :created_at => time1)
      Timecop.freeze(time2) do
        @cli.start("another task")
      end
      TimeTracker::Task.count.must == 2
      task1.time_periods.first.ended_at.must == time2
      task1.must be_paused
      task2 = TimeTracker::Task.sort(:created_at.desc).first
      task2.project.name.must == "some project"
      task2.name.must == "another task"
      task2.created_at.must == time2
      stdout.must == %{(Pausing clock for "some task", at 1m.)\nStarted clock for "another task".\n}
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
      it "stops the currently running task in the current project, creating a time period" do
        started_at = Time.local(2010, 1, 1, 0, 0, 0)
        ended_at = Time.local(2010, 1, 1, 3, 29, 0)
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :created_at => started_at)
        task2 = Factory(:task, :project => project, :name => "another task", :state => "stopped")
        Timecop.freeze(ended_at) do
          @cli.stop
        end
        task1.reload
        task1.must be_stopped
        time_period = task1.time_periods.first
        time_period.started_at.must == started_at
        time_period.ended_at.must == ended_at
        stdout.must == %{Stopped clock for "some task", at 3h:29m.\n}
      end
      it "bails if tasks are under this project but they're all stopped" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "some task", :created_at => Time.now, :state => "stopped")
        expect { @cli.stop }.to raise_error("It doesn't look like you're working on anything at the moment.")
      end
      it "auto-resumes the last task under this project that was paused" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :state => "paused", :updated_at => Time.local(2010, 1, 1, 1, 0, 0))
        task2 = Factory(:task, :project => project, :name => "another task", :state => "paused", :updated_at => Time.local(2010, 1, 1, 2, 0, 0))
        task3 = Factory(:task, :project => project, :name => "yet another task", :created_at => Time.local(2010, 1, 1, 3, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop
        end
        task1.reload
        task1.must be_paused
        task2.reload
        task2.must be_running
        stdout.must == %{Stopped clock for "yet another task", at 29m.\n(Resuming clock for "another task".)\n}
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
        task1.must be_stopped
        stdout.must == %{Stopped clock for "some task", at 3h:29m.\n}
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
        Factory(:task, :project => project, :name => "some task", :state => "stopped")
        expect { @cli.stop("some task") }.to raise_error("I think you've stopped that task already.")
      end
      it "auto-resumes the last task under this project that was paused" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :state => "paused")
        task2 = Factory(:task, :project => project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop("another task")
        end
        task1.reload
        task1.must be_running
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming clock for "some task".)\n}
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
        task1.must be_stopped
        stdout.must == %{Stopped clock for "some task", at 3h:29m.\n}
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
        Factory(:task, :project => project, :name => "some task", :number => "1", :state => "stopped")
        expect { @cli.stop("1") }.to raise_error("I think you've stopped that task already.")
      end
      it "auto-resumes the last task under this project that was paused" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1", :state => "paused")
        task2 = Factory(:task, :project => project, :name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.stop("2")
        end
        task1.reload
        task1.must be_running
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming clock for "some task".)\n}
      end
    end
  end
  
  describe '#resume' do
    it "bails if no name given" do
      project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      task1 = Factory(:task, :project => project, :name => "some task", :state => "paused")
      expect { @cli.resume }.to raise_error("Yes, but which task do you want to resume? (I'll accept a number or a name.)")
    end
    context "given a string" do
      it "bails if no tasks exist at all" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        expect { @cli.resume("some task") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "resumes the given paused task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :state => "paused")
        @cli.resume("some task")
        task1.reload
        task1.must be_running
        stdout.must == %{Resumed clock for "some task".\n}
      end
      it "resumes the given stopped task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :state => "stopped")
        @cli.resume("some task")
        task1.reload
        task1.must be_running
        stdout.must == %{Resumed clock for "some task".\n}
      end
      it "bails if the given task can't be found in this project" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "some task")
        expect { @cli.resume("another task") }.to raise_error("I don't think that task exists.")
      end
      it "bails if a paused task can be found by that name but it's in other projects" do
        project1 = Factory(:project, :name => "some project")
        Factory(:task, :project => project1, :name => "some task", :state => "paused")
        project2 = Factory(:project, :name => "another project")
        Factory(:task, :project => project2, :name => "some task", :state => "paused")
        project3 = Factory(:project, :name => "a different project")
        TimeTracker.config.update("current_project_id", project3.id.to_s)
        expect { @cli.resume("some task") }.to raise_error(%{That task doesn't exist here. Perhaps you meant to switch to "some project" or "another project"?})
      end
      it "bails if a stopped task can be found by that name but it's in other projects" do
        project1 = Factory(:project, :name => "some project")
        Factory(:task, :project => project1, :name => "some task", :state => "stopped")
        project2 = Factory(:project, :name => "another project")
        Factory(:task, :project => project2, :name => "some task", :state => "stopped")
        project3 = Factory(:project, :name => "a different project")
        TimeTracker.config.update("current_project_id", project3.id.to_s)
        expect { @cli.resume("some task") }.to raise_error(%{That task doesn't exist here. Perhaps you meant to switch to "some project" or "another project"?})
      end
      it "bails if the given task can be found, but it's already running" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :state => "running")
        expect { @cli.resume("some task") }.to raise_error("Aren't you working on that task already?")
      end
      it "auto-pauses any task that's already running before resuming the given paused task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :state => "paused")
        task2 = Factory(:task, :project => project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        paused_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(paused_at) do
          @cli.resume("some task")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before resuming the given stopped task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :state => "stopped")
        task2 = Factory(:task, :project => project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        paused_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(paused_at) do
          @cli.resume("some task")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".\n}
      end
    end
    context "given a number" do
      it "bails if no tasks exist at all" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        expect { @cli.resume("1") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "resumes the given paused task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1", :state => "paused")
        @cli.resume("1")
        task1.reload
        task1.must be_running
        stdout.must == %{Resumed clock for "some task".\n}
      end
      it "resumes the given stopped task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1", :state => "stopped")
        @cli.resume("1")
        task1.reload
        task1.must be_running
        stdout.must == %{Resumed clock for "some task".\n}
      end
      it "bails if the given task can't be found" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        Factory(:task, :project => project, :name => "some task")
        expect { @cli.resume("2") }.to raise_error("I don't think that task exists.")
      end
      it "bails if the given task can be found, but it's already running" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1")
        expect { @cli.resume("1") }.to raise_error("Aren't you working on that task already?")
      end
      it "auto-switches to another project if given paused task is present there" do
        project1 = Factory(:project, :name => "some project")
        task = Factory(:task, :project => project1, :name => "some task", :number => "1", :state => "paused")
        project2 = Factory(:project, :name => "another project")
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        @cli.resume("1")
        TimeTracker.config["current_project_id"].must == project1.id.to_s
        stdout.must == %{(Switching to project "some project".)\nResumed clock for "some task".\n}
      end
      it "auto-switches to another project if given stopped task is present there" do
        project1 = Factory(:project, :name => "some project")
        task = Factory(:task, :project => project1, :name => "some task", :number => "1", :state => "stopped")
        project2 = Factory(:project, :name => "another project")
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        @cli.resume("1")
        TimeTracker.config["current_project_id"].must == project1.id.to_s
        stdout.must == %{(Switching to project "some project".)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before auto-switching to another project where paused task is present" do
        project1 = Factory(:project, :name => "some project")
        task1 = Factory(:task, :project => project1, :name => "some task", :number => "1", :state => "paused")
        project2 = Factory(:project, :name => "another project")
        task2 = Factory(:task, :project => project2, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.resume("1")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\n(Switching to project "some project".)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before auto-switching to another project where stopped task is present" do
        project1 = Factory(:project, :name => "some project")
        task1 = Factory(:task, :project => project1, :name => "some task", :number => "1", :state => "stopped")
        project2 = Factory(:project, :name => "another project")
        task2 = Factory(:task, :project => project2, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.resume("1")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\n(Switching to project "some project".)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before resuming the given paused task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1", :state => "paused")
        task2 = Factory(:task, :project => project, :name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.resume("1")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before resuming the given stopped task" do
        project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", project.id.to_s)
        task1 = Factory(:task, :project => project, :name => "some task", :number => "1", :state => "stopped")
        task2 = Factory(:task, :project => project, :name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 0, 0))
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.resume("1")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".\n}
      end
    end
  end
  
  describe '#list' do
    context "lastfew subcommand", :shared => true do
      it "prints a list of the last 4 time periods plus the currently running task, ordered by last active" do
        Timecop.freeze Time.zone.local(2010, 1, 3)
        project1 = Factory(:project, :name => "some project")
        project2 = Factory(:project, :name => "another project")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "some task",
          :state => "stopped"
        )
        period1 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 1, 0, 0),
          :ended_at   => Time.zone.local(2010, 1, 2, 5, 5)
        )
        period3 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 3, 10, 10),
          :ended_at   => Time.zone.local(2010, 1, 3, 15, 15)
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project2, 
          :name => "another task", 
          :state => "stopped"
        )
        period2 = Factory(:time_period,
          :task => task2,
          :started_at => Time.zone.local(2010, 1, 2, 5, 5),
          :ended_at   => Time.zone.local(2010, 1, 3, 10, 10)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project1, 
          :name => "yet another task", 
          :state => "running",
          :last_started_at => Time.zone.local(2010, 1, 3, 15, 15)
        )
        @cli.list(*@args)
        stdout.lines.must smart_match([
          "",
          "Latest tasks:",
          "",
          "    Today,  3:15pm -                    [#3] some project / yet another task (*)",
          "    Today, 10:10am -     Today,  3:15pm [#1] some project / some task",
          "Yesterday,  5:05am -     Today, 10:10am [#2] another project / another task",
          " 1/1/2010, 12:00am - Yesterday,  5:05am [#1] some project / some task",
          ""
        ])
      end
      it "prints a list of the last 5 time periods if no task is running" do
        Timecop.freeze Time.zone.local(2010, 1, 3)
        project1 = Factory(:project, :name => "some project")
        project2 = Factory(:project, :name => "another project")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "some task",
          :state => "stopped"
        )
        period1 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 1, 0, 0),
          :ended_at   => Time.zone.local(2010, 1, 2, 5, 5)
        )
        period3 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 3, 10, 10),
          :ended_at   => Time.zone.local(2010, 1, 3, 15, 15)
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project2, 
          :name => "another task", 
          :state => "stopped"
        )
        period2 = Factory(:time_period,
          :task => task2,
          :started_at => Time.zone.local(2010, 1, 2, 5, 5),
          :ended_at   => Time.zone.local(2010, 1, 3, 10, 10)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project1, 
          :name => "yet another task", 
          :state => "paused"
        )
        period3 = Factory(:time_period,
          :task => task3,
          :started_at => Time.zone.local(2010, 1, 3, 15, 15),
          :ended_at   => Time.zone.local(2010, 1, 3, 20, 20)
        )
        @cli.list(*@args)
        stdout.lines.must smart_match([
          "",
          "Latest tasks:",
          "",
          "    Today,  3:15pm -     Today,  8:20pm [#3] some project / yet another task",
          "    Today, 10:10am -     Today,  3:15pm [#1] some project / some task",
          "Yesterday,  5:05am -     Today, 10:10am [#2] another project / another task",
          " 1/1/2010, 12:00am - Yesterday,  5:05am [#1] some project / some task",
          ""
        ])
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list(*@args)
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
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
      it "prints a list of all ended time periods, grouped by day, ordered by ended time" do
        Timecop.freeze Time.zone.local(2010, 1, 3)
        project1 = Factory(:project, :name => "some project")
        project2 = Factory(:project, :name => "another project")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "some task",
          :state => "paused"
        )
        period1 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 1, 0, 0),
          :ended_at   => Time.zone.local(2010, 1, 2, 5, 5)
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project2, 
          :name => "another task", 
          :state => "stopped"
        )
        period2 = Factory(:time_period,
          :task => task2,
          :started_at => Time.zone.local(2010, 1, 2, 5, 5),
          :ended_at   => Time.zone.local(2010, 1, 3, 10, 10)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project2, 
          :name => "yet another task", 
          :state => "running"
        )
        @cli.list("completed")
        stdout.lines.must smart_match([
          "",
          "Completed tasks:",
          "",
          "Today:",
          "  (12:00am) -  10:10am  [#2] another project / another task",
          "",
          "Yesterday:",
          "    5:05am  - (11:59pm) [#2] another project / another task",
          "  (12:00am) -   5:05am  [#1] some project / some task",
          "",
          "1/1/2010:",
          "   12:00am  - (11:59pm) [#1] some project / some task",
          ""
        ])
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list("completed")
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
      end
    end
    context "all" do
      it "prints a list of all tasks, ordered by last updated time" do
        Timecop.freeze(2010, 1, 5)
        project1 = Factory(:project, :name => "some project")
        project2 = Factory(:project, :name => "another project")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "some task",
          :state => "paused"
        )
        period1 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 1, 0, 0),
          :ended_at   => Time.zone.local(2010, 1, 2, 5, 5)
        )
        period2 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 3, 10, 10),
          :ended_at   => Time.zone.local(2010, 1, 3, 15, 15)
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project2, 
          :name => "another task", 
          :state => "stopped"
        )
        period3 = Factory(:time_period,
          :task => task2,
          :started_at => Time.zone.local(2010, 1, 2, 5, 5),
          :ended_at   => Time.zone.local(2010, 1, 3, 10, 10)
        )
        period4 = Factory(:time_period,
          :task => task2,
          :started_at => Time.zone.local(2010, 1, 5, 1, 1),
          :ended_at   => Time.zone.local(2010, 1, 5, 6, 6)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project1, 
          :name => "yet another task",
          :state => "paused"
        )
        period5 = Factory(:time_period,
          :task => task3,
          :started_at => Time.zone.local(2010, 1, 3, 15, 15),
          :ended_at   => Time.zone.local(2010, 1, 4, 20, 20)
        )
        task4 = Factory(:task,
          :number => "4",
          :project => project1,
          :name => "even yet another task",
          :state => "stopped"
        )
        period6 = Factory(:time_period,
          :task => task4,
          :started_at => Time.zone.local(2010, 1, 4, 20, 20),
          :ended_at   => Time.zone.local(2010, 1, 5, 1, 1)
        )
        task5 = Factory(:task,
          :number => "5",
          :project => project2, 
          :name => "still yet another task", 
          :state => "running",
          :last_started_at => Time.zone.local(2010, 1, 5, 6, 6)
        )
        @cli.list("all")
        stdout.lines.must smart_match([
          "",
          "All tasks:",
          "",
          "Today:",
          "    6:06am  -           [#5] another project / still yet another task (*)",
          "    1:01am  -   6:06am  [#2] another project / another task",
          "  (12:00am) -   1:01am  [#4] some project / even yet another task",
          "",
          "Yesterday:",
          "    8:20pm  - (11:59pm) [#4] some project / even yet another task",
          "  (12:00am) -   8:20pm  [#3] some project / yet another task",
          "",
          "1/3/2010:",
          "    3:15pm  - (11:59pm) [#3] some project / yet another task",
          "   10:10am  -   3:15pm  [#1] some project / some task",
          "  (12:00am) -  10:10am  [#2] another project / another task",
          "",
          "1/2/2010:",
          "    5:05am  - (11:59pm) [#2] another project / another task",
          "  (12:00am) -   5:05am  [#1] some project / some task",
          "",
          "1/1/2010:",
          "   12:00am  - (11:59pm) [#1] some project / some task",
          ""
        ])
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list("all")
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
      end
    end
    context "today" do
      it "prints a list of time periods that ended today, ordered by ended_at" do
        Timecop.freeze Time.zone.local(2010, 1, 2)
        project1 = Factory(:project, :name => "some project")
        project2 = Factory(:project, :name => "another project")
        task1 = Factory(:task,
          :number => "1",
          :project => project1, 
          :name => "some task",
          :state => "stopped"
        )
        period1 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 1, 0, 0),
          :ended_at   => Time.zone.local(2010, 1, 1, 5, 5)
        )
        period2 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 2, 3, 3),
          :ended_at   => Time.zone.local(2010, 1, 2, 8, 8)
        )
        period3 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 1, 2, 13, 13),
          :ended_at   => Time.zone.local(2010, 1, 2, 18, 18)
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project1,
          :name => "another task",
          :state => "paused"
        )
        period4 = Factory(:time_period,
          :task => task2,
          :started_at => Time.zone.local(2010, 1, 1, 5, 5),
          :ended_at   => Time.zone.local(2010, 1, 2, 3, 3)
        )
        task2 = Factory(:task,
          :number => "3",
          :project => project2, 
          :name => "yet another task",
          :state => "stopped"
        )
        period5 = Factory(:time_period,
          :task => task2,
          :started_at => Time.zone.local(2010, 1, 2, 8, 8),
          :ended_at   => Time.zone.local(2010, 1, 2, 13, 13)
        )
        @cli.list("today")
        stdout.lines.must smart_match([
          "",
          "Today's tasks:",
          "",
          "  1:13pm  - 6:18pm [#1] some project / some task",
          "  8:08am  - 1:13pm [#3] another project / yet another task",
          "  3:03am  - 8:08am [#1] some project / some task",
          "(12:00am) - 3:03am [#2] some project / another task",
          ""
        ])
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list("today")
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
      end
    end
    context "this week" do
      it "prints a list of tasks updated this week, ordered by last updated time" do
        Timecop.freeze Time.zone.local(2010, 8, 5)
        project1 = Factory(:project, :name => "some project")
        project2 = Factory(:project, :name => "another project")
        task1 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "some task",
          :state => "stopped"
        )
        period1 = Factory(:time_period,
          :task => task1,
          :started_at => Time.zone.local(2010, 8, 1, 0, 0),
          :ended_at   => Time.zone.local(2010, 8, 2, 5, 5)
        )
        task2 = Factory(:task,
          :number => "2",
          :project => project1, 
          :name => "another task", 
          :state => "stopped"
        )
        period2 = Factory(:time_period,
          :task => task2,
          :started_at => Time.zone.local(2010, 8, 2, 5, 5),
          :ended_at   => Time.zone.local(2010, 8, 3, 15, 15)
        )
        task3 = Factory(:task, 
          :number => "3", 
          :project => project2, 
          :name => "yet another task", 
          :state => "paused"
        )
        period3 = Factory(:time_period,
          :task => task3,
          :started_at => Time.zone.local(2010, 8, 3, 15, 15),
          :ended_at   => Time.zone.local(2010, 8, 5, 3, 3)
        )
        task4 = Factory(:task,
          :number => "4",
          :project => project2,
          :name => "even yet another task",
          :state => "running",
          :last_started_at => Time.zone.local(2010, 8, 5, 3, 3)
        )
        @cli.list("this week")
        stdout.lines.must smart_match([
          "",
          "This week's tasks:",
          "",
          "8/1/2010:",
          "   12:00am  - (11:59pm) [#1] some project / some task",
          "",
          "8/2/2010:",
          "  (12:00am) -   5:05am  [#1] some project / some task",
          "    5:05am  - (11:59pm) [#2] some project / another task",
          "",
          "8/3/2010:",
          "  (12:00am) -   3:15pm  [#2] some project / another task",
          "    3:15pm  - (11:59pm) [#3] another project / yet another task",
          "",
          "Yesterday:",
          "  (12:00am) - (11:59pm) [#3] another project / yet another task",
          "",
          "Today:",
          "  (12:00am) -   3:03am  [#3] another project / yet another task",
          "    3:03am  -           [#4] another project / even yet another task (*)",
          ""
        ])
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.list("this week")
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
      end
    end
    context "unknown command" do
      it "fails with an ArgumentError" do
        expect { @cli.list("yourmom") }.to raise_error(ArgumentError)
      end
    end
  end
  
  describe '#search' do
    it "bails if no query given" do
      expect { @cli.search }.to raise_error("Okay, but what do you want to search for?")
    end
    it "compares the given query to the name of each task (not time period) in the system, and returns matching results" do
      project1 = Factory(:project, :name => "project 1")
      project2 = Factory(:project, :name => "project 2222")
      task1 = Factory(:task,
        :number => "1",
        :project => project1,
        :name => "foo bar baz",
        :last_started_at => Time.zone.local(2010, 1, 1, 5, 23),
        :state => "stopped"
      )
      Factory(:time_period, :task => task1)
      task2 = Factory(:task,
        :number => "21",
        :project => project2, 
        :name => "foosball table",
        :last_started_at => Time.zone.local(2010, 1, 21, 10, 24),
        :state => "running"
      )
      Factory(:time_period, :task => task2)
      Factory(:time_period, :task => task2)
      task3 = Factory(:task, 
        :number => "3", 
        :project => project1, 
        :name => "nancy pelosi",
        :last_started_at => Time.zone.local(2010, 1, 2, 11, 22),
        :state => "running"
      )
      Factory(:time_period, :task => task3)
      @cli.search("foo")
      stdout.lines.must smart_match([
        "Search results:",
        '[#21] project 2222 / foosball table (*) (last active: 1/21/2010)',
        '[ #1] project 1    / foo bar baz        (last active:  1/1/2010)'
      ])
    end
    it "makes an OR query from multiple words" do
      project1 = Factory(:project, :name => "project 1")
      project2 = Factory(:project, :name => "project 2222")
      task1 = Factory(:task,
        :number => "1",
        :project => project1,
        :name => "foo bar baz",
        :last_started_at => Time.zone.local(2010, 1, 1, 5, 23),
        :state => "stopped"
      )
      Factory(:time_period, :task => task1)
      task2 = Factory(:task,
        :number => "21",
        :project => project2, 
        :name => "foosball table",
        :last_started_at => Time.zone.local(2010, 1, 21, 10, 24),
        :state => "stopped"
      )
      Factory(:time_period, :task => task2)
      Factory(:time_period, :task => task2)
      task3 = Factory(:task, 
        :number => "3", 
        :project => project1, 
        :name => "nancy pelosi",
        :last_started_at => Time.zone.local(2010, 1, 2, 11, 22),
        :state => "running"
      )
      Factory(:time_period, :task => task3)
      @cli.search("foo", "pelosi")
      stdout.lines.must smart_match([
        "Search results:",
        '[#21] project 2222 / foosball table   (last active: 1/21/2010)',
        '[ #3] project 1    / nancy pelosi (*) (last active:  1/2/2010)',
        '[ #1] project 1    / foo bar baz      (last active:  1/1/2010)'
      ])
    end
  end
  
end