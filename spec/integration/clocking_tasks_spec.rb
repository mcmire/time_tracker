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
    stdout.must =~ /Started clock for "some task"/
    stderr.must == ""
  end
  scenario "Starting a task without switching to a project first" do
    tt 'start "some task"'
    stdout.must == ""
    stderr.must =~ /Try switching to a project first/
  end
  #scenario "Running 'tt start' without specifying a name"
  #scenario "Starting the same task after it's been started"
  #scenario "Stopping a task"
  #scenario "Starting a task while another one is running"
  #scenario "Stopping the last task"
  #scenario "Stopping a certain task"
  #scenario "Stopping a task that doesn't exist"
  #scenario "Running 'tt resume' without specifying a task"
  #scenario "Resuming a certain task"
  #scenario "Resuming a task that doesn't exist"
  #scenario "Resuming a task that hasn't stopped"
end