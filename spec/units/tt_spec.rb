require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker do
  describe ".config" do
    it "calls Config.find and caches the value" do
      TimeTracker.instance_variable_set("@config", nil)
      mock.proxy(TimeTracker).reload_config.once
      ret = TimeTracker.config
      ret = TimeTracker.config
      ret.must be_a(TimeTracker::Config)
    end
  end
  
  describe '.reload_config' do
    it "re-runs the query to fetch the config data every time" do
      mock(TimeTracker::Config).find { :config }.twice
      ret = TimeTracker.reload_config
      ret = TimeTracker.reload_config
      ret.must == :config
    end
  end
end