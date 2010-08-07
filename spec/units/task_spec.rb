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
    #it "sets state to next_state if set" do
    #  Factory(:task, :next_state => "whatever").state.must == "whatever"
    #end
    it "sets state to 'running' by default" do
      Factory(:task).state.must == "running"
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
    #it "sets state to next_state if set" do
    #  task = Factory(:task)
    #  task.update_attributes!(:next_state => "whatever")
    #  task.state.must == "whatever"
    #end
  end
  
  describe '.last' do
    it "returns the last created task regardless of id" do
      project = Factory(:project)
      task1 = Factory(:task, :project => project, :created_at => Time.local(2010, 1, 1))
      task2 = Factory(:task, :project => project, :created_at => Time.local(2010, 1, 4))
      task3 = Factory(:task, :project => project, :created_at => Time.local(2010, 1, 3))
      task4 = Factory(:task, :project => project, :created_at => Time.local(2010, 1, 2))
      TimeTracker::Task.last.must == task2
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
  
  #describe '.all_time_periods_ended_today' do
  #  before do
  #    today = Date.today
  #    @start_of_today = Time.local(today.year, today.month, today.day, 0, 0, 0)
  #    @end_of_today   = Time.local(today.year, today.month, today.day, 23, 59, 59)
  #  end
  #  it "includes periods ended today" do
  #    task = Factory(:task)
  #    start_of_today_period = Factory(:time_period, :ended_at => @start_of_today)
  #    end_of_today_period = Factory(:time_period, :ended_at => @end_of_today)
  #    task.time_periods << start_of_today_period
  #    task.time_periods << end_of_today_period
  #    task.save!
  #    TimeTracker::Task.all_time_periods_ended_today.must include(start_of_today_period)
  #    TimeTracker::Task.all_time_periods_ended_today.must include(end_of_today_period)
  #  end
  #  it "excludes tasks updated in the past" do
  #    yesterday_task = Factory(:time_period, :ended_at => @start_of_today-1)
  #    TimeTracker::Task.all_time_periods_ended_today.must_not include(yesterday_task)
  #  end
  #  it "sorts periods by ended_at" do
  #    task = Factory(:task)
  #    period1 = Factory(:time_period, :ended_at => Time.zone.local(2010, 1, 1, 2, 0, 0))
  #    period2 = Factory(:time_period, :ended_at => Time.zone.local(2010, 1, 1, 13, 30, 0))
  #    period3 = Factory(:time_period, :ended_at => Time.zone.local(2010, 1, 1, 0, 2, 0))
  #    TimeTracker::Task.all_time_periods_ended_today.must == [period3, period1, period2]
  #  end
  #end
  
  #describe '.updated_this_week' do
  #  before do
  #    today = Date.today
  #    sunday = today - today.wday
  #    saturday = sunday + 6
  #    @start_of_this_week = Time.zone.local(sunday.year, sunday.month, sunday.day, 0, 0, 0)
  #    @end_of_this_week   = Time.zone.local(saturday.year, saturday.month, saturday.day, 23, 59, 59)
  #  end
  #  it "includes tasks updated this week" do
  #    start_of_today_task = Factory(:task, :updated_at => @start_of_this_week)
  #    end_of_today_task = Factory(:task, :updated_at => @end_of_this_week)
  #    TimeTracker::Task.updated_this_week.to_a.must include(start_of_today_task)
  #    TimeTracker::Task.updated_this_week.to_a.must include(end_of_today_task)
  #  end
  #  it "excludes tasks updated in the past" do
  #    yesterday_task = Factory(:task, :updated_at => @start_of_this_week-1)
  #    TimeTracker::Task.updated_this_week.to_a.must_not include(yesterday_task)
  #  end
  #end
  
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
  
  describe '#stop!' do
    it "creates a new time period" do
      started_at = Time.local(2010, 1, 1, 0, 0, 0)
      ended_at = Time.local(2010, 1, 1, 3, 29, 0)
      task = Factory.build(:task, :created_at => started_at)
      Timecop.freeze(ended_at) do
        task.stop!
      end
      task.reload
      task.time_periods.size.must == 1
      time_period = task.time_periods.first
      time_period.started_at.must == started_at
      time_period.ended_at.must == ended_at
    end
    it "sets the state to stopped and saves" do
      task = Factory.build(:task)
      task.stop!
      task.state.must == "stopped"
      task.must_not be_a_new_record
    end
  end
  
  describe '#pause!' do
    it "creates a new time period just like #stop" do
      started_at = Time.local(2010, 1, 1, 0, 0, 0)
      paused_at = Time.local(2010, 1, 1, 3, 29, 0)
      task = Factory.build(:task, :created_at => started_at)
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
      task = Factory.build(:task)
      task.pause!
      task.state.must == "paused"
      task.must_not be_a_new_record
    end
  end
  
  describe '#resume!' do
    it "marks the task as running, sets last_started_at, and saves" do
      task = Factory.build(:task, :state => "paused")
      resumed_at = Time.zone.local(2010)
      Timecop.freeze(resumed_at) do
        task.resume!
      end
      task.state.must == "running"
      task.last_started_at.must == resumed_at
      task.must_not be_new
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
    #it "right-aligns the date and time to the given width" do
    #  project = Factory.build(:project, :name => "some project")
    #  task = Factory.build(:task,
    #    :number => 1,
    #    :name => "some task"
    #  )
    #  time = Object.new
    #  
    #  stub(time).to_s(:simpler_date) { "x" * 4 }
    #  stub(task).created_at { time }
    #  task.info(:right_align => 20).must == "                xxxx -                      some task [#1] (in some project)"
    #  
    #  stub(time).to_s(:simpler_date) { "x" * 11 }
    #  stub(task).created_at { time }
    #  task.info(:right_align => 13).must == "  xxxxxxxxxxx -               some task [#1] (in some project)"
    #end
    it "returns an array of strings" do
      project = TimeTracker::Project.new(:name => "some project")
      task = TimeTracker::Task.new(
        :project => project,
        :number => "1",
        :name => "some task",
        :created_at => Time.zone.local(2010, 1, 1, 0, 0)
      )
      task.info.must == ['12:00am', ' - ', '', ' ', 'some task [#1] (in some project) <==']
    end
    it "includes the date only if specified" do
      project = TimeTracker::Project.new(:name => "some project")
      task = TimeTracker::Task.new(
        :project => project,
        :number => "1",
        :name => "some task",
        :created_at => Time.zone.local(2010, 1, 1, 0, 0)
      )
      task.info(:include_date => true).must == ['1/1/2010', ', ', '12:00am', ' - ', '', '', '', ' ', 'some task [#1] (in some project) <==']
    end
    # the time stuff is tested in ruby_spec.rb
  end
end