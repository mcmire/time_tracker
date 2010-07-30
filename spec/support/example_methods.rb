# Add a way to assert that an array is equal to another array, recursively. For instance:
#
#   zing = ["zang", "hullabaloo"]
#   zing == ["zang", /hulla/] #=> false
#   zing.zip(["zang", /ulla/]).all? {|actual, expected| expected === actual } #=> true
#   zing.should deep_equal(["zang", /ulla/]) # same thing, only in matcher form
#
Spec::Matchers.define :smart_match do |expected|
  match do |actual|
    if actual.respond_to?(:zip)
      actual.zip(expected).all? {|a,e| Proc === e ? e.call(a) : e === a }
    else
      actual === expected
    end
  end
  failure_message_for_should do |actual|
    "expected\n#{expected.pretty_inspect}\nto smart match\n#{actual.inspect}"
  end
  failure_message_for_should_not do |actual|
    "expected\n#{expected.inspect}\nto not be smart matched"
  end
  description do
    "should smart match #{expected.inspect}"
  end
end

module ExampleMethods
  
end