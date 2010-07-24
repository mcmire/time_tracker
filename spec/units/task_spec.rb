require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Task do
  
  before do
    @task = TimeTracker::Task.new
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
  
end