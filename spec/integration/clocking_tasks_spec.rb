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
    output.must == %{Right, but what do you want to call the new task?}
  end
  scenario "Starting the same task after it's been started" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'start "some task"'
    output.must == %{You're already working on that task.}
  end
  scenario "Starting a task while another one is running" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'start "another task"'
    output.must == %{Started clock for "another task".\n(You're now working on 2 tasks.)}
  end
  #scenario "Stopping a task"
  #scenario "Stopping the last task"
  #scenario "Stopping a certain task"
  #scenario "Stopping a task that I haven't started"
  #scenario "Starting a task that I've already stopped"
  #scenario "Running 'tt resume' without specifying a task"
  #scenario "Resuming a certain task"
  #scenario "Resuming a task that I haven't started"
  #scenario "Resuming a task that I haven't stopped"
end