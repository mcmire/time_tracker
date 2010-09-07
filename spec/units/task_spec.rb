require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Task do
  
  before do
    @task = TimeTracker::Task.new
  end
  
  context "on create" do
    it "gets assigned a number one higher than the last one regardless of project" do
      Factory(:task).number.must == 1
      Factory(:task).number.must == 2
    end
    it "does not get assigned a number if number is already set" do
      Factory(:task, :number => 18).number.must == 18
    end
    it "sets last_started_at to created_at" do
      time = Time.local(2010, 1, 1)
      Factory(:task, :created_at => time).last_started_at.must == time
    end
    it "doesn't set last_started_at if last_started_at is already specified" do
      time = Time.local(2010, 1, 1)
      Factory(:task, :last_started_at => time).last_started_at.must == time
    end
    it "sets state to 'created' by default" do
      Factory(:task).state.must == "unstarted"
    end
    it "sets num_votes to 1 by default" do
      Factory(:task).num_votes.must == 1
    end
    it "adds the task to whichever external service is selected and saves the external id" do
      project = Factory(:project)
      @service = Object.new
      stub(TimeTracker).external_service { @service }
      stub(@task = Object.new).id { 5 }
      mock(@service).add_task!(project, "some task") { @task }
      task = Factory(:task, :name => "some task", :project => project)
      task.external_id.must == 5
    end
  end
  
  context "on update" do
    it "doesn't touch the number set at creation" do
      task = Factory(:task)
      number = task.number
      task.save!
      task.reload
      task.number.must == number
    end
    it "doesn't touch the value of last_started_at set at creation" do
      task = Factory(:task)
      last_started_at = task.last_started_at
      task.save!
      task.reload
      task.last_started_at == last_started_at
    end
    it "pushes the task to the external service" do
      task = Factory(:task, :external_id => 1)
      mock(@service = Object.new).push_task!(task)
      stub(TimeTracker).external_service { @service }
      task.save!
    end
    it "bails if the task doesn't exist in the external service" do
      task = Factory(:task, :external_id => 1)
      mock(@service = Object.new).push_task!(task) do
        raise TimeTracker::Service::ResourceNotFoundError.new(nil, nil)
      end
      stub(TimeTracker).external_service { @service }
      expect { task.save! }.to raise_error(TimeTracker::Service::ResourceNotFoundError)
    end
  end
  
  describe '.last_running' do
    it "returns the last created task regardless of id" do
      project = Factory(:project)
      task1 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 1), :state => "running")
      task2 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 4), :state => "running")
      task3 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 3), :state => "running")
      task4 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 2), :state => "running")
      TimeTracker::Task.last_running.must == task2
    end
  end
  
  describe '.last_stopped' do
    it "returns the last created task regardless of id" do
      project = Factory(:project)
      task1 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 1), :state => "stopped")
      task2 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 4), :state => "stopped")
      task3 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 3), :state => "stopped")
      task4 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 2), :state => "stopped")
      TimeTracker::Task.last_stopped.must == task2
    end
  end
  
  describe '.last_paused' do
    it "returns the last created task regardless of id" do
      project = Factory(:project)
      task1 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 1), :state => "paused")
      task2 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 4), :state => "paused")
      task3 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 3), :state => "paused")
      task4 = Factory(:task, :project => project, :updated_at => Time.local(2010, 1, 2), :state => "paused")
      TimeTracker::Task.last_paused.must == task2
    end
  end
  
  describe '.running' do
    it "includes tasks which are running" do
      running_task = Factory(:task, :state => "running")
      TimeTracker::Task.running.to_a.must include(running_task)
    end
    it "excludes tasks which are not running" do
      stopped_task = Factory(:task, :state => "stopped")
      TimeTracker::Task.running.to_a.must_not include(stopped_task)
    end
  end
  
  describe '.not_running' do
    it "includes tasks which are paused" do
      paused_task = Factory(:task, :state => "paused")
      TimeTracker::Task.not_running.to_a.must include(paused_task)
    end
    it "includes tasks which are stopped" do
      stopped_task = Factory(:task, :state => "stopped")
      TimeTracker::Task.not_running.to_a.must include(stopped_task)
    end
    it "excludes tasks which are running" do
      running_task = Factory(:task, :state => "running")
      TimeTracker::Task.not_running.to_a.must_not include(running_task)
    end
  end
  
  describe '.stopped' do
    it "includes tasks which are stopped" do
      stopped_task = Factory(:task, :state => "stopped")
      TimeTracker::Task.stopped.to_a.must include(stopped_task)
    end
    it "excludes all tasks which aren't stopped" do
      running_task = Factory(:task, :state => "running")
      TimeTracker::Task.stopped.to_a.must_not include(running_task)
    end
  end
  
  describe '.paused' do
    it "includes tasks which are paused" do
      paused_task = Factory(:task, :state => "paused")
      TimeTracker::Task.paused.to_a.must include(paused_task)
    end
    it "excludes tasks which aren't paused" do
      stopped_task = Factory(:task, :state => "stopped")
      TimeTracker::Task.paused.to_a.must_not include(stopped_task)
    end
  end
  
  describe '#unstarted?' do
    it "returns true if state is set to 'unstarted'" do
      @task.state = "unstarted"
      @task.must be_unstarted
    end
    it "returns false if state is not set to 'unstarted'" do
      @task.state = "running"
      @task.must_not be_unstarted
    end
  end
    
  describe '#running?' do
    it "returns true if state is set to 'running'" do
      @task.state = "running"
      @task.must be_running
    end
    it "returns false if state is not set to 'running'" do
      @task.state = "stopped"
      @task.must_not be_running
    end
  end
  
  describe '#stopped?' do
    it "returns true if state is set to 'stopped'" do
      @task.state = "stopped"
      @task.must be_stopped
    end
    it "returns false if state is not set to 'stopped'" do
      @task.state = "running"
      @task.must_not be_stopped
    end
  end
  
  describe '#paused?' do
    it "returns true if state is set to 'paused'" do
      @task.state = "paused"
      @task.must be_paused
    end
    it "returns false if state is not set to 'paused'" do
      @task.state = "running"
      @task.must_not be_paused
    end
  end
  
  describe '#start!' do
    it "sets last_started_at to the current time" do
      time = Time.zone.local(2010)
      Timecop.freeze(time)
      task = Factory.build(:task, :state => "unstarted")
      task.start!
      task.last_started_at.must == time
    end
    it "sets the state to running and saves" do
      task = Factory.build(:task, :state => "unstarted")
      task.start!
      task.state.must == "running"
      task.must_not be_a_new_record
    end
    it "bails if the task is paused" do
      task = Factory(:task, :state => "paused")
      expect { task.start! }.to raise_error("Validation failed: Aren't you still working on that task?")
    end
    it "bails if the task is running" do
      task = Factory(:task, :state => "running")
      expect { task.start! }.to raise_error("Validation failed: Aren't you already working on that task?")
    end
  end
  
  describe '#stop!' do
    it "creates a new time period" do
      started_at = Time.local(2010, 1, 1, 0, 0, 0)
      ended_at = Time.local(2010, 1, 1, 3, 29, 0)
      task = Factory(:task, :created_at => started_at, :state => "running")
      Timecop.freeze(ended_at) do
        task.stop!
      end
      task.reload
      task.time_periods.size.must == 1
      time_period = task.time_periods.first
      time_period.started_at.must == started_at
      time_period.ended_at.must == ended_at
    end
    it "doesn't create a new time period if task was previously paused" do
      task = Factory(:task, :state => "paused")
      task.stop!
      task.time_periods.must be_empty
    end
    it "sets the state to stopped and saves" do
      task = Factory.build(:task, :state => "running")
      task.stop!
      task.state.must == "stopped"
      task.must_not be_a_new_record
    end
    it "bails if the task is stopped" do
      task = Factory(:task, :state => "stopped")
      expect { task.stop! }.to raise_error("Validation failed: I think you've stopped that task already.")
    end
    it "bails if the task hasn't been started yet" do
      task = Factory(:task, :state => "unstarted")
      expect { task.stop! }.to raise_error("Validation failed: You can't stop a task without starting it first!")
    end
  end
  
  describe '#pause!' do
    it "creates a new time period just like #stop" do
      started_at = Time.local(2010, 1, 1, 0, 0, 0)
      paused_at = Time.local(2010, 1, 1, 3, 29, 0)
      task = Factory(:task, :created_at => started_at, :state => "running")
      Timecop.freeze(paused_at) do
        task.pause!
      end
      task.reload
      task.time_periods.size.must == 1
      time_period = task.time_periods.first
      time_period.started_at.must == started_at
      time_period.ended_at.must == paused_at
    end
    it "sets the state to paused and saves" do
      task = Factory.build(:task, :state => "running")
      task.pause!
      task.state.must == "paused"
      task.must_not be_a_new_record
    end
    it "bails if the task hasn't been started yet" do
      task = Factory(:task, :state => "unstarted")
      expect { task.pause! }.to raise_error("Validation failed: You can't pause a task without starting it first!")
    end
    it "bails if the task is stopped" do
      task = Factory(:task, :state => "stopped")
      expect { task.pause! }.to raise_error("Validation failed: It looks like you've already stopped this task.")
    end
    it "bails if the task is completed" do
      task = Factory(:task, :state => "completed")
      expect { task.pause! }.to raise_error("Validation failed: It looks like you've already completed this task.")
    end
  end
  
  describe '#finish!' do
    it "creates a new time period just like #stop if the task was running" do
      started_at = Time.local(2010, 1, 1, 0, 0, 0)
      finished_at = Time.local(2010, 1, 1, 3, 29, 0)
      task = Factory(:task, :created_at => started_at, :state => "running")
      Timecop.freeze(finished_at) do
        task.finish!
      end
      task.reload
      task.time_periods.size.must == 1
      time_period = task.time_periods.first
      time_period.started_at.must == started_at
      time_period.ended_at.must == finished_at
    end
    it "doesn't create a time period if the task was paused" do
      task = Factory(:task, :state => "paused")
      task.finish!
      task.reload
      task.time_periods.size.must == 0
    end
    it "doesn't create a time period if the task was stopped" do
      task = Factory(:task, :state => "stopped")
      task.finish!
      task.reload
      task.time_periods.size.must == 0
    end
    it "sets the state to 'completed' and saves" do
      task = Factory.build(:task, :state => "running")
      task.finish!
      task.state.must == "completed"
      task.must_not be_a_new_record
    end
    it "bails if the task hasn't been started yet" do
      task = Factory(:task, :state => "unstarted")
      expect { task.finish! }.to raise_error("Validation failed: You can't finish a task without starting it first!")
    end
    it "bails if the task is already completed" do
      task = Factory(:task, :state => "completed")
      expect { task.finish! }.to raise_error("Validation failed: It looks like you've already completed this task.")
    end
  end
  
  describe '#resume!' do
    it "sets last_started_at" do
      task = Factory.build(:task, :state => "paused")
      resumed_at = Time.zone.local(2010)
      Timecop.freeze(resumed_at) do
        task.resume!
      end
      task.last_started_at.must == resumed_at
    end
    it "marks the task as running, sets last_started_at, and saves" do
      task = Factory.build(:task, :state => "paused")
      task.resume!
      task.state.must == "running"
      task.must_not be_new
    end
    it "bails if the task hasn't been started yet" do
      task = Factory(:task, :state => "unstarted")
      expect { task.resume! }.to raise_error("Validation failed: You can't resume a task without starting it first!")
    end
    it "bails if the task is still running" do
      task = Factory(:task, :state => "running")
      expect { task.resume! }.to raise_error("Validation failed: Aren't you working on that task already?")
    end
  end
  
  describe '#upvote!' do
    it "increments num_votes and saves the record" do
      task = Factory(:task, :num_votes => 2)
      task.upvote!
      task.upvote!
      task.num_votes.must == 4
    end
  end
  
  describe '#total_running_time' do
    it "adds up the running time for all time periods and returns the time in a readable form" do
      task = Factory(:task)
      task.time_periods << TimeTracker::TimePeriod.new(
        :started_at => Time.local(2010, 1, 1, 0, 0, 0),
        :ended_at => Time.local(2010, 1, 1, 1, 45, 0)
      )
      task.time_periods << TimeTracker::TimePeriod.new(
        :started_at => Time.local(2010, 1, 1, 0, 0, 0),
        :ended_at => Time.local(2010, 1, 1, 2, 30, 0)
      )
      task.total_running_time.must == "4h:15m"
    end
  end
  
  describe '#info' do
    context "if :include_day not given" do
      it "returns an array containing the time the task was last started, and its name, number, and project name" do
        project = TimeTracker::Project.new(:name => "some project")
        task = TimeTracker::Task.new(
          :project => project,
          :number => "1",
          :name => "some task",
          :last_started_at => Time.zone.local(2010, 1, 1, 0, 0)
        )
        task.info.must == [
          [
            Date.new(2010, 1, 1),
            ['', '12:00am', '', ' - ', '', '', '', ' ', '[', '#1', ']', ' ', 'some project / some task (*)']
          ]
        ]
      end
    end
    context "if :include_day given" do
      it "includes the day part" do
        project = TimeTracker::Project.new(:name => "some project")
        task = TimeTracker::Task.new(
          :project => project,
          :number => "1",
          :name => "some task",
          :last_started_at => Time.zone.local(2010, 1, 1, 0, 0)
        )
        task.info(:include_day => true).must ==
          ['1/1/2010', ', ', '12:00am', ' - ', '', '  ', '', ' ', '[', '#1', ']', ' ', 'some project / some task (*)']
      end
    end
    # the time stuff is tested in ruby_spec.rb
  end
  
  describe '#info_for_search' do
    it "returns an array containing the task number, project name, and last started date" do
      project = TimeTracker::Project.new(:name => "some project")
      task = TimeTracker::Task.new(
        :project => project,
        :number => "1",
        :name => "some task",
        :last_started_at => Time.zone.local(2010, 1, 1),
        :state => "stopped"
      )
      task.info_for_search.must ==
        [ "[", "#1", "]", " ", "some project", " / ", "some task", " ", "(last active: ", "1/1/2010)" ]
    end
    it "adds an asterisk after the task name if it's running" do
      project = TimeTracker::Project.new(:name => "some project")
      task = TimeTracker::Task.new(
        :project => project,
        :number => "1",
        :name => "some task",
        :last_started_at => Time.zone.local(2010, 1, 1),
        :state => "running"
      )
      task.info_for_search.must ==
        [ "[", "#1", "]", " ", "some project", " / ", "some task (*)", " ", "(last active: ", "1/1/2010)" ]
    end
  end
end