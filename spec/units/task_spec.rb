require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Task do
  
  before do
    @task = TimeTracker::Task.new
  end
  
  context "on create" do
    it "gets assigned a number one higher than the last one regardless of project" do
      Factory(:task, :project => Factory(:project)).number.must == 1
      Factory(:task, :project => Factory(:project)).number.must == 2
    end
    it "does not get assigned a number if number is already set" do
      Factory(:task, :number => 18, :project => Factory(:project)).number.must == 18
    end
  end
  
  context "on update" do
    it "doesn't overwrite the number set at creation" do
      task = Factory(:task, :project => Factory(:project))
      number = task.number
      task.save
      task.number.must == number
    end
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
    before do
      @running_task = Factory(:task, :stopped_at => nil)
      @stopped_task = Factory(:task, :stopped_at => Time.now)
    end
    it "includes all tasks which aren't stopped yet" do
      TimeTracker::Task.running.must include(@running_task)
    end
    it "excludes tasks which have been stopped" do
      TimeTracker::Task.running.must_not include(@stopped_task)
    end
  end
  
  describe '.stopped' do
    before do
      @running_task = Factory(:task, :stopped_at => nil)
      @stopped_task = Factory(:task, :stopped_at => Time.now)
    end
    it "includes tasks which have been stopped" do
      TimeTracker::Task.stopped.must include(@stopped_task)
    end
    it "excludes all tasks which aren't stopped yet" do
      TimeTracker::Task.stopped.must_not include(@running_task)
    end
  end
  
  describe '.paused' do
    it "includes tasks which are marked as paused" do
      @paused_task = Factory(:task, :paused => true)
      TimeTracker::Task.paused.must include(@paused_task)
    end
    it "excludes tasks which are not marked as paused" do
      @unpaused_task = Factory(:task, :paused => false)
      TimeTracker::Task.paused.must_not include(@unpaused_task)
    end
  end
  
  describe '.updated_today' do
    before do
      today = Date.today
      @start_of_today = Time.local(today.year, today.month, today.day, 0, 0, 0)
      @end_of_today   = Time.local(today.year, today.month, today.day, 23, 59, 59)
    end
    it "includes tasks updated today" do
      start_of_today_task = Factory(:task, :updated_at => @start_of_today)
      end_of_today_task = Factory(:task, :updated_at => @end_of_today)
      TimeTracker::Task.updated_today.must include(start_of_today_task)
      TimeTracker::Task.updated_today.must include(end_of_today_task)
    end
    it "excludes tasks updated in the past" do
      yesterday_task = Factory(:task, :updated_at => @start_of_today-1)
      TimeTracker::Task.updated_today.must_not include(yesterday_task)
    end
  end
  
  describe '.updated_this_week' do
    before do
      today = Date.today
      sunday = today - today.wday
      saturday = sunday + 6
      @start_of_this_week = Time.local(sunday.year, sunday.month, sunday.day, 0, 0, 0)
      @end_of_this_week   = Time.local(saturday.year, saturday.month, saturday.day, 23, 59, 59)
    end
    it "includes tasks updated this week" do
      start_of_today_task = Factory(:task, :updated_at => @start_of_this_week)
      end_of_today_task = Factory(:task, :updated_at => @end_of_this_week)
      TimeTracker::Task.updated_this_week.must include(start_of_today_task)
      TimeTracker::Task.updated_this_week.must include(end_of_today_task)
    end
    it "excludes tasks updated in the past" do
      yesterday_task = Factory(:task, :updated_at => @start_of_this_week)
      TimeTracker::Task.updated_today.must_not include(yesterday_task)
    end
  end
  
  describe '#running?' do
    it "returns true if stopped_at is not set" do
      @task.created_at = Time.now
      @task.stopped_at = nil
      @task.must be_running
    end
    it "returns false if stopped_at is set" do
      @task.created_at = Time.now
      @task.stopped_at = Time.now
      @task.must_not be_running
    end
    it "returns false if created_at is not set, even if stopped_at is not set" do
      @task.created_at = nil
      @task.stopped_at = nil
      @task.must_not be_running
    end
  end
  
  describe '#stopped?' do
    it "returns true if stopped_at is set" do
      @task.created_at = Time.now
      @task.stopped_at = Time.now
      @task.must be_stopped
    end
    it "returns false if stopped_at is not set" do
      @task.created_at = Time.now
      @task.stopped_at = nil
      @task.must_not be_stopped
    end
    it "returns false if created_at is not set, even if stopped_at is set" do
      @task.created_at = nil
      @task.stopped_at = Time.now
      @task.must_not be_stopped
    end
  end
  
  describe '#stop!' do
    it "records the time the task was stopped and saves it" do
      task = Factory.build(:task)
      time = Time.utc(2010)
      Timecop.freeze(time) do
        task.stop!
      end
      task.stopped_at.must == time
      task.must_not be_a_new_record
    end
  end
  
  describe '#pause!' do
    it "records the time the task was stopped, marks it as paused, and saves it" do
      task = Factory.build(:task)
      time = Time.utc(2010)
      Timecop.freeze(time) do
        task.pause!
      end
      task.stopped_at.must == time
      task.must be_paused
      task.must_not be_new
    end
  end
  
  describe '#resume!' do
    it "marks the task as not paused, unsets stopped_at, and saves" do
      task = Factory.build(:task, :stopped_at => Time.now, :paused => true)
      task.resume!
      task.stopped_at.must == nil
      task.must_not be_paused
      task.must_not be_new
    end
  end
  
  describe '#running_time' do
    it "returns the difference between stopped_at and created_at, formatted" do
      time1 = Time.local(2009)
      time2 = Time.local(2010)
      stub(Time).formatted_diff(time2, time1) { "3h:29m" }
      @task.stopped_at = time2
      @task.created_at = time1
      @task.running_time.must == "3h:29m"
    end
  end
  
  describe '#info' do
    before do
      @project = TimeTracker::Project.new(:name => "some project")
      @task = TimeTracker::Task.new(
        :project => @project,
        :number => 1,
        :name => "some task"
      )
    end
    it "returns the correct string for a running task" do
      @task.stopped_at = nil
      @task.info.must == '#1. some task [some project]'
    end
    it "returns the correct string for a stopped task" do
      @task.created_at = Time.local(2010, 1, 1, 0, 0, 0)
      @task.stopped_at = Time.local(2010, 1, 1, 11, 22, 33)
      @task.info.must == '#1. some task [some project] (stopped at 11h:22m)'
    end
    it "returns the correct string for a paused task" do
      @task.created_at = Time.local(2010, 1, 1, 0, 0, 0)
      @task.stopped_at = Time.local(2010, 1, 1, 11, 22, 33)
      @task.paused = true
      @task.info.must == '#1. some task [some project] (paused at 11h:22m)'
    end
  end
end