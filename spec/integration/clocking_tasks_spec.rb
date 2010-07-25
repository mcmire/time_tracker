require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Starting, stopping, and resuming tasks" do
  story <<-EOT
    As a programmer,
    I want to be able to keep track of how long it takes for me to do stuff,
    so that I can review it later and see how I spend my time,
    and so that I can be more efficient at my job.
  EOT
  
  scenario "Starting a task" do
    tt 'switch "some project"'
    tt 'start "some task"'
    output.must == %{Started clock for "some task".}
  end
  scenario "Starting a task without switching to a project first" do
    tt 'start "some task"'
    output.must == %{Try switching to a project first.}
  end
  scenario "Running 'tt start' without specifying a name" do
    tt 'start'
    output.must == %{Right, but what's the name of your task?}
  end
  scenario "Starting the same task after it's been started" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'start "some task"'
    output.must == %{Aren't you already working on that task?}
  end
  scenario "Starting a task while another one is running" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'start "another task"'
    output.must == %{Started clock for "another task".\n(You're now working on 2 tasks.)}
  end
  #scenario "Starting a task that I've already stopped"
  
  scenario "Stopping the last task" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop'
    output.must =~ %r{Stopped clock for "some task", at \ds\.}
  end
  scenario "Stopping the last task without switching to a project first" do
    tt 'stop'
    output.must == %{Try switching to a project first.}
  end
  scenario "Stopping the last task without starting a task first" do
    tt 'switch "some project"'
    tt 'stop'
    output.must == %{You haven't started a task under this project yet.}
  end
  scenario "Stopping the last task when all the tasks I've started have been stopped since" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop'
    tt 'stop'
    output.must == %{It looks like all the tasks under this project are stopped.}
  end
  scenario "Stopping a task by name" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop "some task"'
    output.must =~ %r{Stopped clock for "some task", at \ds\.}
  end
  scenario "Stopping a task by name that doesn't exist" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop "another task"'
    output.must == %{It looks like that task doesn't exist.}
  end
  scenario "Stopping a task by name that's already been stopped" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop "some task"'
    tt 'stop "some task"'
    output.must == %{I think you've stopped that task already.}
  end
  scenario "Stopping a task by task number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop 1'
    output.must =~ %r{Stopped clock for "some task", at \ds\.}
  end
  scenario "Stopping a task by task number that doesn't exist" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop 2'
    output.must == %{It looks like that task doesn't exist.}
  end
  scenario "Stopping a task by task number that's already been stopped" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop 1'
    tt 'stop 1'
    output.must == %{I think you've stopped that task already.}
  end
  
  #scenario "Running 'tt resume' without specifying a task"
  #scenario "Resuming a certain task"
  #scenario "Resuming a task that I haven't started"
  #scenario "Resuming a task that I haven't stopped"
end