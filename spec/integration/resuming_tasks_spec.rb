require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Resuming tasks" do
  story <<-EOT
    I want to be able to tell the system that I've resumed work on a task
    so that I can continue to track its time
  EOT
  
  scenario "Resuming a task without specifying a name" do
    tt 'resume'
    output.must == "Yes, but which task do you want to resume? (I'll accept a number or a name.)\n"
  end
  
  scenario "Resuming a task by name without switching to a project first" do
    tt 'resume "some task"'
    output.must == "Try switching to a project first.\n"
  end
  scenario "Resuming a task by name when no tasks exist at all" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Resuming a non-existent task by name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'resume "yet another task"'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Resuming a paused task by name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.must =~ %r{Resumed clock for "some task"\.}
  end
  scenario "Resuming a paused task by name that may exist in other projects but not here" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    stdin << "y\n"
    tt 'switch "another project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'switch "a different project"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.must == %{That task doesn't exist here. Perhaps you meant to switch to "another project"?\n}
  end
  scenario "Resuming a task by name that has a previous (stopped) instance" do
    with_manual_time_override do
      Timecop.freeze Time.zone.local(2010, 1, 1, 0, 0)
      tt 'switch "some project"'
      stdin << "y\n"
      tt 'start "some task"'
      stdin << "y\n"
      Timecop.freeze Time.zone.local(2010, 1, 1, 5, 5)
      tt 'stop'
      tt 'start "some task"'
      stdin << "y\n"
      Timecop.freeze Time.zone.local(2010, 1, 1, 10, 10)
      tt 'start "another task"'
      stdin << "y\n"
      Timecop.freeze Time.zone.local(2010, 1, 1, 15, 15)
      tt 'resume "some task"'
      tt 'list'
    end
    output.lines.must smart_match([
      '',
      'Latest tasks:',
      '',
      ' 3:15pm -         [#2] some project / some task (*)',
      '10:10am -  3:15pm [#3] some project / another task',
      ' 5:05am - 10:10am [#2] some project / some task',
      '12:00am -  5:05am [#1] some project / some task',
      ''
    ])
  end
  scenario "Resuming a stopped task by name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'resume "some task"'
    output.must == %{Resumed clock for "some task".\n}
  end
  scenario "Resuming a stopped task by name that may exist in other projects but not here" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'switch "another project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'switch "a different project"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.must == %{That task doesn't exist here. Perhaps you meant to switch to "another project"?\n}
  end
  scenario "Resuming a running task by name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.must == %{Aren't you working on that task already?\n}
  end
  scenario "Resuming a task by name that hasn't been started yet" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'resume "some task"'
    output.must == %{You can't resume a task that you haven't started yet!\n}
  end
  
  scenario "Resuming a task by number without switching to a project first" do
    tt 'resume 1'
    output.must == "Try switching to a project first.\n"
  end
  scenario "Resuming a task by number when no tasks exist" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'resume 1'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Resuming a non-existent task by number" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'resume 2'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Resuming a paused task by number" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'resume 1'
    output.must =~ %r{Resumed clock for "some task".}
  end
  scenario "Resuming a stopped task by number" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'resume 1'
    output.must == %{Resumed clock for "some task".\n}
  end
  scenario "Resuming a running task by number" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'resume 1'
    output.must == %{Aren't you working on that task already?\n}
  end
  scenario "Resuming a task by number that hasn't been started yet" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'resume 1'
    output.must == %{You can't resume a task that you haven't started yet!\n}
  end
end