require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

module IntegrationExampleMethods
  # The actual integration methods are in support/integration_example_methods.rb, so look there.
end

# We would put this in support/integration_example_methods.rb, except that that
# file gets loaded by support/args_parser.rb, in a separate Ruby process,
# and over there, we don't load rspec.
#
# Fortunately in Ruby, even if you mix a module into another one, you can reopen it
# later and add more methods, and they'll get mixed in, too. So this works.
#
Spec::Runner.configuration.include(IntegrationExampleMethods, :type => :integration)