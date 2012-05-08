
require 'units/models/spec_helper'
require 'support/extras/timecop'
require 'tt/models/task'

describe TimeTracker::Models::Task do
  Models = TimeTracker::Models

  def Project!(attrs={})
    FG.create(:project, attrs)
  end
  def Task(attrs={})
    attrs = { :project => Project! }.merge(attrs)
    FG.build(:task, attrs)
  end
  def Task!(attrs={})
    attrs = { :project => Project! }.merge(attrs)
    FG.create(:task, attrs)
  end

  before do
    @task = Models::Task.new
  end

  context "on create" do
    it "gets assigned a number one higher than the last one regardless of project" do
      Task!.number.must == 1
      Task!.number.must == 2
    end
    it "does not get assigned a number if number is already set" do
      Task!(:number => 18).number.must == 18
    end
    it "sets last_started_at to created_at" do
      time = Time.local(2010, 1, 1)
      Task!(:created_at => time).last_started_at.must == time
    end
    it "doesn't set last_started_at if last_started_at is already specified" do
      time = Time.local(2010, 1, 1)
      Task!(:last_started_at => time).last_started_at.must == time
    end
    it "sets state to 'created' by default" do
      Task!.state.must == "unstarted"
    end
    it "sets num_votes to 1 by default" do
      Task!.num_votes.must == 1
    end
    it "adds the task to whichever external service is selected and saves the external id" do
      project = Project!
      @service = Object.new
      stub(TimeTracker).external_service { @service }
      stub(@task = Object.new).id { 5 }
      mock(@service).add_Task!(project, "some task") { @task }
      task = Task!(:name => "some task", :project => project)
      task.external_id.must == 5
    end
  end

  context "on update" do
    it "doesn't touch the number set at creation" do
      task = Task!
      number = task.number
      task.save!
      task.reload
      task.number.must == number
    end
    it "doesn't touch the value of last_started_at set at creation" do
      task = Task!
      last_started_at = task.last_started_at
      task.save!
      task.reload
      task.last_started_at == last_started_at
    end
    it "pushes the task to the external service" do
      task = Task!(:external_id => 1)
      mock(@service = Object.new).push_task!(task)
      stub(TimeTracker).external_service { @service }
      task.save!
    end
    it "bails if the task doesn't exist in the external service" do
      task = Task!(:external_id => 1)
      # TODO: This is not a good test?!
      mock(@service = Object.new).push_task!(task) do
        raise 'blah'
      end
      stub(TimeTracker).external_service { @service }
      expect { task.save! }.to raise_error('blah')
    end
  end

  describe '.last_running' do
    it "returns the last created task regardless of id" do
      project = Project!
      task1 = Task!(:project => project, :updated_at => Time.local(2010, 1, 1), :state => "running")
      task2 = Task!(:project => project, :updated_at => Time.local(2010, 1, 4), :state => "running")
      task3 = Task!(:project => project, :updated_at => Time.local(2010, 1, 3), :state => "running")
      task4 = Task!(:project => project, :updated_at => Time.local(2010, 1, 2), :state => "running")
      Models::Task.last_running.must == task2
    end
  end

  describe '.last_paused' do
    it "returns the last created task regardless of id" do
      project = Project!
      task1 = Task!(:project => project, :updated_at => Time.local(2010, 1, 1), :state => "paused")
      task2 = Task!(:project => project, :updated_at => Time.local(2010, 1, 4), :state => "paused")
      task3 = Task!(:project => project, :updated_at => Time.local(2010, 1, 3), :state => "paused")
      task4 = Task!(:project => project, :updated_at => Time.local(2010, 1, 2), :state => "paused")
      Models::Task.last_paused.must == task2
    end
  end

  describe '.running' do
    it "includes tasks which are running" do
      running_task = Task!(:state => "running")
      Models::Task.running.to_a.must include(running_task)
    end
    it "excludes tasks which are not running" do
      paused_task = Task!(:state => "paused")
      Models::Task.running.to_a.must_not include(paused_task)
    end
  end

  describe '.not_running' do
    it "includes tasks which are not running" do
      paused_task = Task!(:state => "paused")
      Models::Task.not_running.to_a.must include(paused_task)
    end
    it "excludes tasks which are running" do
      running_task = Task!(:state => "running")
      Models::Task.not_running.to_a.must_not include(running_task)
    end
  end

  describe '.paused' do
    it "includes tasks which are paused" do
      paused_task = Task!(:state => "paused")
      Models::Task.paused.to_a.must include(paused_task)
    end
    it "excludes tasks which aren't paused" do
      running_task = Task!(:state => "running")
      Models::Task.paused.to_a.must_not include(running_task)
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
      @task.state = "paused"
      @task.must_not be_running
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
      task = Task(:state => "unstarted")
      task.start!
      task.last_started_at.must == time
    end
    it "sets the state to running and saves" do
      task = Task(:state => "unstarted")
      task.start!
      task.state.must == "running"
      task.must_not be_a_new_record
    end
    it "bails if the task is paused" do
      task = Task!(:state => "paused")
      expect { task.start! }.to raise_error("Validation failed: Aren't you still working on that task?")
    end
    it "bails if the task is running" do
      task = Task!(:state => "running")
      expect { task.start! }.to raise_error("Validation failed: Aren't you already working on that task?")
    end
  end

  describe '#pause!' do
    it "creates a new time period just like #finish" do
      started_at = Time.zone.local(2010, 1, 1, 0, 0, 0)
      paused_at = Time.zone.local(2010, 1, 1, 3, 29, 0)
      task = Task!(:created_at => started_at, :state => "running")
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
      task = Task(:state => "running")
      task.pause!
      task.state.must == "paused"
      task.must_not be_a_new_record
    end
    it "bails if the task hasn't been started yet" do
      task = Task!(:state => "unstarted")
      expect { task.pause! }.to raise_error("Validation failed: You can't pause a task you haven't started yet!")
    end
    it "bails if the task is paused" do
      task = Task!(:state => "paused")
      expect { task.pause! }.to raise_error("Validation failed: It looks like you've already paused this task.")
    end
    it "bails if the task is finished" do
      task = Task!(:state => "finished")
      expect { task.pause! }.to raise_error("Validation failed: It looks like you've already finished this task.")
    end
  end

  describe '#finish!' do
    it "creates a new time period just like #finish if the task was running" do
      started_at = Time.zone.local(2010, 1, 1, 0, 0, 0)
      finished_at = Time.zone.local(2010, 1, 1, 3, 29, 0)
      task = Task!(:created_at => started_at, :state => "running")
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
      task = Task!(:state => "paused")
      task.finish!
      task.reload
      task.time_periods.size.must == 0
    end
    it "sets the state to 'finished' and saves" do
      task = Task(:state => "running")
      task.finish!
      task.state.must == "finished"
      task.must_not be_a_new_record
    end
    it "bails if the task hasn't been started yet" do
      task = Task!(:state => "unstarted")
      expect { task.finish! }.to raise_error("Validation failed: You can't finish a task you haven't started yet!")
    end
    it "bails if the task is already finished" do
      task = Task!(:state => "finished")
      expect { task.finish! }.to raise_error("Validation failed: It looks like you've already finished this task.")
    end
  end

  describe '#resume!' do
    it "sets last_started_at" do
      task = Task(:state => "paused")
      resumed_at = Time.zone.local(2010)
      Timecop.freeze(resumed_at) do
        task.resume!
      end
      task.last_started_at.must == resumed_at
    end
    it "marks the task as running, sets last_started_at, and saves" do
      task = Task(:state => "paused")
      task.resume!
      task.state.must == "running"
      task.must_not be_new
    end
    it "bails if the task hasn't been started yet" do
      task = Task!(:state => "unstarted")
      expect { task.resume! }.to raise_error("Validation failed: You can't resume a task you haven't started yet!")
    end
    it "bails if the task is still running" do
      task = Task!(:state => "running")
      expect { task.resume! }.to raise_error("Validation failed: Aren't you working on that task already?")
    end
  end

  describe '#upvote!' do
    it "increments num_votes and saves the record" do
      task = Task!(:num_votes => 2)
      task.upvote!
      task.upvote!
      task.num_votes.must == 4
    end
  end

  describe '#total_running_time' do
    it "adds up the running time for all time periods and returns the time in a readable form" do
      task = Task!
      task.time_periods << Models::TimePeriod.new(
        :started_at => Time.local(2010, 1, 1, 0, 0, 0),
        :ended_at => Time.local(2010, 1, 1, 1, 45, 0)
      )
      task.time_periods << Models::TimePeriod.new(
        :started_at => Time.local(2010, 1, 1, 0, 0, 0),
        :ended_at => Time.local(2010, 1, 1, 2, 30, 0)
      )
      task.total_running_time.must == "4h:15m"
    end
  end

  describe '#info' do
    context "if :include_day not given" do
      it "returns an array containing the time the task was last started, and its name, number, and project name" do
        project = Models::Project.new(:name => "some project")
        task = Models::Task.new(
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
        project = Models::Project.new(:name => "some project")
        task = Models::Task.new(
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
      project = Models::Project.new(:name => "some project")
      task = Models::Task.new(
        :project => project,
        :number => "1",
        :name => "some task",
        :last_started_at => Time.zone.local(2010, 1, 1),
        :state => "paused"
      )
      task.info_for_search.must ==
        [ "[", "#1", "]", " ", "some project", " / ", "some task", " ", "(last active: ", "1/1/2010)" ]
    end
    it "adds an asterisk after the task name if it's running" do
      project = Models::Project.new(:name => "some project")
      task = Models::Task.new(
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
