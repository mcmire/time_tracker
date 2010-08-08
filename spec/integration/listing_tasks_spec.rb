require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Listing tasks" do
  story <<-EOT
    As a programmer,
    I want to be able to pull back and get a list of the tasks in various ways
    in order to see how I'm spending my time
  EOT
  
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
      "",
      "Latest tasks:",
      "",
      "Today, 12:12am -         [#3]    some project / yet another task <==",
      "Today, 12:08am - 12:10am [#1]    some project / some task",
      "Today, 12:06am - 12:08am [#2] another project / another task",
      "Today, 12:02am - 12:04am [#1]    some project / some task",
      ""
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
      "",
      "Latest tasks:",
      "",
      "Today, 12:12am -         [#3]    some project / yet another task <==",
      "Today, 12:08am - 12:10am [#1]    some project / some task",
      "Today, 12:06am - 12:08am [#2] another project / another task",
      "Today, 12:02am - 12:04am [#1]    some project / some task",
      ""
    ])
  end
  scenario "Listing last few tasks with 'list lastfew' when no tasks created yet" do
    tt 'list lastfew'
    output.must == "It doesn't look like you've started any tasks yet.\n"
  end
  scenario "Listing last few tasks with 'list' when no tasks created yet" do
    tt 'list'
    output.must == "It doesn't look like you've started any tasks yet.\n"
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
      "",
      "Completed tasks:",
      "",
      "Today:",
      "  12:06am - 12:08am [#2] some project / another task",
      "  12:02am - 12:04am [#1] some project / some task",
      ""
    ])
  end
  #scenario "Listing stopped tasks with just 'stopped'"
  scenario "Listing stopped tasks with 'list completed' when no tasks created yet" do
    tt 'list completed'
    output.must == "It doesn't look like you've started any tasks yet.\n"
  end
  #scenario "Listing stopped tasks with 'stopped' when no tasks created yet"
  
  scenario "Listing all tasks with 'list all'" do
    tt 'switch "project 1"'
    tt 'start "task 1"'
    tt 'start "task 2"'
    tt 'start "task 3"'
    tt 'stop'
    tt 'resume 1'
    tt 'switch "project 2"'
    tt 'start "task 4"'
    tt 'start "task 5"'
    tt 'stop'
    tt 'start "task 6"'
    tt 'resume 1'
    tt 'list all'
    output.lines.must smart_match([
      "",
      "All tasks:",
      "",
      "Today:",
      "  12:22am -         [#1] project 1 / task 1 <==",
      "  12:20am - 12:22am [#6] project 2 / task 6",
      "  12:18am - 12:20am [#4] project 2 / task 4",
      "  12:16am - 12:18am [#5] project 2 / task 5",
      "  12:14am - 12:16am [#4] project 2 / task 4",
      "  12:10am - 12:12am [#1] project 1 / task 1",
      "  12:08am - 12:10am [#2] project 1 / task 2",
      "  12:06am - 12:08am [#3] project 1 / task 3",
      "  12:04am - 12:06am [#2] project 1 / task 2",
      "  12:02am - 12:04am [#1] project 1 / task 1",
      ""
    ])
  end
  #scenario "Listing all tasks with 'all'"
  scenario "Listing all tasks with 'list all' when no tasks created yet" do
    tt 'list all'
    output.must == "It doesn't look like you've started any tasks yet.\n"
  end
  #scenario "Listing all tasks with 'all' when no tasks created yet"
  
  scenario "Listing today's completed tasks with 'list today'" do
    with_manual_time_override do
      tt 'switch "work project"'
      Timecop.freeze Time.zone.local(2010, 1, 1, 0, 0, 0)
      tt 'start "create report for accounting"'
      Timecop.freeze Time.zone.local(2010, 1, 1, 1, 0, 0)
      tt 'start "add notes feature in admin"'
      Timecop.freeze Time.zone.local(2010, 1, 1, 5, 0, 0)
      tt 'stop'
      Timecop.freeze Time.zone.local(2010, 1, 1, 6, 0, 0)
      tt 'switch "personal project"'
      tt 'start "write documentation"'
      Timecop.freeze Time.zone.local(2010, 1, 1, 7, 10, 0)
      tt 'resume 1'
      Timecop.freeze Time.zone.local(2010, 1, 1, 15, 0, 0)
      tt 'stop'
      tt 'list today'
    end
    output.lines.must smart_match([
      "",
      "Today's tasks:",
      "",
      " 7:10am - 3:00pm [#1]     work project / create report for accounting",
      " 6:00am - 7:10am [#3] personal project / write documentation",
      " 5:00am - 6:00am [#1]     work project / create report for accounting",
      " 1:00am - 5:00am [#2]     work project / add notes feature in admin",
      "12:00am - 1:00am [#1]     work project / create report for accounting",
      ""
    ])
  end
  #scenario "Listing today's completed tasks with just 'today'"
  scenario "Listing today's completed tasks with 'list today' when no tasks created yet" do
    tt 'list today'
    output.must == "It doesn't look like you've started any tasks yet.\n"
  end
  #scenario "Listing today's completed tasks with 'completed' when no tasks created yet"
  
  scenario "Listing this week's completed tasks with 'list this week'" do
    with_manual_time_override do
      tt 'switch "project 1"'
      Timecop.freeze Time.zone.local(2010, 1, 1)
      tt 'start "task 1"'
      tt 'stop'
      tt 'start "task 2"'
      tt 'stop'
      Timecop.freeze Time.zone.local(2010, 1, 7, 0, 0, 0)
      tt 'start "task 3"'
      Timecop.freeze Time.zone.local(2010, 1, 7, 1, 0, 0)
      tt 'start "task 4"'
      tt 'list this week'
    end
    output.lines.must smart_match([
      "",
      "This week's tasks:",
      "",
      "Today:",
      "  12:00am - 1:00am [#3] project 1 / task 3",
      "   1:00am -        [#4] project 1 / task 4 <==",
      ""
    ])
  end
  #scenario "Listing today's completed tasks with just 'this week'"
  scenario "Listing this week's completed tasks with 'list this week' when no tasks created yet" do
    tt 'list this week'
    output.must == "It doesn't look like you've started any tasks yet.\n"
  end
  #scenario "Listing today's completed tasks with 'this week' when no tasks created yet"
  
  scenario "Unknown subcommand" do
    tt 'list yourmom'
    output.must =~ /Oops! That isn't the right way to call "list"/
  end
end