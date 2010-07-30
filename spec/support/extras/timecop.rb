require 'timecop'

Spec::Runner.configuration.after(:each) do
  # Ensure that times we freeze with Timecop are unfrozen
  Timecop.return
end