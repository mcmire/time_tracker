require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Listing tasks" do
  # TODO: Change all commands to list time periods instead of tasks
  
  scenario "Listing last few tasks with 'list lastfew'" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'switch "another project"'
    tt 'start "another task"'
    tt 'resume 1'
    tt 'stop'
    tt 'start "yet another task"'
    tt 'list lastfew'
    output.lines.must smart_match([
      "Last 5 tasks:",
      "#3. yet another task [some project] <==",
      /#1\. some task \[some project\] \(stopped at \ds\)/,
      /#2\. another task \[another project\] \(paused at \ds\)/
    ])
  end
  scenario "Listing last few tasks with just 'list'" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'switch "another project"'
    tt 'start "another task"'
    tt 'resume 1'
    tt 'stop'
    tt 'start "yet another task"'
    tt 'list'
    output.lines.must smart_match([
      "Last 5 tasks:",
      "#3. yet another task [some project] <==",
      /#1\. some task \[some project\] \(stopped at \ds\)/,
      /#2\. another task \[another project\] \(paused at \ds\)/
    ])
  end
  scenario "Listing last few tasks with 'list lastfew' when no tasks created yet" do
    tt 'list lastfew'
    output.must == "It doesn't look like you've started any tasks yet."
  end
  scenario "Listing last few tasks with 'list' when no tasks created yet" do
    tt 'list'
    output.must == "It doesn't look like you've started any tasks yet."
  end
  
  scenario "Listing stopped tasks with 'list completed'" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop'
    tt 'start "another task"'
    tt 'stop'
    tt 'start "yet another task"'
    tt 'list completed'
    output.lines.must smart_match([
      "Completed tasks:",
      /#2\. another task \[some project\] \(stopped at \ds\)/,
      /#1\. some task \[some project\] \(stopped at \ds\)/
    ])
  end
  #scenario "Listing stopped tasks with just 'stopped'"
  scenario "Listing stopped tasks with 'list completed' when no tasks created yet" do
    tt 'list completed'
    output.must == "It doesn't look like you've started any tasks yet."
  end
  #scenario "Listing stopped tasks with 'stopped' when no tasks created yet"
  
  scenario "Listing all tasks with 'list all'" do
    tt 'switch "project 1"'
    tt 'start "task 1"'
    tt 'start "task 2"'
    tt 'start "task 3"'
    tt 'stop'
    tt 'resume 2'
    tt 'switch "project 2"'
    tt 'start "task 4"'
    tt 'start "task 5"'
    tt 'stop'
    tt 'start "task 6"'
    tt 'resume 1'
    tt 'list all'
    output.lines.must smart_match([
      "All tasks:",
      "#1. task 1 [project 1] <==",
      /#6\. task 6 \[project 2\] \(paused at \ds\)/,
      /#5\. task 5 \[project 2\] \(stopped at \ds\)/,
      /#4\. task 4 \[project 2\] \(paused at \ds\)/,
      /#2\. task 2 \[project 1\] \(paused at \ds\)/,
      /#3\. task 3 \[project 1\] \(stopped at \ds\)/,
      /#1\. task 1 \[project 1\] \(paused at \ds\)/
    ])
  end
  #scenario "Listing all tasks with 'all'"
  scenario "Listing all tasks with 'list all' when no tasks created yet" do
    tt 'list all'
    output.must == "It doesn't look like you've started any tasks yet."
  end
  #scenario "Listing all tasks with 'all' when no tasks created yet"
  
  scenario "Listing today's completed tasks with 'list today'" do
    tt 'switch "project 1"'
    Timecop.freeze Time.local(2010, 1, 1)
    tt 'start "task 1"'
    tt 'stop'
    tt 'start "task 2"'
    tt 'stop'
    Timecop.freeze Time.local(2010, 1, 2)
    tt 'start "task 3"'
    tt 'start "task 4"'
    tt 'list today'
    output.lines.must smart_match([
      "Today's tasks:",
      "#4. task 4 [project 1] <==",
      /#3\. task 3 \[project 1\] \(paused at \ds\)/
    ])
  end
  #scenario "Listing today's completed tasks with just 'today'"
  scenario "Listing today's completed tasks with 'list today' when no tasks created yet" do
    tt 'list today'
    output.must == "It doesn't look like you've started any tasks yet."
  end
  #scenario "Listing today's completed tasks with 'completed' when no tasks created yet"
  
  scenario "Listing this week's completed tasks with 'list this week'" do
    tt 'switch "project 1"'
    Timecop.freeze Time.local(2010, 1, 1)
    tt 'start "task 1"'
    tt 'stop'
    tt 'start "task 2"'
    tt 'stop'
    Timecop.freeze Time.local(2010, 1, 7)
    tt 'start "task 3"'
    tt 'start "task 4"'
    tt 'list this week'
    output.lines.must smart_match([
      "This week's tasks:",
      "#4. task 4 [project 1] <==",
      /#3\. task 3 \[project 1\] \(paused at \ds\)/
    ])
  end
  #scenario "Listing today's completed tasks with just 'this week'"
  scenario "Listing this week's completed tasks with 'list this week' when no tasks created yet" do
    tt 'list this week'
    output.must == "It doesn't look like you've started any tasks yet."
  end
  #scenario "Listing today's completed tasks with 'this week' when no tasks created yet"
  
  scenario "Unknown subcommand" do
    tt 'list yourmom'
    output.must =~ /Oops! That isn't the right way to call "list"/
  end
end