require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe TimeTracker::Service::PivotalTracker do
  
  describe '.new' do
    it "stores the given api key in @api_key" do
      TimeTracker::Service::PivotalTracker.new(:api_key => "xxxx").api_key.must == "xxxx"
    end
    it "stores the given api key even if key is a string" do
      TimeTracker::Service::PivotalTracker.new("api_key" => "xxxx").api_key.must == "xxxx"
    end
  end
  
  describe '#valid?' do
    it "returns true if the credentials are valid" do
      stub_request(:head, "www.pivotaltracker.com/services/v3/activities?limit=1").
        with(:headers => {"X-TrackerToken" => "xxxx"}).
        to_return(:status => 200)
      service = TimeTracker::Service::PivotalTracker.new(:api_key => "xxxx")
      service.must be_valid
    end
    it "returns false if the credentials are invalid" do
      stub_request(:head, "www.pivotaltracker.com/services/v3/activities?limit=1").
        with(:headers => {"X-TrackerToken" => "xxxx"}).
        to_return(:status => 401)
        service = TimeTracker::Service::PivotalTracker.new(:api_key => "xxxx")
        service.must_not be_valid
    end
  end
  
  describe '#pull_tasks' do
    before do
      @service = TimeTracker::Service::PivotalTracker.new(:api_key => "xxxx")
    end
    context "pull_tasks specs", :shared => true do
      def stub_api_call(pt_type, pt_state)
        body = <<-EOT
          <?xml version="1.0" encoding="UTF-8"?>
          <stories type="array" count="10" total="10">
            <story>
              <project_id type="integer">5</project_id>
              <id type="integer">1</id>
              <name>some task</name>
              <story_type>#{pt_type}</story_type>
              <current_state>#{pt_state}</current_state>
              <requested_by>Joe Bloe</requested_by>
              <owned_by>John Q. Public</owned_by>
              <created_at type="datetime">2010/01/02 03:04:05 UTC</created_at>
              <updated_at type="datetime">2010/02/03 04:05:06 UTC</updated_at>
              <description>this task needs to do stuff</description>
              <estimate type="integer">1</estimate>
              <url>http://www.pivotaltracker.com/story/show/1</url>
              <labels>one fish,two fish,red fish,blue fish</labels>
            </story>
          </stories>
        EOT
        stub_request(:get, api_url).
          with(:headers => {"X-TrackerToken" => "xxxx"}).
          to_return(:status => 200, :body => body)
      end
      
      {
        "unscheduled" => "unstarted",
        "unstarted" => "unstarted",
        "started" => "running",
        "finished" => "finished",
        "delivered" => "finished",
        "accepted" => "finished",
        "rejected" => "finished"
      }.each do |pt_state, tt_state|
        %w(feature bug chore).each do |pt_type|
          context "pulling a#{'n' if pt_state =~ /^[aeiou]/} #{pt_state} #{pt_type}" do
            before do
              stub_api_call(pt_type, pt_state)
            end
            it 'adds any new tasks to the tt database' do
              act!
              task = TimeTracker::Task.first
              task.external_id.must == 1
              task.project.id.must == @project.id if @project
              task.name.must == "some task"
              task.tags.must == ["t:#{pt_type}"]
              task.state.must == tt_state
              task.created_by.must == "Joe Bloe"
              task.owned_by.must == "John Q. Public"
              task.created_at.must == Time.utc(2010, 1, 2, 3, 4, 5)
              task.updated_at.must == Time.utc(2010, 2, 3, 4, 5, 6)
            end
            it 'updates any modified tasks' do
              task = Factory(:task,
                :external_id => 1,
                :project => @project,
                :name => "some lame task and such as",
                :tags => ["word"]
              )
              act!
              task.reload
              task.external_id.must == 1
              task.project.id.must == @project.id if @project
              task.name.must == "some task"
              task.tags.must == ["word", "t:#{pt_type}"]
              task.state.must == tt_state
              task.created_by.must == "Joe Bloe"
              task.owned_by.must == "John Q. Public"
              task.created_at.must == Time.utc(2010, 1, 2, 3, 4, 5)
              task.updated_at.must == Time.utc(2010, 2, 3, 4, 5, 6)
            end
          end
        end
      end
    end
    context "given a project object" do
      before do
        @project = Factory(:project, :external_id => 5)
      end
      def act!
        @service.pull_tasks(@project)
      end
      context "without time last pulled set" do
        before do
          TimeTracker.config.update("last_pulled_times", nil)
        end
        def api_url
          "www.pivotaltracker.com/services/v3/projects/5/stories"
        end
        it_should_behave_like "pull_tasks specs"
        it "records the time tasks were pulled, for the given project" do
          Timecop.freeze Time.utc(2010, 1, 5)
          stub_api_call("feature", "finished")
          act!
          TimeTracker.reload_config
          TimeTracker.config["last_pulled_times"]["5"].must == Time.utc(2010, 1, 5)
        end
      end
      context "with time last pulled set" do
        before do
          TimeTracker.config.update("last_pulled_times", "5" => Time.utc(2010, 1, 5))
        end
        def api_url
          "www.pivotaltracker.com/services/v3/projects/5/stories?modified_since=1/5/2010"
        end
        it_should_behave_like "pull_tasks specs"
        it "updates the time tasks were pulled, for the given project" do
          Timecop.freeze Time.utc(2010, 1, 5)
          stub_api_call("feature", "finished")
          act!
          TimeTracker.reload_config
          TimeTracker.config["last_pulled_times"]["5"].must == Time.utc(2010, 1, 5)
        end
      end
    end
    context "not given a project object" do
      before do
        @project = Factory(:project, :external_id => 5)
        Factory(:project, :external_id => 10)
        Factory(:project, :external_id => 15)
      end
      def act!
        @service.pull_tasks
      end
      context "without any times last pulled set" do
        before do
          TimeTracker.config.update("last_pulled_times", nil)
        end
        def api_url
          "www.pivotaltracker.com/services/v3/stories"
        end
        it_should_behave_like "pull_tasks specs"
        it "records the time tasks were pulled, for all projects" do
          Timecop.freeze Time.utc(2010, 1, 8)
          stub_api_call("feature", "finished")
          act!
          TimeTracker.reload_config
          TimeTracker.config["last_pulled_times"].must == {
            "5" => Time.utc(2010, 1, 8),
            "10" => Time.utc(2010, 1, 8),
            "15" => Time.utc(2010, 1, 8)
          }
        end
      end
      context "with time last pulled set" do
        before do
          TimeTracker.config.update("last_pulled_times",
            "5" => Time.utc(2010, 1, 5),
            "10" => Time.utc(2010, 1, 3),
            "15" => Time.utc(2010, 1, 8)
          )
        end
        def api_url
          "www.pivotaltracker.com/services/v3/stories?modified_since=1/3/2010"
        end
        it_should_behave_like "pull_tasks specs"
        it "updates the time tasks were pulled, for all projects" do
          Timecop.freeze Time.utc(2010, 1, 8)
          stub_api_call("feature", "finished")
          act!
          TimeTracker.reload_config
          TimeTracker.config["last_pulled_times"].must == {
            "5" => Time.utc(2010, 1, 8),
            "10" => Time.utc(2010, 1, 8),
            "15" => Time.utc(2010, 1, 8)
          }
        end
      end
    end
  end

end