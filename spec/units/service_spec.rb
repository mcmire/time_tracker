require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Service do

  describe '.get_service' do
    it "returns the class corresponding to the given underscored class name" do
      TimeTracker::Service.get_service("pivotal_tracker").must == TimeTracker::Service::PivotalTracker
    end
  end

end
