require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Managing projects" do
  story <<-EOT
    I want to be able to search for tasks,
    so that I know whether or not I need to upvote a task I've already created,
    or whether I need to create a new one.
  EOT
  
  scenario "Searching for a task without specifying a query" do
    tt 'search'
    output.must == "Okay, but what do you want to search for?\n"
  end
  
  scenario "Searching for a task by one term" do
    Timecop.freeze Time.zone.local(2010, 1, 1, 5, 0, 0)
    tt 'switch "moving to a new apartment"'
    stdin << "y\n"
    tt 'start "pack up the foosball table"'
    stdin << "y\n"
    tt 'finish'
    Timecop.freeze Time.zone.local(2010, 1, 3, 15, 0, 0)
    tt 'start "take out the foo bar"'
    stdin << "y\n"
    #tt 'finish'
    Timecop.freeze Time.zone.local(2010, 1, 7, 21, 0, 0)
    tt 'switch "outside stuff"'
    stdin << "y\n"
    tt 'start "mow the lawn"'
    stdin << "y\n"
    tt 'finish'
    tt 'switch "moving to a new apartment"'
    tt 'resume "take out the foo bar"'
    tt 'search foo'
    output.lines.must smart_match([
      "Search results:",
      "[#2] moving to a new apartment / take out the foo bar (*)   (last active: 1/7/2010)",
      "[#1] moving to a new apartment / pack up the foosball table (last active: 1/1/2010)"
    ])
  end
    
  scenario "Searching for a task by two terms is an OR query" do
    Timecop.freeze Time.zone.local(2010, 1, 1, 5, 0, 0)
    tt 'switch "moving to a new apartment"'
    stdin << "y\n"
    tt 'start "pack up the foosball table"'
    stdin << "y\n"
    tt 'finish'
    Timecop.freeze Time.zone.local(2010, 1, 3, 15, 0, 0)
    tt 'start "take out the foo bar"'
    stdin << "y\n"
    #tt 'finish'
    Timecop.freeze Time.zone.local(2010, 1, 7, 21, 0, 0)
    tt 'switch "outside stuff"'
    stdin << "y\n"
    tt 'start "mow the lawn"'
    stdin << "y\n"
    tt 'finish'
    tt 'switch "moving to a new apartment"'
    tt 'resume "take out the foo bar"'
    tt 'search foo lawn'
    output.lines.must smart_match([
      "Search results:",
      "[#2] moving to a new apartment / take out the foo bar (*)   (last active: 1/7/2010)",
      "[#3] outside stuff             / mow the lawn               (last active: 1/7/2010)",
      "[#1] moving to a new apartment / pack up the foosball table (last active: 1/1/2010)"
    ])
  end
end