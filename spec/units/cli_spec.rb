require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Cli do
  before do
    @stdin, @stdout, @stderr = Array.new(3) { StringIO.new }
    @cli = TimeTracker::Cli.new(:stdin => @stdin, :stdout => @stdout, :stderr => @stderr, :program_name => "tt")
  end
  
  def stdout
    @stdout.string#.strip
  end
  
  def stderr
    @stderr.string#.strip
  end
  
  def stdin
    @stdin
  end
  
  describe '#add' do
    context "with 'project' argument" do
      context "integration with Pivotal Tracker" do
        before do
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          stub(@project = Object.new).id { 5 }
        end
        it "pulls the latest projects from Pivotal Tracker" do
          mock(@service).pull_projects
          stub(@service).add_project { @project }
          @cli.run_command!("add", "project", "some project")
        end
      end
      it "creates a new project" do
        @cli.run_command!("add", "project", "some project")
        TimeTracker::Project.count.must == 1
        TimeTracker::Project.first.name.must == "some project"
      end
      it "bails if no name given" do
        expect { @cli.run_command!("add", "project") }.to raise_error("Right, but what do you want to call the new project?")
      end
      it "bails if the project already exists" do
        Factory(:project, :name => "some project")
        expect { @cli.run_command!("add", "project", "some project") }.to raise_error("It looks like this project already exists.")
      end
    end
    context "with 'task' argument" do
      before do
        @project = Factory(:project, :name => "some project")
        TimeTracker.config.update("current_project_id", @project.id.to_s)
        @time = Time.zone.local(2010)
      end
      context "integration with Pivotal Tracker" do
        before do
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          stub(@task = Object.new).id { 5 }
        end
        it "pulls the latest tasks from Pivotal Tracker" do
          mock(@service).pull_tasks(@project)
          stub(@service).add_task { @task }
          @cli.run_command!("add", "task", "some task")
        end
      end
      it "creates a new task in the current project" do
        Timecop.freeze(@time) do
          @cli.run_command!("add", "task", "some task")
        end
        TimeTracker::Task.count.must == 1
        task = TimeTracker::Task.last(:order => :number)
        task.project.name.must == "some project"
        task.name.must == "some task"
        task.created_at.must == @time
        stdout.must == %{Task "some task" created.\n}
      end
      context "if a task by the given name already exists" do
        it "bails if the task hasn't been started yet" do
          @project.tasks.create!(:name => "some task", :state => "unstarted")
          expect { @cli.run_command!("add", "task", "some task") }.to
            raise_error("It looks like you've already added that task. Perhaps you'd like to upvote it instead?")
        end
        it "bails if the task is running" do
          @project.tasks.create!(:name => "some task", :state => "running")
          expect { @cli.run_command!("add", "task", "some task") }.to raise_error("Aren't you already working on that task?")
        end
        it "bails if the task is paused" do
          @project.tasks.create!(:name => "some task", :state => "paused")
          expect { @cli.run_command!("add", "task", "some task") }.to raise_error("Aren't you still working on that task?")
        end
        it "doesn't bail, but creates a new task, if the task is stopped" do
          @project.tasks.create!(:name => "some task", :state => "stopped")
          Timecop.freeze(@time) do
            @cli.run_command!("add", "task", "some task")
          end
          TimeTracker::Task.count.must == 2
          task = TimeTracker::Task.last(:order => :number)
          task.project.name.must == "some project"
          task.name.must == "some task"
          task.created_at.must == @time
          stdout.must == %{Task "some task" created.\n}
        end
      end
    end
  end
  
  describe '#switch' do
    context "integration with Pivotal Tracker" do
      before do
        @service = Object.new
        stub(TimeTracker).external_service { @service }
        stub(@project = Object.new).id { 5 }
        stub(@service).pull_projects
        stub(@service).add_project { @project }
      end
      it "pulls the latest projects from Pivotal Tracker" do
        mock(@service).pull_projects
        stdin.sneak("y\n")
        @cli.run_command!("switch", "some project")
      end
      it "also pulls the latest tasks in the current project, if one is set, from Pivotal Tracker" do
        curr_proj = Factory(:project)
        stub(TimeTracker).current_project { curr_proj }
        mock(@service).pull_tasks(curr_proj)
        stdin.sneak("y\n")
        @cli.run_command!("switch", "some project")
      end
    end
    it "finds the given project and sets the current one to that" do
      project = Factory(:project, :name => "some project")
      @cli.run_command!("switch", "some project")
      TimeTracker::Project.count.must == 1
      TimeTracker.config["current_project_id"].must == project.id
      stdout.must == %{Switched to project "some project".\n}
    end
    it "creates the given project if it doesn't already exist (given user accepts prompt)" do
      stdin.sneak("y\n")
      @cli.run_command!("switch", "some project")
      TimeTracker::Project.count.must == 1
      TimeTracker::Project.first.name.must == "some project"
      TimeTracker.config["current_project_id"].must_not be_nil
      stdout.must start_with(%{I can't find this project. Did you want to create it? (y/n) })
      stdout.must end_with(%{Switched to project "some project".\n})
    end
    it "aborts if prompt to auto-create project is denied" do
      stdin.sneak("n\n")
      @cli.run_command!("switch", "some project")
      stdout.must start_with(%{I can't find this project. Did you want to create it? (y/n) })
      stdout.must end_with(%{Okay, never mind then.})
    end
    it "auto-pauses any task that's running in the current project before switching to the given one" do
      project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", project.id.to_s)
      time1 = Time.zone.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.zone.local(2010, 1, 1, 0, 1, 0)
      task = Factory(:task, :project => project, :name => "some task", :created_at => time1, :state => "running")
      Timecop.freeze(time2) do
        stdin.sneak("y\n")
        @cli.run_command!("switch", "another project")
      end
      task.time_periods.first.ended_at.must == time2
      task.must be_paused
      stdout.must end_with(%{(Pausing clock for "some task", at 1m.)\nSwitched to project "another project".\n})
    end
    it "auto-resumes a task that had been paused in this project prior to switching to another one" do
      project1 = Factory(:project, :name => "some project")
      task = Factory(:task, :project => project1, :name => "some task", :state => "paused")
      project2 = Factory(:project, :name => "another project")
      TimeTracker.config.update("current_project_id", project2.id.to_s)
      stdin.sneak("y\n")
      @cli.run_command!("switch", "some project")
      task.reload
      task.must be_running
      stdout.must end_with(%{Switched to project "some project".\n(Resuming clock for "some task".)\n})
    end
  end
  
  describe '#start' do
    before do
      @project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", @project.id.to_s)
      @time = Time.zone.local(2010)
    end
    it "bails if no name given" do
      expect { @cli.start }.to raise_error("Right, but which task do you want to start?")
    end
    it "bails if no project has been set yet" do
      TimeTracker.config.update("current_project_id", nil)
      expect { @cli.run_command!("start", "some task") }.to raise_error("Try switching to a project first.")
    end
    context "integration with Pivotal Tracker" do
      before do
        @service = Object.new
        stub(TimeTracker).external_service { @service }
        stub(@task = Object.new).id { 5 }
        stub(@service).add_task { @task }
      end
      it "pulls the latest tasks in the current project from Pivotal Tracker" do
        mock(@service).pull_tasks(@project)
        stdin.sneak("y\n")
        @cli.run_command!("start", "some task")
      end
    end
    context "when a task exists with the same name under the current project" do
      it "starts the clock for the task if it hasn't been started yet" do
        task = Factory(:task, :project => @project, :name => "some task", :state => "unstarted")
        Timecop.freeze(@time) do
          @cli.run_command!("start", "some task")
        end
        TimeTracker::Task.count.must == 1
        task.reload
        task.must be_running
        task.last_started_at.must == @time
        stdout.must == %{Started clock for "some task".\n}
      end
      it "bails if the task is running" do
        Factory(:task, :project => @project, :name => "some task", :state => "running")
        expect { @cli.run_command!("start", "some task") }.to raise_error("Aren't you already working on that task?")
      end
      it "bails if the task is paused" do
        Factory(:task, :project => @project, :name => "some task", :state => "paused")
        expect { @cli.run_command!("start", "some task") }.to raise_error("Aren't you still working on that task?")
      end
      it "doesn't bail, but creates a new task, if the task is stopped" do
        task = Factory(:task, :project => @project, :name => "some task", :state => "stopped")
        Timecop.freeze(@time) do
          stdin.sneak("y\n")
          @cli.run_command!("start", "some task")
        end
        TimeTracker::Task.count.must == 2
        task2 = TimeTracker::Task.last(:order => :number)
        task2.id.must_not == task.id
        task2.project.name.must == "some project"
        task2.name.must == "some task"
        task2.must be_running
        task2.created_at.must == @time
        stdout.must end_with(%{Started clock for "some task".\n})
      end
    end
    it "auto-creates the task under the current project (given user accepts prompt) and starts the clock for it" do
      Timecop.freeze(@time) do
        stdin.sneak("y\n")
        @cli.run_command!("start", "some task")
        stdout.must start_with(%{I can't find this task. Did you want to create it? (y/n) })
      end
      TimeTracker::Task.count.must == 1
      task = TimeTracker::Task.last(:order => :number)
      task.project.name.must == "some project"
      task.name.must == "some task"
      task.must be_running
      task.created_at.must == @time
      stdout.must end_with(%{Started clock for "some task".})
    end
    it "aborts if prompt to auto-create is denied" do
      stdin.sneak("n\n")
      @cli.run_command!("start", "some task")
      stdout.must start_with(%{I can't find this task. Did you want to create it? (y/n) })
      stdout.must end_with(%{Okay, never mind then.})
    end
    it "auto-pauses any task that's currently running before starting a new one" do
      time1 = Time.zone.local(2010, 1, 1, 0, 0, 0)
      time2 = Time.zone.local(2010, 1, 1, 0, 1, 0)
      task1 = Factory(:task, :project => @project, :name => "some task", :created_at => time1, :state => "running")
      Timecop.freeze(time2) do
        stdin.sneak("y\n")
        @cli.run_command!("start", "another task")
      end
      TimeTracker::Task.count.must == 2
      task1.time_periods.first.ended_at.must == time2
      task1.must be_paused
      task2 = TimeTracker::Task.last(:order => :number)
      task2.project.name.must == "some project"
      task2.name.must == "another task"
      task2.must be_running
      task2.created_at.must == time2
      stdout.must end_with(%{(Pausing clock for "some task", at 1m.)\nStarted clock for "another task".\n})
    end
  end
  
  describe '#stop' do
    before do
      @project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", @project.id.to_s)
    end
    context "with no argument" do
      it "bails if no project has been set yet" do
        TimeTracker.config.update("current_project_id", nil)
        expect { @cli.stop }.to raise_error("Try switching to a project first.")
      end
      context "integration with Pivotal Tracker" do
        before do
          Factory(:task, :project => @project, :state => "running")
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          stub(@task = Object.new).id { 5 }
          stub(@service).add_task { @task }
          stub(@service).check_task_exists!
        end
        it "pulls the latest tasks in the current project from Pivotal Tracker" do
          mock(@service).pull_tasks(@project)
          stdin.sneak("y\n")
          @cli.run_command!("stop")
        end
      end
      it "bails if no tasks have been created under this project yet" do
        expect { @cli.stop }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "stops the currently running task in the current project, creating a time period" do
        started_at = Time.local(2010, 1, 1, 0, 0, 0)
        ended_at = Time.local(2010, 1, 1, 3, 29, 0)
        task1 = Factory(:task, :project => @project, :name => "some task", :created_at => started_at, :state => "running")
        task2 = Factory(:task, :project => @project, :name => "another task", :state => "stopped")
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
      it "bails if all tasks under this project have been stopped" do
        Factory(:task, :project => @project, :state => "stopped")
        expect { @cli.stop }.to raise_error("It doesn't look like you're working on anything at the moment.")
      end
      it "bails if none of the tasks under this project have been started yet" do
        Factory(:task, :project => @project, :state => "unstarted")
        expect { @cli.stop }.to raise_error("It doesn't look like you're working on anything at the moment.")
      end
      it "auto-resumes the last task under this project that was paused" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "paused", :updated_at => Time.local(2010, 1, 1, 1, 0, 0))
        task2 = Factory(:task, :project => @project, :name => "another task", :state => "paused", :updated_at => Time.local(2010, 1, 1, 2, 0, 0))
        task3 = Factory(:task, :project => @project, :name => "yet another task", :created_at => Time.local(2010, 1, 1, 3, 0, 0), :state => "running")
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
        TimeTracker.config.update("current_project_id", nil)
        expect { @cli.run_command!("stop", "some task") }.to raise_error("Try switching to a project first.")
      end
      context "integration with Pivotal Tracker" do
        before do
          Factory(:task, :project => @project, :name => "some task", :state => "running")
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          stub(@task = Object.new).id { 5 }
          stub(@service).add_task { @task }
          stub(@service).check_task_exists!
        end
        it "pulls the latest tasks in the current project from Pivotal Tracker" do
          mock(@service).pull_tasks(@project)
          @cli.run_command!("stop", "some task")
        end
      end
      it "bails if no tasks have been created under this project yet" do
        expect { @cli.run_command!("stop", "some task") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "stops the task matching the given name" do
        task1 = Factory(:task, :project => @project, :name => "some task", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        stopped_at = Time.local(2010, 1, 1, 3, 29)
        Timecop.freeze(stopped_at) do
          @cli.run_command!("stop", "some task")
        end
        task1.reload
        task1.must be_stopped
        stdout.must == %{Stopped clock for "some task", at 3h:29m.\n}
      end
      it "stops the last running task if there are two tasks by the given name" do
        task1 = Factory(:task, :project => @project, :name => "some task", :updated_at => Time.local(2009, 12, 1), :state => "stopped")
        task2 = Factory(:task, :project => @project, :name => "some task", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        stopped_at = Time.local(2010, 1, 1, 3, 29)
        Timecop.freeze(stopped_at) do
          @cli.run_command!("stop", "some task")
        end
        task1.reload
        task1.updated_at.must == Time.local(2009, 12, 1)
        task2.reload
        task2.must be_stopped
        stdout.must == %{Stopped clock for "some task", at 3h:29m.\n}
      end
      it "bails if a task can't be found by the given name" do
        Factory(:task, :project => @project, :name => "another task")
        expect { @cli.run_command!("stop", "some task") }.to raise_error("I don't think that task exists.")
      end
      it "bails if the given task has already been stopped" do
        Factory(:task, :project => @project, :name => "some task", :state => "stopped")
        expect { @cli.run_command!("stop", "some task") }.to raise_error("I think you've stopped that task already.")
      end
      it "doesn't bail if the given task is paused, but stops it" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "paused")
        @cli.run_command!("stop", "some task")
        task1.reload
        task1.must be_stopped
        task1.time_periods.must be_empty
        stdout.must == %{Stopped clock for "some task".\n}
      end
      it "bails if the given task is merely created" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "unstarted")
        expect { @cli.run_command!("stop", "some task") }.to raise_error("You can't stop a task without starting it first!")
      end
      it "auto-resumes the last task under this project that was paused" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "paused")
        task2 = Factory(:task, :project => @project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.run_command!("stop", "another task")
        end
        task1.reload
        task1.must be_running
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming clock for "some task".)\n}
      end
    end
    context "given a number" do
      it "bails if no project has been set yet" do
        TimeTracker.config.update("current_project_id", nil)
        expect { @cli.run_command!("stop", "1") }.to raise_error("Try switching to a project first.")
      end
      context "integration with Pivotal Tracker" do
        before do
          Factory(:task, :project => @project, :number => "1", :state => "running")
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          stub(@task = Object.new).id { 5 }
          stub(@service).add_task { @task }
          stub(@service).check_task_exists!
        end
        it "pulls the latest tasks in the current project from Pivotal Tracker" do
          mock(@service).pull_tasks(@project)
          @cli.run_command!("stop", "1")
        end
      end
      it "bails if no tasks have been created under this project yet" do
        expect { @cli.run_command!("stop", "1") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "stops the task matching the given number" do
        task1 = Factory(:task, :project => @project, :name => "some task", :number => "1", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        stopped_at = Time.local(2010, 1, 1, 3, 29)
        Timecop.freeze(stopped_at) do
          @cli.run_command!("stop", "1")
        end
        task1.reload
        task1.must be_stopped
        stdout.must == %{Stopped clock for "some task", at 3h:29m.\n}
      end
      it "bails if a task can't be found by the given number" do
        Factory(:task, :project => @project, :name => "another task")
        expect { @cli.run_command!("stop", "2") }.to raise_error("I don't think that task exists.")
      end
      it "bails if the given task has already been stopped" do
        Factory(:task, :project => @project, :name => "some task", :number => "1", :state => "stopped")
        expect { @cli.run_command!("stop", "1") }.to raise_error("I think you've stopped that task already.")
      end
      it "doesn't bail if the given task is paused, but stops it" do
        task1 = Factory(:task, :project => @project, :number => "1", :state => "paused")
        @cli.run_command!("stop", "1")
        task1.reload
        task1.must be_stopped
        task1.time_periods.must be_empty
        stdout.must == %{Stopped clock for "some task".\n}
      end
      it "bails if the given task is merely created" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "unstarted")
        expect { @cli.run_command!("stop", "1") }.to raise_error("You can't stop a task without starting it first!")
      end
      it "auto-resumes the last task under this project that was paused" do
        task1 = Factory(:task, :project => @project, :name => "some task", :number => "1", :state => "paused")
        task2 = Factory(:task, :project => @project, :name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.run_command!("stop", "2")
        end
        task1.reload
        task1.must be_running
        stdout.must == %{Stopped clock for "another task", at 3h:29m.\n(Resuming clock for "some task".)\n}
      end
    end
  end
  
  describe '#resume' do
    before do
      @project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", @project.id.to_s)
    end
    it "bails if no name given" do
      TimeTracker.config.update("current_project_id", nil)
      task1 = Factory(:task, :project => @project, :name => "some task", :state => "paused")
      expect { @cli.resume }.to raise_error("Yes, but which task do you want to resume? (I'll accept a number or a name.)")
    end
    context "given a string" do
      it "bails if no project has been set yet" do
        TimeTracker.config.update("current_project_id", nil)
        expect { @cli.run_command!("resume", "some task") }.to raise_error("Try switching to a project first.")
      end
      context "integration with Pivotal Tracker" do
        before do
          Factory(:task, :project => @project, :name => "some task", :state => "paused")
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          stub(@service).check_task_exists!
        end
        it "pulls the latest tasks in the current project from Pivotal Tracker" do
          mock(@service).pull_tasks(@project)
          @cli.run_command!("resume", "some task")
        end
      end
      it "bails if no tasks exist at all" do
        expect { @cli.run_command!("resume", "some task") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "resumes the given paused task" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "paused")
        @cli.run_command!("resume", "some task")
        task1.reload
        task1.must be_running
        stdout.must == %{Resumed clock for "some task".\n}
      end
      it "resumes the given stopped task" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "stopped")
        @cli.run_command!("resume", "some task")
        task1.reload
        task1.must be_running
        stdout.must == %{Resumed clock for "some task".\n}
      end
      it "resumes the last stopped task if there are two tasks by the given name" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "stopped", :created_at => Time.zone.local(2010, 1, 1))
        task2 = Factory(:task, :project => @project, :name => "some task", :state => "stopped", :created_at => Time.zone.local(2010, 2, 1))
        @cli.run_command!("resume", "some task")
        task1.reload
        task1.must be_stopped
        task2.reload
        task2.must be_running
        stdout.must == %{Resumed clock for "some task".\n}
      end
      it "bails if the given task can't be found in this project" do
        Factory(:task, :project => @project, :name => "some task")
        expect { @cli.run_command!("resume", "another task") }.to raise_error("I don't think that task exists.")
      end
      it "bails if a paused task can be found by that name but it's in other projects" do
        project1 = Factory(:project, :name => "some project")
        Factory(:task, :project => project1, :name => "some task", :state => "paused")
        project2 = Factory(:project, :name => "another project")
        Factory(:task, :project => project2, :name => "some task", :state => "paused")
        project3 = Factory(:project, :name => "a different project")
        TimeTracker.config.update("current_project_id", project3.id.to_s)
        expect { @cli.run_command!("resume", "some task") }.to raise_error(%{That task doesn't exist here. Perhaps you meant to switch to "some project" or "another project"?})
      end
      it "ignores created tasks when listing other projects our paused task might be in" do
        project1 = Factory(:project, :name => "some project")
        Factory(:task, :project => project1, :name => "some task", :state => "unstarted")
        project2 = Factory(:project, :name => "another project")
        Factory(:task, :project => project2, :name => "some task", :state => "paused")
        project3 = Factory(:project, :name => "a different project")
        TimeTracker.config.update("current_project_id", project3.id.to_s)
        expect { @cli.run_command!("resume", "some task") }.to raise_error(%{That task doesn't exist here. Perhaps you meant to switch to "another project"?})
      end
      it "bails if a stopped task can be found by that name but it's in other projects" do
        project1 = Factory(:project, :name => "some project")
        Factory(:task, :project => project1, :name => "some task", :state => "stopped")
        project2 = Factory(:project, :name => "another project")
        Factory(:task, :project => project2, :name => "some task", :state => "stopped")
        project3 = Factory(:project, :name => "a different project")
        TimeTracker.config.update("current_project_id", project3.id.to_s)
        expect { @cli.run_command!("resume", "some task") }.to raise_error(%{That task doesn't exist here. Perhaps you meant to switch to "some project" or "another project"?})
      end
      it "ignores created tasks when listing other projects our stopped task might be in" do
        project1 = Factory(:project, :name => "some project")
        Factory(:task, :project => project1, :name => "some task", :state => "unstarted")
        project2 = Factory(:project, :name => "another project")
        Factory(:task, :project => project2, :name => "some task", :state => "stopped")
        project3 = Factory(:project, :name => "a different project")
        TimeTracker.config.update("current_project_id", project3.id.to_s)
        expect { @cli.run_command!("resume", "some task") }.to raise_error(%{That task doesn't exist here. Perhaps you meant to switch to "another project"?})
      end
      it "bails if the given task is already running" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "running")
        expect { @cli.run_command!("resume", "some task") }.to raise_error("Aren't you working on that task already?")
      end
      it "bails if the given task hasn't been started yet" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "unstarted")
        expect { @cli.run_command!("resume", "some task") }.to raise_error("You can't resume a task that you haven't started yet!")
      end
      it "auto-pauses any task that's already running before resuming the given paused task" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "paused")
        task2 = Factory(:task, :project => @project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        paused_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(paused_at) do
          @cli.run_command!("resume", "some task")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before resuming the given stopped task" do
        task1 = Factory(:task, :project => @project, :name => "some task", :state => "stopped")
        task2 = Factory(:task, :project => @project, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        paused_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(paused_at) do
          @cli.run_command!("resume", "some task")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".\n}
      end
    end
    context "given a number" do
      it "bails if no project has been set yet" do
        TimeTracker.config.update("current_project_id", nil)
        expect { @cli.run_command!("resume", "1") }.to raise_error("Try switching to a project first.")
      end
      context "integration with Pivotal Tracker" do
        before do
          Factory(:task, :project => @project, :number => "1", :state => "paused")
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          stub(@service).check_task_exists!
        end
        it "pulls the latest tasks in the current project from Pivotal Tracker" do
          mock(@service).pull_tasks(@project)
          @cli.run_command!("resume", "1")
        end
      end
      it "bails if no tasks exist at all" do
        expect { @cli.run_command!("resume", "1") }.to raise_error("It doesn't look like you've started any tasks yet.")
      end
      it "resumes the given paused task" do
        task1 = Factory(:task, :project => @project, :name => "some task", :number => "1", :state => "paused")
        @cli.run_command!("resume", "1")
        task1.reload
        task1.must be_running
        stdout.must == %{Resumed clock for "some task".\n}
      end
      it "resumes the given stopped task" do
        task1 = Factory(:task, :project => @project, :name => "some task", :number => "1", :state => "stopped")
        @cli.run_command!("resume", "1")
        task1.reload
        task1.must be_running
        stdout.must == %{Resumed clock for "some task".\n}
      end
      it "bails if the given task can't be found" do
        Factory(:task, :project => @project)
        expect { @cli.run_command!("resume", "2") }.to raise_error("I don't think that task exists.")
      end
      it "bails if the given task is already running" do
        task1 = Factory(:task, :project => @project, :number => "1", :state => "running")
        expect { @cli.run_command!("resume", "1") }.to raise_error("Aren't you working on that task already?")
      end
      it "bails if the given task hasn't been started yet" do
        task1 = Factory(:task, :project => @project, :number => "1", :state => "unstarted")
        expect { @cli.run_command!("resume", "1") }.to raise_error("You can't resume a task that you haven't started yet!")
      end
      it "auto-switches to another project if given paused task is present there" do
        project1 = Factory(:project, :name => "some project")
        task = Factory(:task, :project => project1, :name => "some task", :number => "1", :state => "paused")
        project2 = Factory(:project, :name => "another project")
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        @cli.run_command!("resume", "1")
        TimeTracker.config["current_project_id"].must == project1.id.to_s
        stdout.must == %{(Switching to project "some project".)\nResumed clock for "some task".\n}
      end
      it "auto-switches to another project if given stopped task is present there" do
        project1 = Factory(:project, :name => "some project")
        task = Factory(:task, :project => project1, :name => "some task", :number => "1", :state => "stopped")
        project2 = Factory(:project, :name => "another project")
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        @cli.run_command!("resume", "1")
        TimeTracker.config["current_project_id"].must == project1.id.to_s
        stdout.must == %{(Switching to project "some project".)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before auto-switching to another project where paused task is present" do
        project1 = Factory(:project, :name => "some project")
        task1 = Factory(:task, :project => project1, :name => "some task", :number => "1", :state => "paused")
        project2 = Factory(:project, :name => "another project")
        task2 = Factory(:task, :project => project2, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.run_command!("resume", "1")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\n(Switching to project "some project".)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before auto-switching to another project where stopped task is present" do
        project1 = Factory(:project, :name => "some project")
        task1 = Factory(:task, :project => project1, :name => "some task", :number => "1", :state => "stopped")
        project2 = Factory(:project, :name => "another project")
        task2 = Factory(:task, :project => project2, :name => "another task", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        TimeTracker.config.update("current_project_id", project2.id.to_s)
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.run_command!("resume", "1")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\n(Switching to project "some project".)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before resuming the given paused task" do
        task1 = Factory(:task, :project => @project, :name => "some task", :number => "1", :state => "paused")
        task2 = Factory(:task, :project => @project, :name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.run_command!("resume", "1")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".\n}
      end
      it "auto-pauses any task that's already running before resuming the given stopped task" do
        task1 = Factory(:task, :project => @project, :name => "some task", :number => "1", :state => "stopped")
        task2 = Factory(:task, :project => @project, :name => "another task", :number => "2", :created_at => Time.local(2010, 1, 1, 0, 0, 0), :state => "running")
        stopped_at = Time.local(2010, 1, 1, 3, 29, 0)
        Timecop.freeze(stopped_at) do
          @cli.run_command!("resume", "1")
        end
        task2.reload
        task2.must be_paused
        stdout.must == %{(Pausing clock for "another task", at 3h:29m.)\nResumed clock for "some task".\n}
      end
    end
  end
  
  describe '#upvote' do
    before do
      @project = Factory(:project, :name => "some project")
      TimeTracker.config.update("current_project_id", @project.id.to_s)
    end
    it "bails if no name given" do
      expect { @cli.upvote }.to raise_error("Yes, but which task do you want to upvote? (I'll accept a number or a name.)")
    end
    context "given a string" do
      it "bails if no project has been set yet" do
        Factory(:task, :project => @project, :name => "some task", :num_votes => 3)
        TimeTracker.config.update("current_project_id", nil)
        expect { @cli.run_command!("upvote", "some task") }.to raise_error("Try switching to a project first.")
      end
      context "integration with Pivotal Tracker" do
        before do
          Factory(:task, :project => @project, :name => "some task", :num_votes => 3)
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          stub(@service).check_task_exists!
        end
        it "pulls the latest tasks in the current project from Pivotal Tracker" do
          mock(@service).pull_tasks(@project)
          @cli.run_command!("upvote", "some task")
        end
      end
      it "increments the number of votes for the task on each call" do
        task = Factory(:task, :project => @project, :name => "some task", :num_votes => 3)
        @cli.run_command!("upvote", "some task")
        task.reload
        task.num_votes.must == 4
        stdout.lines.last.must == %{This task now has 4 votes.}
      
        @cli.run_command!("upvote", "some task")
        task.reload
        task.num_votes.must == 5
        stdout.lines.last.must == %{This task now has 5 votes.}
      end
      it "bails if the task can't be found" do
        expect { @cli.run_command!("upvote", "some task") }.to raise_error("I don't think that task exists.")
      end
      it "bails if the task is running" do
        Factory(:task, :project => @project, :name => "some task", :state => "running")
        expect { @cli.run_command!("upvote", "some task") }.to raise_error("There isn't any point in upvoting a task you're already working on.")
      end
      it "bails if the task is stopped" do
        Factory(:task, :project => @project, :name => "some task", :state => "stopped")
        expect { @cli.run_command!("upvote", "some task") }.to raise_error("There isn't any point in upvoting a task you've already completed.")
      end
      it "bails if the task is paused" do
        Factory(:task, :project => @project, :name => "some task", :state => "paused")
        expect { @cli.run_command!("upvote", "some task") }.to raise_error("There isn't any point in upvoting a task you're already working on.")
      end
    end
    context "given a number" do
      it "bails if no project has been set yet" do
        Factory(:task, :project => @project, :number => 1, :num_votes => 3)
        TimeTracker.config.update("current_project_id", nil)
        expect { @cli.run_command!("upvote", "1") }.to raise_error("Try switching to a project first.")
      end
      context "integration with Pivotal Tracker" do
        before do
          Factory(:task, :project => @project, :number => 1, :num_votes => 3)
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          stub(@service).check_task_exists!
        end
        it "pulls the latest tasks in the current project from Pivotal Tracker" do
          mock(@service).pull_tasks(@project)
          @cli.run_command!("upvote", "1")
        end
      end
      it "increments the number of votes for the task on each call" do
        task = Factory(:task, :project => @project, :number => 1, :num_votes => 3)
        @cli.run_command!("upvote", "1")
        task.reload
        task.num_votes.must == 4
        stdout.lines.last.must == %{This task now has 4 votes.}
      
        @cli.run_command!("upvote", "1")
        task.reload
        task.num_votes.must == 5
        stdout.lines.last.must == %{This task now has 5 votes.}
      end
      it "bails if the task can't be found" do
        expect { @cli.run_command!("upvote", "1") }.to raise_error("I don't think that task exists.")
      end
      it "bails if the task is running" do
        Factory(:task, :project => @project, :number => 1, :state => "running")
        expect { @cli.run_command!("upvote", "1") }.to raise_error("There isn't any point in upvoting a task you're already working on.")
      end
      it "bails if the task is stopped" do
        Factory(:task, :project => @project, :number => 1, :state => "stopped")
        expect { @cli.run_command!("upvote", "1") }.to raise_error("There isn't any point in upvoting a task you've already completed.")
      end
      it "bails if the task is paused" do
        Factory(:task, :project => @project, :number => 1, :state => "paused")
        expect { @cli.run_command!("upvote", "1") }.to raise_error("There isn't any point in upvoting a task you're already working on.")
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
        @cli.run_command!("list", *@args)
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
        @cli.run_command!("list", *@args)
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
      it "does not include tasks that have merely been created" do
        Timecop.freeze Time.zone.local(2010, 1, 1)
        project1 = Factory(:project, :name => "some project")
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
        task2 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "another task",
          :state => "unstarted"
        )
        @cli.run_command!("list", *@args)
        stdout.lines.must smart_match([
          "",
          "Latest tasks:",
          "",
          "12:00am - 5:05am [#1] some project / some task",
          ""
        ])
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.run_command!("list", *@args)
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
      end
      context "Pivotal Tracker integration" do
        it "pulls the latest tasks from the API" do
          task = Factory(:task)
          Factory(:time_period, :task => task)
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          mock(@service).pull_tasks
          @cli.run_command!("list", *@args)
        end
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
        @cli.run_command!("list", "completed")
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
        @cli.run_command!("list", "completed")
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
      end
      context "Pivotal Tracker integration" do
        it "pulls the latest tasks from the API" do
          task = Factory(:task, :state => "stopped")
          Factory(:time_period, :task => task)
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          mock(@service).pull_tasks
          @cli.run_command!("list", "completed")
        end
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
        @cli.run_command!("list", "all")
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
      it "does not include tasks which have merely been created" do
        Timecop.freeze Time.zone.local(2010, 1, 1)
        project1 = Factory(:project, :name => "some project")
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
        task2 = Factory(:task,
          :number => "1",
          :project => project1,
          :name => "another task",
          :state => "unstarted"
        )
        @cli.run_command!("list", "all")
        stdout.lines.must smart_match([
          "",
          "All tasks:",
          "",
          "Today:",
          "  12:00am - 5:05am [#1] some project / some task",
          ""
        ])
      end
      it "prints a notice message if no tasks are in the database" do
        @cli.run_command!("list", "all")
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
      end
      context "Pivotal Tracker integration" do
        it "pulls the latest tasks from the API" do
          task = Factory(:task, :state => "stopped")
          Factory(:time_period, :task => task)
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          mock(@service).pull_tasks
          @cli.run_command!("list", "all")
        end
      end
    end
    context "today" do
      before do
        Timecop.freeze Time.zone.local(2010, 1, 2)
      end
      it "prints a list of time periods that ended today, ordered by ended_at" do
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
        @cli.run_command!("list", "today")
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
        @cli.run_command!("list", "today")
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
      end
      context "Pivotal Tracker integration" do
        it "pulls the latest tasks from the API" do
          task = Factory(:task, :state => "stopped")
          Factory(:time_period,
            :task => task,
            :started_at => Time.zone.local(2010, 1, 2),
            :ended_at => Time.zone.local(2010, 1, 2)
          )
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          mock(@service).pull_tasks
          @cli.run_command!("list", "today")
        end
      end
    end
    context "this week" do
      before do
        Timecop.freeze Time.zone.local(2010, 8, 5)
      end
      it "prints a list of tasks updated this week, ordered by last updated time" do
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
        @cli.run_command!("list", "this week")
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
        @cli.run_command!("list", "this week")
        stdout.must == "It doesn't look like you've started any tasks yet.\n"
      end
      context "Pivotal Tracker integration" do
        it "pulls the latest tasks from the API" do
          task = Factory(:task, :state => "stopped")
          Factory(:time_period,
            :task => task,
            :started_at => Time.zone.local(2010, 8, 5),
            :ended_at => Time.zone.local(2010, 8, 5)
          )
          @service = Object.new
          stub(TimeTracker).external_service { @service }
          mock(@service).pull_tasks
          @cli.run_command!("list", "this week")
        end
      end
    end
    context "unknown command" do
      it "fails with an InvalidInvocationError" do
        expect { @cli.run_command!("list", "yourmom") }.to raise_error(TimeTracker::Commander::InvalidInvocationError)
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
      @cli.run_command!("search", "foo")
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
      @cli.run_command!("search", "foo", "pelosi")
      stdout.lines.must smart_match([
        "Search results:",
        '[#21] project 2222 / foosball table   (last active: 1/21/2010)',
        '[ #3] project 1    / nancy pelosi (*) (last active:  1/2/2010)',
        '[ #1] project 1    / foo bar baz      (last active:  1/1/2010)'
      ])
    end
    # TODO: show a different message if no search results found
    context "Pivotal Tracker integration" do
      it "pulls the latest tasks from the API" do
        Factory(:task, :name => "foosball table")
        @service = Object.new
        stub(TimeTracker).external_service { @service }
        mock(@service).pull_tasks
        @cli.run_command!("search", "foo")
      end
    end
  end
  
  describe '#configure' do
    before do
      TimeTracker.external_service = nil
    end
    it "bails if the subcommand is invalid" do
      expect { @cli.run_command!("configure", "sadjklf") }.to \
        raise_error("Oops! That isn't the right way to call \"configure\". Try one of these:\n\n" +
        "  tt configure external_service pivotal --api-key KEY --full-name NAME")
    end
    context "with external_service argument" do
      it "bails if service not given" do
        expect { @cli.run_command!("configure", "external_service") }.to \
          raise_error("Right, but which external service do you want to integrate with? Try one of these:\n\n" +
          "  tt configure external_service pivotal --api-key KEY --full-name NAME")
      end
      it "bails if service is not valid" do
        expect { @cli.run_command!("configure", "external_service", "adslkf") }.to \
          raise_error("Sorry, tt doesn't have support for the 'adslkf' service. Try one of these:\n\n" +
          "  tt configure external_service pivotal --api-key KEY --full-name NAME")
      end
      context "using pivotal_tracker service" do
        it "bails if no api key given" do
          expect { @cli.run_command!("configure", "external_service", "pivotal", "--full-name", "Joe Bloe") }.to \
            raise_error("I'm missing the API key.\n\n" +
            "Try this: tt configure external_service pivotal --api-key KEY --full-name NAME")
        end
        it "bails if no full name given" do
          expect { @cli.run_command!("configure", "external_service", "pivotal", "--api-key", "xxxx") }.to \
            raise_error("I'm missing your full name.\n\n" +
            "Try this: tt configure external_service pivotal --api-key KEY --full-name NAME")
        end
        it "aborts if the API key is incorrect" do
          stub.proxy(TimeTracker::Service::PivotalTracker).new do |service|
            stub(service).valid? { false }
          end
          @cli.run_command!("configure", "external_service", "pivotal", "--api-key", "xxxx", "--full-name", "Joe Bloe")
          TimeTracker.external_service.must be_nil
          TimeTracker.reload_config
          TimeTracker.config["external_service"].must be_nil
          TimeTracker.config["external_service_options"].must be_nil
        end
        it "bails if projects already exist" do
          Factory(:project)
          expect { @cli.run_command!("configure", "external_service", "pivotal", "--api-key", "xxxx", "--full-name", "Joe Bloe") }.to \
            raise_error("Actually -- you can't do that if you've already created a project or task. Sorry.")
        end
        it "bails if tasks already exist" do
          project = Factory(:project)
          Factory(:task, :project => project)
          expect { @cli.run_command!("configure", "external_service", "pivotal", "--api-key", "xxxx", "--full-name", "Joe Bloe") }.to \
            raise_error("Actually -- you can't do that if you've already created a project or task. Sorry.")
        end
        it "stores the api key and full name with the service" do
          stub.proxy(TimeTracker::Service::PivotalTracker).new do |service|
            stub(service).valid? { true }
          end
          @cli.run_command!("configure", "external_service", "pivotal", "--api-key", "xxxx", "--full-name", "Joe Bloe")
          TimeTracker.external_service.must be_a(TimeTracker::Service::PivotalTracker)
          TimeTracker.reload_config
          TimeTracker.config["external_service"].must == "pivotal_tracker"
          TimeTracker.config["external_service_options"].must == {"api_key" => "xxxx", "full_name" => "Joe Bloe"}
        end
      end
    end
    context "with no arguments" do
      it "prompts the user for an API key for Pivotal Tracker" do
        stdin.sneak("y\nxxxx\nJoe Bloe\n")
        stub.proxy(TimeTracker::Service::PivotalTracker).new(:api_key => "xxxx", :full_name => "Joe Bloe") do |service|
          stub(service).valid? { true }
        end
        @cli.run_command!("configure")
        TimeTracker.external_service.must be_a(TimeTracker::Service::PivotalTracker)
        TimeTracker.reload_config
        TimeTracker.config["external_service"].must == "pivotal_tracker"
        TimeTracker.config["external_service_options"].must == {"api_key" => "xxxx", "full_name" => "Joe Bloe"}
      end
      it "aborts if the user doesn't want to integrate with Pivotal Tracker" do
        stdin.sneak("n\n")
        @cli.run_command!("configure")
        TimeTracker.external_service.must be_nil
        TimeTracker.reload_config
        TimeTracker.config["external_service"].must be_nil
        TimeTracker.config["external_service_options"].must be_nil
      end
      it "aborts if the Pivotal Tracker credentials are incorrect" do
        stdin.sneak("y\nxxxx\nJoe Bloe\n")
        stub.proxy(TimeTracker::Service::PivotalTracker).new(:api_key => "xxxx", :full_name => "Joe Bloe") do |service|
          stub(service).valid? { false }
        end
        @cli.run_command!("configure")
        TimeTracker.external_service.must be_nil
        TimeTracker.reload_config
        TimeTracker.config["external_service"].must be_nil
        TimeTracker.config["external_service_options"].must be_nil
      end
      it "bails if projects already exist" do
        Factory(:project)
        stdin.sneak("y\n")
        expect { @cli.run_command!("configure") }.to \
          raise_error("Actually -- you can't do that if you've already created a project or task. Sorry.")
      end
      it "bails if tasks already exist" do
        project = Factory(:project)
        Factory(:task, :project => project)
        stdin.sneak("y\n")
        expect { @cli.run_command!("configure") }.to \
          raise_error("Actually -- you can't do that if you've already created a project or task. Sorry.")
      end
    end
  end
  
end