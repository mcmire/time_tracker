
# Remove the lack of confidence from RSpec's language
# (Copied from Thor specs)
Kernel.module_eval do
  alias_method :must, :should
  alias_method :must_not, :should_not
  undef_method :should
  undef_method :should_not
end
