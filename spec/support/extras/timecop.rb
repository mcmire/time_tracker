require 'timecop'

RSpec.configure do |c|
  # Ensure that times we freeze with Timecop are unfrozen
  c.after(:each) { Timecop.return }
end
