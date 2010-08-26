require 'webmock/rspec'

Spec::Runner.configure do |c|
  c.include(WebMock, :type => :integration)
end