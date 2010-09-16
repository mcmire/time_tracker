require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Automatic commands" do
  story <<-EOT
    I want the system to take care of executing certain commands automatically,
    since that's how I'm thinking mentally anyway.
  EOT
  
  scenario "Switching to another project while a task in this project is still running" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'switch "another project"'
    stdin << "y\n"
    output.lines.must smart_match([
      /\(Pausing clock for "some task", at \dm\.\)/,
      %{Switched to project "another project".}
    ])
  end
  
  scenario "Starting a task while another one is running" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    output.lines.must smart_match([
      /\(Pausing clock for "some task", at \dm\.\)/,
      %{Started clock for "another task".}
    ])
  end
  
  # No tests for finish 1 or stop "another task" here -- they're unit tests though
  scenario "Starting 3 tasks in a row and returning to the last task" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'start "yet another task"'
    stdin << "y\n"
    tt 'finish'
    output.lines.must smart_match([
      /Stopped clock for "yet another task", at \dm\./,
      %{(Resuming clock for "another task".)}
    ])
  end
  
  scenario "Starting a task in one project, starting another task in another project, finishping that task, switching back to the other project" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'switch "another project"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'finish'
    output.must =~ %r{Stopped clock for "another task"}
    tt 'switch "some project"'
    output.lines.must smart_match([
      %{Switched to project "some project".},
      %{(Resuming clock for "some task".)}
    ])
  end
  
  scenario "Resuming a paused task when another is already running" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.lines.must smart_match([
      /\(Pausing clock for "another task", at \dm\.\)/,
      %{Resumed clock for "some task".}
    ])
  end
  
  scenario "Resuming a finished task when another is already running" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.lines.must smart_match([
      /\(Pausing clock for "another task", at \dm\.\)/,
      %{Resumed clock for "some task".}
    ])
  end
  
  scenario "Resuming a paused task in another project by number without switching to that project first" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'switch "another project"'
    stdin << "y\n"
    tt 'resume 1'
    output.lines.must smart_match([
      %{(Switching to project "some project".)},
      %{Resumed clock for "some task".}
    ])
  end
  
  scenario "Resuming a finished task in another project by number without switching to that project first" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'switch "another project"'
    stdin << "y\n"
    tt 'resume 1'
    output.lines.must smart_match([
      %{(Switching to project "some project".)},
      %{Resumed clock for "some task".}
    ])
  end
  
  scenario "Resuming a paused task in another project by number when one in this project is already running" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'switch "another project"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'resume 1'
    output.lines.must smart_match([
      /\(Pausing clock for "another task", at \dm\.\)/,
      %{(Switching to project "some project".)},
      %{Resumed clock for "some task".}
    ])
  end
  
  # TODO: revisit
  #scenario "Resuming a finished task in another project by number when one in this project is already running" do
  #  tt 'switch "some project"'
  #  stdin << "y\n"
  #  tt 'start "some task"'
  #  stdin << "y\n"
  #  tt 'finish'
  #  tt 'switch "another project"'
  #  stdin << "y\n"
  #  tt 'start "another task"'
  #  stdin << "y\n"
  #  tt 'resume 1'
  #  output.lines.must smart_match([
  #    /\(Pausing clock for "another task", at \dm\.\)/,
  #    %{(Switching to project "some project".)},
  #    %{Resumed clock for "some task".}
  #  ])
  #end
  
end