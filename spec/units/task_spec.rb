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
    before do
      @paused_task = Factory(:task, :paused => true)
      @unpaused_task = Factory(:task, :paused => false)
    end
    it "includes tasks which are marked as paused" do
      TimeTracker::Task.paused.must include(@paused_task)
    end
    it "excludes tasks which are not marked as paused" do
      TimeTracker::Task.paused.must_not include(@unpaused_task)
    end
  end
  
  describe '#running?' do
    it "returns true if stopped_at is not set" do
      stub(@task).new_record? { false }
      @task.stopped_at = nil
      @task.must be_running
    end
    it "returns false if stopped_at is set" do
      stub(@task).new_record? { false }
      @task.stopped_at = Time.now
      @task.must_not be_running
    end
    it "returns false for a new record even if stopped_at is not set" do
      @task.stopped_at = nil
      @task.must_not be_running
    end
  end
  
  describe '#stopped?' do
    it "returns true if stopped_at is set" do
      stub(@task).new_record? { false }
      @task.stopped_at = Time.now
      @task.must be_stopped
    end
    it "returns false if stopped_at is not set" do
      stub(@task).new_record? { false }
      @task.stopped_at = nil
      @task.must_not be_stopped
    end
    it "returns false for a new record even if stopped_at is set" do
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
end