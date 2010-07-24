require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker do
  describe ".config" do
    it "calls Config.find and caches the value" do
      mock(TimeTracker::Config).find { :config }.once
      ret = TimeTracker.config
      ret = TimeTracker.config
      ret.must == :config
    end
  end
end