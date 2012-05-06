require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Finishing tasks" do
  story <<-EOT
    I want to be able to mark a task as finished
    so that I can see how long it took me to finish.
  EOT

  scenario "Finishing the last task without switching to a project first" do
    tt 'finish'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Finishing the last task without starting a task first" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'finish'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Finishing the last task when all the tasks we've started have been finished since" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'finish'
    tt 'finish'
    output.must == %{It doesn't look like you're working on anything at the moment.\n}
  end
  scenario "Finishing the last task when none of the tasks in this project have been started yet" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'add task "another task"'
    tt 'finish'
    output.must == %{It doesn't look like you're working on anything at the moment.\n}
  end
  scenario "Finishing the last task" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'finish'
    output.must =~ %r{Stopped clock for "some task", at \dm\.\n}
  end

  scenario "Finishing a task by name without switching to a project first" do
    tt 'finish "some task"'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Finishing a task by name without starting a task first" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'finish "some task"'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Finishing a task by name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'finish "some task"'
    output.must =~ %r{Stopped clock for "some task", at \dm\.\n}
  end
  scenario "Finishing a task by name that has a previous (finished) instance" do
    with_manual_time_override do
      Timecop.freeze Time.zone.local(2010, 1, 1, 0, 0)
      tt 'switch "some project"'
      stdin << "y\n"
      tt 'start "some task"'
      stdin << "y\n"
      Timecop.freeze Time.zone.local(2010, 1, 1, 5, 5)
      tt 'finish'
      tt 'start "some task"'
      stdin << "y\n"
      Timecop.freeze Time.zone.local(2010, 1, 1, 10, 10)
      tt 'finish "some task"'
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
  scenario "Finishing a non-existent task by name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'finish "another task"'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Finishing an already finished task by name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'finish "some task"'
    tt 'finish "some task"'
    output.must == %{It looks like you've already finished this task.\n}
  end
  scenario "Finishing a paused task by name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'finish "some task"'
    output.must =~ %r{Stopped clock for "some task".\n}
  end
  scenario "Finishing a task by name without starting it first" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'finish "some task"'
    output.must == %{You can't finish a task you haven't started yet!\n}
  end

  scenario "Finishing a task by number without switching to a project first" do
    tt 'finish 1'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Finishing a task by number without starting a task first" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'finish 1'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Finishing a task by number" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'finish 1'
    output.must =~ %r{Stopped clock for "some task", at \dm\.\n}
  end
  scenario "Finishing a non-existent task by number" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'finish 2'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Finishing an already finished task by number" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'finish 1'
    tt 'finish 1'
    output.must == %{It looks like you've already finished this task.\n}
  end
  scenario "Finishing a paused task by number" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'finish 1'
    output.must =~ %r{Stopped clock for "some task".\n}
  end
  scenario "Finishing a task by number without starting it first" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'finish 1'
    output.must == %{You can't finish a task you haven't started yet!\n}
  end
end
