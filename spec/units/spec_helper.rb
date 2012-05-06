require_relative '../spec_helper'

module UnitExampleMethods; end
module UnitExampleGroupMethods; end
module UnitExampleGroup
  def self.included(base)
    base.send(:include, UnitExampleMethods)
    base.extend(UnitExampleGroupMethods)
    base.metadata[:type] = :unit
  end
end
RSpec.configure do |c|
  c.include UnitExampleGroup,
    :type => :unit,
    :example_group => { :file_path => 'spec/units' }
  c.before(:suite, :type => :unit) do
    $RUNNING_TESTS = :units
  end
end
