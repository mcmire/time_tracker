#
# Assert that an array is equal to another array, recursively. For instance:
#
#   zing = ["zang", "hullabaloo"]
#   zing == ["zang", /hulla/] #=> false
#   zing.zip(["zang", /ulla/]).all? {|actual, expected| expected === actual } #=> true
#   zing.should deep_equal(["zang", /ulla/]) # same thing, only in matcher form
#
Spec::Matchers.define :smart_match do |expected|
  match do |actual|
    if actual.respond_to?(:zip)
      if actual.size >= expected.size
        actual.zip(expected).all? {|a,e| Proc === e ? e.call(a) : e === a }
      else
        expected.zip(actual).all? {|e,a| Proc === e ? e.call(a) : e === a }
      end
    else
      actual === expected
    end
  end
  failure_message_for_should do |actual|
    "expected\n#{expected.pretty_inspect}to smart match\n#{actual.pretty_inspect}"
  end
  failure_message_for_should_not do |actual|
    "expected\n#{expected.inspect}\nto not be smart matched"
  end
  description do
    "should smart match #{expected.inspect}"
  end
end

# Assert that a string starts with a certain substring.
#
Spec::Matchers.define :start_with do |expected|
  match do |actual|
    actual =~ Regexp.new("^" + Regexp.escape(expected))
  end
  failure_message_for_should do |actual|
    "expected <#{actual.inspect}> to start with <#{expected.inspect}>, but didn't"
  end
  failure_message_for_should_not do
    "expected <#{actual.inspect}> to not start with <#{expected.inspect}>, but it did"
  end
  description do
    "should start with #{expected.inspect}"
  end
end

# Assert that a string starts with a certain substring.
#
Spec::Matchers.define :end_with do |expected|
  match do |actual|
    actual =~ Regexp.new(Regexp.escape(expected) + "$")
  end
  failure_message_for_should do |actual|
    "expected <#{actual.inspect}> to end with <#{expected.inspect}>, but didn't"
  end
  failure_message_for_should_not do
    "expected <#{actual.inspect}> to not end with <#{expected.inspect}>, but it did"
  end
  description do
    "should end with #{expected.inspect}"
  end
end

module ExampleMethods
  
end