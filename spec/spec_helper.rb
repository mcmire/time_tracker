require 'pp'

#require 'spec'
require 'spec/autorun'

require 'bundler'
Bundler.setup
Bundler.require(:default, :test)

require "tt"

Dir['spec/support/**/*.rb'].map {|f| require f }

Kernel.module_eval do
  alias_method :must, :should
  alias_method :must_not, :should_not
  undef_method :should
  undef_method :should_not
end
