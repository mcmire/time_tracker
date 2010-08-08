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
      "Today, 12:12am -         yet another task [#3] (in some project) <==",
      "Today, 12:08am - 12:10am some task        [#1] (in some project)",
      "Today, 12:06am - 12:08am another task     [#2] (in another project)",
      "Today, 12:02am - 12:04am some task        [#1] (in some project)"
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
      "Today, 12:12am -         yet another task [#3] (in some project) <==",
      "Today, 12:08am - 12:10am some task        [#1] (in some project)",
      "Today, 12:06am - 12:08am another task     [#2] (in another project)",
      "Today, 12:02am - 12:04am some task        [#1] (in some project)"
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
      "  12:06am - 12:08am another task [#2] (in some project)",
      "  12:02am - 12:04am some task    [#1] (in some project)"
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
      "  12:22am -         task 1 [#1] (in project 1) <==",
      "  12:20am - 12:22am task 6 [#6] (in project 2)",
      "  12:18am - 12:20am task 4 [#4] (in project 2)",
      "  12:16am - 12:18am task 5 [#5] (in project 2)",
      "  12:14am - 12:16am task 4 [#4] (in project 2)",
      "  12:10am - 12:12am task 1 [#1] (in project 1)",
      "  12:08am - 12:10am task 2 [#2] (in project 1)",
      "  12:06am - 12:08am task 3 [#3] (in project 1)",
      "  12:04am - 12:06am task 2 [#2] (in project 1)",
      "  12:02am - 12:04am task 1 [#1] (in project 1)"
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
      " 7:10am - 3:00pm create report for accounting [#1] (in work project)",
      " 6:00am - 7:10am write documentation          [#3] (in personal project)",
      " 5:00am - 6:00am create report for accounting [#1] (in work project)",
      " 1:00am - 5:00am add notes feature in admin   [#2] (in work project)",
      "12:00am - 1:00am create report for accounting [#1] (in work project)"
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
      "  12:00am - 1:00am task 3 [#3] (in project 1)",
      "   1:00am -        task 4 [#4] (in project 1) <=="
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