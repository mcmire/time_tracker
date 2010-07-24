require 'pp'

#require 'spec'
require 'spec/autorun'

require 'bundler'
Bundler.setup
Bundler.require(:default, :test)

require "tt"
require "tt/mongo_mapper"

Dir['spec/support/**/*.rb'].map {|f| require f }

Kernel.module_eval do
  alias_method :must, :should
  alias_method :must_not, :should_not
  undef_method :should
  undef_method :should_not
end

Spec::Runner.configuration.before(:each, :type => :units) do
  $RUNNING_TESTS = :units
end
Spec::Runner.configuration.before(:each, :type => :integration) do
  $RUNNING_TESTS = :integration
end