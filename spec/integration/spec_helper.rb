
require_relative '../spec_helper'

module IntegrationExampleMethods
  def pt_add_project(name)
    body = <<-EOT
      <?xml version="1.0" encoding="UTF-8"?>
      <project>
        <id>1</id>
        <name>#{name}</name>
      </project>
    EOT
    stub_request(:post, "www.pivotaltracker.com/services/v3/projects").
      with(:headers => {"X-TrackerToken" => "xxxx"}).
      to_return(:body => body, :status => 200)
    tt %{add project "#{project}"}
  end

  # More of the integration-specific methods are in
  # support/integration_example_methods.rb, so look there.
end
module IntegrationExampleGroupMethods; end
module IntegrationExampleGroup
  def self.included(base)
    base.send(:include, IntegrationExampleMethods)
    base.extend(IntegrationExampleGroupMethods)
    base.metadata[:type] = :unit
  end
end
RSpec.configure do |c|
  c.include IntegrationExampleGroup,
    :type => :integration,
    :example_group => { :file_path => 'spec/integration' }
  # If we don't do this and try to run a full spec suite,
  # we get a "too many open files" error after a while
  c.after(:each, :type => :integration) { cleanup_open_io }
end
