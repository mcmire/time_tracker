require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "The rest" do
  
  scenario "Running a non-existent command" do
    tt 'foo'
    output.lines.must include(%{Oops! "foo" isn't a command. Try one of these instead:})
  end
  
end