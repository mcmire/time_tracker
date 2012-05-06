
require 'pp'
require_relative 'support/bundler'

#---

require 'rspec/core'
require 'rspec/expectations'

module ExampleMethods; end
module ExampleGroupMethods; end
RSpec.configure do |c|
  c.include ExampleMethods
  c.extend  ExampleGroupMethods
end


#---

$:.unshift File.expand_path('../../lib', __FILE__)

require 'tt/core'
TimeTracker.config.environment = :test
TimeTracker.setup

#---

require_relative 'support/extras/rr'
require_relative 'support/must'
require_relative 'support/matchers'
