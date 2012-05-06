
require 'webmock/rspec'

RSpec.configure do |c|
  c.include WebMock, :type => :integration
end
