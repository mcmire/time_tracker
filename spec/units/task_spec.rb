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
  end
  
  context "on update" do
    it "doesn't overwrite the number set at creation" do
      task = Factory(:task, :project => Factory(:project))
      number = task.number
      task.save
      task.number.must == number
    end
  end
  
  describe '#started?' do
    it "returns true if started_at is set" do
      @task.started_at = Time.now
      @task.must be_started
    end
    it "returns false if started_at is not set" do
      @task.started_at = nil
      @task.must_not be_started
    end
  end
  
  describe '#stopped?' do
    it "returns true if stopped_at is set" do
      @task.stopped_at = Time.now
      @task.must be_stopped
    end
    it "returns false if stopped_at is not set" do
      @task.stopped_at = nil
      @task.must_not be_stopped
    end
  end
  
  describe '#running_time' do
    it "returns the difference between stopped_at and started_at, formatted" do
      time1 = Time.local(2009)
      time2 = Time.local(2010)
      stub(Time).formatted_diff(time2, time1) { "3h:29m" }
      @task.stopped_at = time2
      @task.started_at = time1
      @task.running_time.must == "3h:29m"
    end
  end
end