
require 'units/models/spec_helper'
require 'tt/models/project'

describe TimeTracker::Models::Project do

  context "on create" do
    it "adds the project to whichever external service is selected and saves the external id" do
      project = FactoryGirl.create(:project)
      @service = Object.new
      stub(TimeTracker).external_service { @service }
      stub(@project = Object.new).id { 5 }
      mock(@service).add_project!("some project") { @project }
      project = FactoryGirl.create(:project, :name => "some project")
      project.external_id.must == 5
    end
  end

end
