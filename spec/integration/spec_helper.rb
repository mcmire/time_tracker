require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'yaml'

# The rest of the integration example methods are in support/
module IntegrationExampleMethods
  # Stolen from RSpec
  def tt(args)
    #ruby "#{tt_command} #{args}"
    capture_output do
      TimeTracker::Cli.start(parse_args(args))
    end
  end
end

Spec::Runner.configuration.include(IntegrationExampleMethods, :type => :integration)