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

  describe '.external_service' do
    it "makes a Service object from the data in config and caches it on first call" do
      TimeTracker.instance_variable_set("@external_service", nil)
      TimeTracker.config["external_service"] = "pivotal_tracker"
      TimeTracker.config["external_service_options"] = {"api_key" => "xxxx"}
      service_klass = stub!.new("api_key" => "xxxx") { :service }
      mock(TimeTracker::Service).get_service("pivotal_tracker") { service_klass }
      TimeTracker.external_service.must == :service
    end
    it "returns the cached Service object on subsequent calls" do
      TimeTracker.instance_variable_set("@external_service", :service)
      TimeTracker.external_service.must == :service
    end
  end
end
