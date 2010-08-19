require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Stopping tasks" do
  story <<-EOT
    I want to be able to mark a task as finished
    so that I can see how long it took me to finish.
  EOT
  
  scenario "Stopping the last task without switching to a project first" do
    tt 'stop'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Stopping the last task without starting a task first" do
    tt 'switch "some project"'
    tt 'stop'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Stopping the last task when all the tasks we've started have been stopped since" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'stop'
    output.must == %{It doesn't look like you're working on anything at the moment.\n}
  end
  scenario "Stopping the last task when none of the tasks in this project have been started yet" do
    tt 'switch "some project"'
    tt 'add task "some task"'
    tt 'add task "another task"'
    tt 'stop'
    output.must == %{It doesn't look like you're working on anything at the moment.\n}
  end
  scenario "Stopping the last task" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    output.must =~ %r{Stopped clock for "some task", at \dm\.\n}
  end
  
  scenario "Stopping a task by name without switching to a project first" do
    tt 'stop "some task"'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Stopping a task by name without starting a task first" do
    tt 'switch "some project"'
    tt 'stop "some task"'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Stopping a task by name" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop "some task"'
    output.must =~ %r{Stopped clock for "some task", at \dm\.\n}
  end
  scenario "Stopping a task by name that has a previous (stopped) instance" do
    with_manual_time_override do
      Timecop.freeze Time.zone.local(2010, 1, 1, 0, 0)
      tt 'switch "some project"'
      tt 'start "some task"'
      stdin << "y\n"
      Timecop.freeze Time.zone.local(2010, 1, 1, 5, 5)
      tt 'stop'
      tt 'start "some task"'
      stdin << "y\n"
      Timecop.freeze Time.zone.local(2010, 1, 1, 10, 10)
      tt 'stop "some task"'
      tt 'list'
    end
    output.lines.must smart_match([
      '',
      'Latest tasks:',
      '',
      ' 5:05am - 10:10am [#2] some project / some task',
      '12:00am -  5:05am [#1] some project / some task',
      ''
    ])
  end
  scenario "Stopping a non-existent task by name" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop "another task"'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Stopping an already stopped task by name" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop "some task"'
    tt 'stop "some task"'
    output.must == %{I think you've stopped that task already.\n}
  end
  scenario "Stopping a paused task by name" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'stop "some task"'
    output.must =~ %r{Stopped clock for "some task".\n}
  end
  scenario "Stopping a task by name without starting it first" do
    tt 'switch "some project"'
    tt 'add task "some task"'
    tt 'stop "some task"'
    output.must == %{You can't stop a task without starting it first!\n}
  end
  
  scenario "Stopping a task by number without switching to a project first" do
    tt 'stop 1'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Stopping a task by number without starting a task first" do
    tt 'switch "some project"'
    tt 'stop 1'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Stopping a task by number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop 1'
    output.must =~ %r{Stopped clock for "some task", at \dm\.\n}
  end
  scenario "Stopping a non-existent task by number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop 2'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Stopping an already stopped task by number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop 1'
    tt 'stop 1'
    output.must == %{I think you've stopped that task already.\n}
  end
  scenario "Stopping a paused task by number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'stop 1'
    output.must =~ %r{Stopped clock for "some task".\n}
  end
  scenario "Stopping a task by number without starting it first" do
    tt 'switch "some project"'
    tt 'add task "some task"'
    tt 'stop 1'
    output.must == %{You can't stop a task without starting it first!\n}
  end
end