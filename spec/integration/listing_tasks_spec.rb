require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Listing tasks" do
  story <<-EOT
    As a programmer,
    I want to be able to pull back and get a list of the tasks in various ways
    in order to see how I'm spending my time
  EOT
  
  scenario "Listing last few tasks with 'list lastfew'" do
    with_manual_time_override do
      Timecop.freeze Time.zone.local(2010, 1, 1, 0, 0)
      tt 'switch "some project"'
      tt 'start "some task"'
      Timecop.freeze Time.zone.local(2010, 1, 2, 5, 5)
      tt 'switch "another project"'
      tt 'start "another task"'
      Timecop.freeze Time.zone.local(2010, 1, 3, 10, 10)
      tt 'resume 1'
      Timecop.freeze Time.zone.local(2010, 1, 3, 15, 15)
      tt 'stop'
      tt 'start "yet another task"'
      tt 'list lastfew'
    end
    output.lines.must smart_match([
      "",
      "Latest tasks:",
      "",
      "    Today,  3:15pm -                    [#3] some project / yet another task (*)",
      "    Today, 10:10am -     Today,  3:15pm [#1] some project / some task",
      "Yesterday,  5:05am -     Today, 10:10am [#2] another project / another task",
      " 1/1/2010, 12:00am - Yesterday,  5:05am [#1] some project / some task",
      ""
    ])
  end
  scenario "Listing last few tasks with just 'list'" do
    with_manual_time_override do
      Timecop.freeze Time.zone.local(2010, 1, 1, 0, 0)
      tt 'switch "some project"'
      tt 'start "some task"'
      Timecop.freeze Time.zone.local(2010, 1, 2, 5, 5)
      tt 'switch "another project"'
      tt 'start "another task"'
      Timecop.freeze Time.zone.local(2010, 1, 3, 10, 10)
      tt 'resume 1'
      Timecop.freeze Time.zone.local(2010, 1, 3, 15, 15)
      tt 'stop'
      tt 'start "yet another task"'
      tt 'list'
    end
    output.lines.must smart_match([
      "",
      "Latest tasks:",
      "",
      "    Today,  3:15pm -                    [#3] some project / yet another task (*)",
      "    Today, 10:10am -     Today,  3:15pm [#1] some project / some task",
      "Yesterday,  5:05am -     Today, 10:10am [#2] another project / another task",
      " 1/1/2010, 12:00am - Yesterday,  5:05am [#1] some project / some task",
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
    with_manual_time_override do
      Timecop.freeze Time.zone.local(2010, 1, 1, 0, 0)
      tt 'switch "some project"'
      tt 'start "some task"'
      Timecop.freeze Time.zone.local(2010, 1, 2, 5, 5)
      tt 'stop'
      tt 'switch "another project"'
      tt 'start "another task"'
      Timecop.freeze Time.zone.local(2010, 1, 3, 10, 10)
      tt 'stop'
      Timecop.freeze Time.zone.local(2010, 1, 3, 15, 15)
      tt 'start "yet another task"'
      tt 'list completed'
    end
    output.lines.must smart_match([
      "",
      "Completed tasks:",
      "",
      "Today:",
      "  (12:00am) -  10:10am  [#2] another project / another task",
      "",
      "Yesterday:",
      "    5:05am  - (11:59pm) [#2] another project / another task",
      "  (12:00am) -   5:05am  [#1] some project / some task",
      "",
      "1/1/2010:",
      "   12:00am  - (11:59pm) [#1] some project / some task",
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
    with_manual_time_override do
      Timecop.freeze Time.zone.local(2010, 1, 1, 0, 0)
      tt 'switch "some project"'
      tt 'start "some task"'
      Timecop.freeze Time.zone.local(2010, 1, 2, 5, 5)
      tt 'switch "another project"'
      tt 'start "another task"'
      Timecop.freeze Time.zone.local(2010, 1, 3, 10, 10)
      tt 'resume 1'
      Timecop.freeze Time.zone.local(2010, 1, 3, 15, 15)
      tt 'stop'
      tt 'start "yet another task"'
      Timecop.freeze Time.zone.local(2010, 1, 4, 20, 20)
      tt 'start "even yet another task"'
      Timecop.freeze Time.zone.local(2010, 1, 5, 1, 1)
      tt 'switch "another project"'
      Timecop.freeze Time.zone.local(2010, 1, 5, 6, 6)
      tt 'start "still yet another task"'
      tt 'list all'
    end
    output.lines.must smart_match([
      "",
      "All tasks:",
      "",
      "Today:",
      "    6:06am  -           [#5] another project / still yet another task (*)",
      "    1:01am  -   6:06am  [#2] another project / another task",
      "  (12:00am) -   1:01am  [#4] some project / even yet another task",
      "",
      "Yesterday:",
      "    8:20pm  - (11:59pm) [#4] some project / even yet another task",
      "  (12:00am) -   8:20pm  [#3] some project / yet another task",
      "",
      "1/3/2010:",
      "    3:15pm  - (11:59pm) [#3] some project / yet another task",
      "   10:10am  -   3:15pm  [#1] some project / some task",
      "  (12:00am) -  10:10am  [#2] another project / another task",
      "",
      "1/2/2010:",
      "    5:05am  - (11:59pm) [#2] another project / another task",
      "  (12:00am) -   5:05am  [#1] some project / some task",
      "",
      "1/1/2010:",
      "   12:00am  - (11:59pm) [#1] some project / some task",
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
      tt 'switch "some project"'
      Timecop.freeze Time.zone.local(2010, 1, 1, 0, 0)
      tt 'start "some task"'
      Timecop.freeze Time.zone.local(2010, 1, 1, 5, 5)
      tt 'start "another task"'
      Timecop.freeze Time.zone.local(2010, 1, 2, 3, 3)
      tt 'stop'
      Timecop.freeze Time.zone.local(2010, 1, 2, 8, 8)
      tt 'switch "another project"'
      tt 'start "yet another task"'
      Timecop.freeze Time.zone.local(2010, 1, 2, 13, 13)
      tt 'resume 1'
      Timecop.freeze Time.zone.local(2010, 1, 2, 18, 18)
      tt 'stop'
      tt 'list today'
    end
    output.lines.must smart_match([
      "",
      "Today's tasks:",
      "",
      "  1:13pm  - 6:18pm [#1] some project / some task",
      "  8:08am  - 1:13pm [#3] another project / yet another task",
      "  3:03am  - 8:08am [#1] some project / some task",
      "(12:00am) - 3:03am [#2] some project / another task",
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
      tt 'switch "some project"'
      Timecop.freeze Time.zone.local(2010, 8, 1, 0, 0)
      tt 'start "some task"'
      Timecop.freeze Time.zone.local(2010, 8, 2, 5, 5)
      tt 'stop'
      tt 'start "another task"'
      Timecop.freeze Time.zone.local(2010, 8, 3, 15, 15)
      tt 'stop'
      tt 'switch "another project"'
      tt 'start "yet another task"'
      Timecop.freeze Time.zone.local(2010, 8, 5, 3, 3)
      tt 'start "even yet another task"'
      tt 'list this week'
    end
    output.lines.must smart_match([
      "",
      "This week's tasks:",
      "",
      "8/1/2010:",
      "   12:00am  - (11:59pm) [#1] some project / some task",
      "",
      "8/2/2010:",
      "  (12:00am) -   5:05am  [#1] some project / some task",
      "    5:05am  - (11:59pm) [#2] some project / another task",
      "",
      "8/3/2010:",
      "  (12:00am) -   3:15pm  [#2] some project / another task",
      "    3:15pm  - (11:59pm) [#3] another project / yet another task",
      "",
      "Yesterday:",
      "  (12:00am) - (11:59pm) [#3] another project / yet another task",
      "",
      "Today:",
      "  (12:00am) -   3:03am  [#3] another project / yet another task",
      "    3:03am  -           [#4] another project / even yet another task (*)",
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