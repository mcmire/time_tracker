require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TimeTracker::Project do

  context "on create" do
    it "adds the project to whichever external service is selected and saves the external id" do
      project = Factory(:project)
      @service = Object.new
      stub(TimeTracker).external_service { @service }
      stub(@project = Object.new).id { 5 }
      mock(@service).add_project!("some project") { @project }
      project = Factory(:project, :name => "some project")
      project.external_id.must == 5
    end
  end

end
