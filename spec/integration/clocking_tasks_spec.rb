require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Starting, stopping, and resuming tasks" do
  story <<-EOT
    As an employee
    I want to be able to keep track of how long it takes for me to do stuff
    So that I can review it later and see how I spend my time
    So that I can be more efficient at my job
  EOT
  
  scenario "Starting a task" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdout.should =~ /Started clock for "some task"/
  end
  scenario "Starting a task without switching to a project"
  scenario "Running 'tt start' without specifying a name"
  scenario "Stopping a task"
  scenario "Starting a task while another one is running"
  scenario "Stopping the last task"
  scenario "Stopping a certain task"
  scenario "Stopping a task that doesn't exist"
  scenario "Running 'tt resume' without specifying a task"
  scenario "Resuming a certain task"
  scenario "Resuming a task that doesn't exist"
  scenario "Resuming a task that hasn't stopped"
end