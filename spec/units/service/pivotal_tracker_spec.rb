
require_relative '../spec_helper'
require_relative '../../support/extras/webmock'
require_relative '../../support/extras/timecop'
require_relative '../support/models'
require 'tt/models'
require 'tt/service/pivotal_tracker'

describe TimeTracker::Service::PivotalTracker do
  Models = TimeTracker::Models

  def self.pull_task_specs(ctx, &block)
    ctx.class_eval do
      def stub_api_call(type, state)
        body = <<EOT
    <?xml version="1.0" encoding="UTF-8"?>
    <stories type="array" count="10" total="10">
    <story>
      <project_id type="integer">5</project_id>
      <id type="integer">1</id>
      <name>some task</name>
      <story_type>#{type}</story_type>
      <current_state>#{state}</current_state>
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
      described_class::STATES.each do |pt_state, tt_state|
        context "pulling a#{'n' if tt_state =~ /^[aeiou]/} #{tt_state} task" do
          before do
            stub_api_call("feature", pt_state)
          end
          it 'adds any new tasks to the tt database' do
            act!
            a_request(:get, api_url).
              with(:headers => {"X-TrackerToken" => "xxxx"}).
              must have_been_made
            task = Models::Task.first
            task.external_id.must == 1
            task.project.id.must == @project.id if @project
            task.name.must == "some task"
            task.tags.must == ["t:feature"]
            task.state.must == tt_state
            task.created_by.must == "Joe Bloe"
            task.owned_by.must == "John Q. Public"
            task.created_at.must == Time.utc(2010, 1, 2, 3, 4, 5)
            task.updated_at.must == Time.utc(2010, 2, 3, 4, 5, 6)
          end
          it 'updates any modified tasks' do
            task = FactoryGirl.create(:task,
              :external_id => 1,
              :project => @project,
              :name => "some lame task and such as",
              :tags => ["word"]
            )
            act!
            a_request(:get, api_url).
              with(:headers => {"X-TrackerToken" => "xxxx"}).
              must have_been_made
            task.reload
            task.external_id.must == 1
            task.project.id.must == @project.id if @project
            task.name.must == "some task"
            task.tags.must == ["word", "t:feature"]
            task.state.must == tt_state
            task.created_by.must == "Joe Bloe"
            task.owned_by.must == "John Q. Public"
            task.created_at.must == Time.utc(2010, 1, 2, 3, 4, 5)
            task.updated_at.must == Time.utc(2010, 2, 3, 4, 5, 6)
          end
        end
      end
      described_class::TYPES.each do |type|
        context "pulling a #{type}" do
          before do
            stub_api_call(type, "started")
          end
          it 'adds any new tasks to the tt database' do
            act!
            a_request(:get, api_url).
              with(:headers => {"X-TrackerToken" => "xxxx"}).
              must have_been_made
            task = Models::Task.first
            task.external_id.must == 1
            task.project.id.must == @project.id if @project
            task.name.must == "some task"
            task.tags.must == ["t:#{type}"]
            task.state.must == "running"
            task.created_by.must == "Joe Bloe"
            task.owned_by.must == "John Q. Public"
            task.created_at.must == Time.utc(2010, 1, 2, 3, 4, 5)
            task.updated_at.must == Time.utc(2010, 2, 3, 4, 5, 6)
          end
          it 'updates any modified tasks' do
            task = FactoryGirl.create(:task,
              :external_id => 1,
              :project => @project,
              :name => "some lame task and such as",
              :tags => ["word"]
            )
            act!
            a_request(:get, api_url).
              with(:headers => {"X-TrackerToken" => "xxxx"}).
              must have_been_made
            task.reload
            task.external_id.must == 1
            task.project.id.must == @project.id if @project
            task.name.must == "some task"
            task.tags.must == ["word", "t:#{type}"]
            task.state.must == "running"
            task.created_by.must == "Joe Bloe"
            task.owned_by.must == "John Q. Public"
            task.created_at.must == Time.utc(2010, 1, 2, 3, 4, 5)
            task.updated_at.must == Time.utc(2010, 2, 3, 4, 5, 6)
          end
        end
      end
    end
    ctx.class_eval(&block)
  end

  before do
    @service = described_class.new({})
  end

  describe '.new' do
    it "stores the given api key in @api_key" do
      described_class.new(:api_key => "xxxx").api_key.must == "xxxx"
    end
    it "stores the given api key even if key is a string" do
      described_class.new("api_key" => "xxxx").api_key.must == "xxxx"
    end
  end

  describe '#valid?' do
    it "returns true if the credentials are valid" do
      stub_request(:head, "www.pivotaltracker.com/services/v3/activities?limit=1").
        with(:headers => {"X-TrackerToken" => "xxxx"}).
        to_return(:status => 200)
      service = described_class.new(:api_key => "xxxx")
      service.must be_valid
    end
    it "returns false if the credentials are invalid" do
      stub_request(:head, "www.pivotaltracker.com/services/v3/activities?limit=1").
        with(:headers => {"X-TrackerToken" => "xxxx"}).
        to_return(:status => 401)
        service = described_class.new(:api_key => "xxxx")
        service.must_not be_valid
    end
  end

  describe '#pull_tasks!' do
    before do
      @service = described_class.new(:api_key => "xxxx")
    end
    context "given a project object" do
      before do
        @project = FactoryGirl.create(:project, :external_id => 5)
      end
      def act!
        @service.pull_tasks!(@project)
      end
      context "without time last pulled set" do
        pull_task_specs(self) do
          before do
            TimeTracker.world.update("last_pulled_times", nil)
          end
          def api_url
            "www.pivotaltracker.com/services/v3/projects/5/stories"
          end
          it "records the time tasks were pulled, for the given project" do
            Timecop.freeze Time.utc(2010, 1, 5)
            stub_api_call("feature", "finished")
            act!
            TimeTracker.world.reload
            TimeTracker.world["last_pulled_times"]["5"].must == Time.utc(2010, 1, 5)
          end
        end
      end
      context "with time last pulled set" do
        pull_task_specs(self) do
          before do
            TimeTracker.world.update("last_pulled_times", "5" => Time.utc(2010, 1, 5))
          end
          def api_url
            "www.pivotaltracker.com/services/v3/projects/5/stories?modified_since=1/5/2010"
          end
          it "updates the time tasks were pulled, for the given project" do
            Timecop.freeze Time.utc(2010, 1, 5)
            stub_api_call("feature", "finished")
            act!
            TimeTracker.world.reload
            TimeTracker.world["last_pulled_times"]["5"].must == Time.utc(2010, 1, 5)
          end
        end
      end
    end
    context "not given a project object" do
      before do
        @project = FactoryGirl.create(:project, :external_id => 5)
        FactoryGirl.create(:project, :external_id => 10)
        FactoryGirl.create(:project, :external_id => 15)
      end
      def act!
        @service.pull_tasks!
      end
      context "without any times last pulled set" do
        pull_task_specs(self) do
          before do
            TimeTracker.world.update("last_pulled_times", nil)
          end
          def api_url
            "www.pivotaltracker.com/services/v3/stories"
          end
          it "records the time tasks were pulled, for all projects" do
            Timecop.freeze Time.utc(2010, 1, 8)
            stub_api_call("feature", "finished")
            act!
            TimeTracker.world.reload
            TimeTracker.world["last_pulled_times"].must == {
              "5" => Time.utc(2010, 1, 8),
              "10" => Time.utc(2010, 1, 8),
              "15" => Time.utc(2010, 1, 8)
            }
          end
        end
      end
      context "with time last pulled set" do
        pull_task_specs(self) do
          before do
            TimeTracker.world.update("last_pulled_times",
              "5" => Time.utc(2010, 1, 5),
              "10" => Time.utc(2010, 1, 3),
              "15" => Time.utc(2010, 1, 8)
            )
          end

          def api_url
            "www.pivotaltracker.com/services/v3/stories?modified_since=1/3/2010"
          end

          it "updates the time tasks were pulled, for all projects" do
            Timecop.freeze Time.utc(2010, 1, 8)
            stub_api_call("feature", "finished")
            act!
            TimeTracker.world.reload
            TimeTracker.world["last_pulled_times"].must == {
              "5" => Time.utc(2010, 1, 8),
              "10" => Time.utc(2010, 1, 8),
              "15" => Time.utc(2010, 1, 8)
            }
          end
        end
      end
    end
  end

  describe '#check_task_exists!' do
    before do
      @service = described_class.new(:api_key => "xxxx")
      @project = FactoryGirl.create(:project, :external_id => 5)
      @task = FactoryGirl.create(:task, :project => @project, :external_id => 1)
    end
    def stub_api_call(status)
      stub_request(:get, "www.pivotaltracker.com/services/v3/projects/5/stories/1").
        with(:headers => {"X-TrackerToken" => "xxxx"}).
        to_return(:status => status)
    end
    def act!
      @service.check_task_exists!(@task)
    end
    it "hits the API and does nothing if a successful response comes back" do
      stub_api_call(200)
      expect {
        act!
        a_request(:get, "www.pivotaltracker.com/services/v3/projects/5/stories/1").
          with(:headers => {"X-TrackerToken" => "xxxx"}).
          must have_been_made
      }.to_not raise_error
    end
    it "hits the API and throws an error if a 404 comes back" do
      stub_api_call(404)
      expect {
        act!
        a_request(:get, "www.pivotaltracker.com/services/v3/projects/5/stories/1").
          with(:headers => {"X-TrackerToken" => "xxxx"}).
          must have_been_made
      }.to raise_error(TimeTracker::Service::ResourceNotFoundError)
    end
  end

  describe '#push_task!' do
    before do
      @service = described_class.new(:api_key => "xxxx")
      @project = FactoryGirl.create(:project, :external_id => 5)
    end
    [
      ["unstarted", "unscheduled", "feature"],
      ["unstarted", "unscheduled", "bug"],
      ["unstarted", "unscheduled", "chore"],
      ["running", "started", "feature"],
      ["running", "started", "bug"],
      ["running", "started", "chore"],
      ["finished", "accepted", "feature"],
      ["finished", "finished", "bug"],
      ["finished", "finished", "chore"]
    ].each do |tt_state, pt_state, type|
      it "sends a#{'n' if tt_state =~ /^[aeiou]/} #{tt_state} #{type} to Pivotal Tracker correctly" do
        body = <<EOT.strip
<story>
  <name>a task</name>
  <story_type>#{type}</story_type>
  <current_state>#{pt_state}</current_state>
  <requested_by>Joe Bloe</requested_by>
  <owned_by>John Q. Public</owned_by>
  <labels>one fish,two fish</labels>
</story>
EOT
        stub_request(:put, "www.pivotaltracker.com/services/v3/projects/5/stories/1").
          with(:headers => {"X-TrackerToken" => "xxxx"}, :body => body).
          to_return(:status => 200)
        task = FactoryGirl.create(:task,
          :project => @project,
          :external_id => 1,
          :name => "a task",
          :created_by => "Joe Bloe",
          :owned_by => "John Q. Public",
          :state => tt_state,
          :tags => ["t:#{type}", 'one fish', 'two fish'],
          :created_at => Time.utc(2010, 1, 2, 3, 4, 5),
          :updated_at => Time.utc(2010, 2, 3, 4, 5, 6)
        )
        @service.push_task!(task)
        a_request(:put, "www.pivotaltracker.com/services/v3/projects/5/stories/1").
          with(:headers => {"X-TrackerToken" => "xxxx"}, :body => body).
          must have_been_made
      end
    end
  end

  describe '#task_to_xml' do
    described_class::STATES.each do |pt_state, tt_state|
      it "serializes a#{'n' if tt_state =~ /^[aeiou]/} #{tt_state} task correctly" do
        body = <<EOT.strip
<story>
  <name>a task</name>
  <story_type>feature</story_type>
  <current_state>#{pt_state}</current_state>
  <requested_by>Joe Bloe</requested_by>
  <owned_by>John Q. Public</owned_by>
  <labels>one fish,two fish</labels>
</story>
EOT
        project = FactoryGirl.create(:project, :external_id => 5)
        FactoryGirl.create(:task,
          :project => project,
          :external_id => 1,
          :name => "a task",
          :tags => ["t:feature", "one fish", "two fish"],
          :state => tt_state,
          :created_by => "Joe Bloe",
          :owned_by => "John Q. Public",
          :created_at => Time.utc(2010, 1, 2, 3, 4, 5),
          :updated_at => Time.utc(2010, 2, 3, 4, 5, 6)
        )
      end
    end
    described_class::TYPES.each do |type|
      it "serializes a #{type} correctly" do
        body = <<EOT.strip
<story>
  <name>a task</name>
  <story_type>#{type}</story_type>
  <current_state>started</current_state>
  <requested_by>Joe Bloe</requested_by>
  <owned_by>John Q. Public</owned_by>
  <labels>one fish,two fish</labels>
</story>
EOT
        project = FactoryGirl.create(:project, :external_id => 5)
        FactoryGirl.create(:task,
          :project => project,
          :external_id => 1,
          :name => "a task",
          :tags => ["t:#{type}", "one fish", "two fish"],
          :state => "running",
          :created_by => "Joe Bloe",
          :owned_by => "John Q. Public",
          :created_at => Time.utc(2010, 1, 2, 3, 4, 5),
          :updated_at => Time.utc(2010, 2, 3, 4, 5, 6)
        )
      end
    end
  end

  describe '#task_type' do
    it "returns the type of the task which is contained in a tag" do
      task = FactoryGirl.build(:task, :tags => ["t:feature"])
      @service.task_type(task).must == "feature"
    end
    it "returns nil if the task doesn't have a type tag" do
      task = FactoryGirl.build(:task, :tags => ["foo", "bar"])
      @service.task_type(task).must == nil
    end
  end

  describe '#task_state' do
    it "returns unscheduled when the state is unstarted" do
      task = FactoryGirl.build(:task, :state => "unstarted")
      @service.task_state(task).must == "unscheduled"
    end
    it "returns started when the state is running" do
      task = FactoryGirl.build(:task, :state => "running")
      @service.task_state(task).must == "started"
    end
    it "returns accepted if the task is a feature and is finished" do
      task = FactoryGirl.build(:task, :state => "finished", :tags => ["t:feature"])
      @service.task_state(task).must == "accepted"
    end
    it "returns finished if the task is not a feature and is finished" do
      task = FactoryGirl.build(:task, :state => "finished", :tags => ["t:bug"])
      @service.task_state(task).must == "finished"
    end
  end

  describe '#task_labels' do
    it "returns a comma-separated list of tags" do
      task = FactoryGirl.build(:task, :tags => ["one fish", "two fish"])
      @service.task_labels(task).must == "one fish,two fish"
    end
    it "excludes the type tag" do
      task = FactoryGirl.build(:task, :tags => ["t:feature", "one fish", "two fish"])
      @service.task_labels(task).must == "one fish,two fish"
    end
  end

end
