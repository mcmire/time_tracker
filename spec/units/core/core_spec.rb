
# require_relative '../spec_helper'

require 'pp'
require_relative '../../support/bundler'
require 'rspec/core'
require 'rspec/expectations'
$:.unshift File.expand_path('../../../../lib', __FILE__)
require_relative '../../support/extras/rr'
require_relative '../../support/must'
require_relative '../../support/matchers'

require 'tt/core/core'

describe TimeTracker::Core do
  let(:world_class) { Module.new }
  let(:project_class) { Module.new }
  let(:service_factory) { Module.new }

  let(:core) {
    # Return a new object instead of using Core directly so that changes
    # to Core (e.g. @external_service) do not have to be tracked and
    # wiped
    Module.new.tap do |mod|
      TimeTracker::Core.hook_into(mod)
      mod._world_class = world_class
      mod._project_class = project_class
      mod._service_factory = service_factory
    end
  }

  describe ".world" do
    it "returns the singleton World instance" do
      stub(world_class).instance { :world }
      core.world.must == :world
    end
  end

  describe '.external_service' do
    let(:world) { {} }
    let(:service_class) {
      Object.new.tap do |o|
        stub(o).new { :service }
      end
    }

    before do
      stub(core).world { world }
      world["external_service"] = "pivotal_tracker"
      world["external_service_options"] = {"api_key" => "xxxx"}
      stub(service_factory).get_service { service_class }
    end

    it "calls the right methods to build the Service object" do
      core.external_service
      service_factory.must have_received.get_service('pivotal_tracker')
      service_class.must have_received.new('api_key' => 'xxxx')
    end

    it "returns the Service object" do
      core.external_service.must == :service
    end

    it "only calls the methods to build the service once" do
      core.external_service
      core.external_service
      service_factory.must have_received.get_service.with_any_args.once
    end
  end
end
