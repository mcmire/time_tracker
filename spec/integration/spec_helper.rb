require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

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

  # More of the integration-specific methods are in support/integration_example_methods.rb, so look there.
end

# We would put this in support/integration_example_methods.rb, except that that
# file gets loaded by support/args_parser.rb, in a separate Ruby process,
# and over there, we don't load rspec.
#
# Fortunately in Ruby, even if you mix a module into another one, you can reopen it
# later and add more methods, and they'll get mixed in, too. So this works.
#
Spec::Runner.configure do |c|
  c.include(IntegrationExampleMethods, :type => :integration)
  # If we don't do this and try to run a full spec suite,
  # we get a "too many open files" error after a while
  c.after(:each) { cleanup_open_io }
end
