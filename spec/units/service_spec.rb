
require 'units/spec_helper'
require 'tt/service'

module TimeTracker
  module Service
    class PivotalTracker; end
  end
end

describe TimeTracker::Service do

  describe '.get_service' do
    it "returns the class corresponding to the given underscored class name" do
      TimeTracker::Service.get_service("pivotal_tracker").must == TimeTracker::Service::PivotalTracker
    end
  end

end
