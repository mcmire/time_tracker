require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Automatic commands" do
  story <<-EOT
    As a power user
    I want the system to take care of executing certain commands automatically
    Since that's how I'm thinking mentally anyway
  EOT
  
  scenario "Switching to another project while a task in this project is still running" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'switch "another project"'
    output.must =~ %r{\(Pausing clock for "some task", at \ds\.\)\nSwitched to project "another project"\.}
  end
  
  scenario "Starting a task while another one is running" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'start "another task"'
    output.must =~ %r{\(Pausing clock for "some task", at \ds\.\)\nStarted clock for "another task"\.}
  end
  
  # No tests for stop 1 or stop "another task" here -- they're unit tests though
  scenario "Starting a task, starting another task, then returning to the first task" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'start "another task"'
    tt 'stop'
    output.must =~ %r{Stopped clock for "another task", at \ds\.\n\(Resuming "some task"\.\)}
  end
  
  scenario "Starting a task in one project, starting another task in another project, stopping that task, switching back to the other project" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'switch "another project"'
    tt 'start "another task"'
    tt 'stop'
    output.must =~ %r{Stopped clock for "another task"}
    tt 'switch "some project"'
    output.must == %{Switched to project "some project".\n(Resuming "some task".)}
  end
  
  # No tests for resume() or resume(1) here -- they're unit tests though
  scenario "Resuming one task when another is already running" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop'
    tt 'start "another task"'
    tt 'resume "some task"'
    output.must =~ %r{\(Pausing clock for "another task", at \ds\.\)\nResumed clock for "some task"\.}
  end
  
  scenario "Resuming a task in another project by number without switching to it first" do
    tt 'switch "some project"'
    tt 'start "some task"'
    tt 'stop'
    tt 'switch "another project"'
    tt 'resume 1'
    output.must == %{(Switching to project "some project".)\nResumed clock for "some task".}
  end
  
end