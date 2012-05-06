
require 'rr'
require 'rr/adapters/rspec2'

# RSpec 2 doesn't have support for RR.
#
# See:
# * https://github.com/btakita/rr/issues/45
# * https://github.com/rspec/rspec-core/issues/136
#
module RSpec
  module Core
    module MockFrameworkAdapter
      include RR::Adapters::RSpec2
    end
  end
end

RSpec.configure do |c|
  c.mock_framework = RSpec::Core::MockFrameworkAdapter
  c.backtrace_clean_patterns.push(RR::Errors::BACKTRACE_IDENTIFIER)
end
