require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Managing tasks" do
  story <<-EOT
    As a programmer,
    I want to be able to keep track of how long it takes for me to do stuff,
    so that I can review it later and see how I spend my time,
    and so that I can be more efficient at my job.
  EOT
  
  scenario "Adding a task without specifying a name" do
    tt 'add task'
    output.must == %{Right, but what do you want to call the new task?\n}
  end
  scenario "Adding a task without switching to a project first" do
    tt 'add task "some task"'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Adding a task" do
    tt 'switch "some project"'
    tt 'add task "some task"'
    output.must == %{Task "some task" created.\n}
  end
  scenario "Adding a task that already exists, but hasn't been started yet" do
    tt 'switch "some project"'
    tt 'add task "some task"'
    tt 'add task "some task"'
    output.must == %{It looks like you've already added that task. Perhaps you'd like to upvote it instead?\n}
  end
  scenario "Adding a task that exists, but is running" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'add task "some task"'
    output.must == %{Aren't you already working on that task?\n}
  end
  scenario "Adding a task that exists, but is paused" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'add task "some task"'
    output.must == %{Aren't you still working on that task?\n}
  end
  scenario "Adding a task that exists, but is stopped" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'add task "some task"'
    output.must == %{Task "some task" created.\n}
  end
  
  scenario "Starting a task without specifying a name" do
    tt 'start'
    output.must == %{Right, but which task do you want to start?\n}
  end
  scenario "Starting a task without switching to a project first" do
    tt 'start "some task"'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Starting a task without creating it first and accepting prompt" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdout.readpartial(1024).must == %{I can't find this task. Did you want to create it? (y/n) }
    stdin << "y\n"
    stdout.readpartial(1024).must == %{Started clock for "some task".\n}
  end
  scenario "Starting a task without creating it first and denying prompt" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdout.readpartial(1024).must == %{I can't find this task. Did you want to create it? (y/n) }
    stdin << "n\n"
    stdout.readpartial(1024).must =~ /^Okay, never mind then./
  end
  scenario "Starting a task without creating it first and trying to get around prompt" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdout.readpartial(1024).must == %{I can't find this task. Did you want to create it? (y/n) }
    stdin << "q\n"
    stderr.readpartial(1024).must == %{What's that, now? }
    stdin << "q\n"
    stderr.readpartial(1024).must == %{Say that again? }
    stdin << "n\n"
    stdout.readpartial(1024).must == %{Okay, never mind then.\n}
  end
  scenario "Starting the same task after it's been created" do
    tt 'switch "some project"'
    tt 'add task "some task"'
    tt 'start "some task"'
    output.must == %{Started clock for "some task".\n}
  end
  scenario "Starting the same task after it's been started" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "some task"'
    output.must == %{Aren't you already working on that task?\n}
  end
  scenario "Starting the same task after it's been paused" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'start "some task"'
    output.must == %{Aren't you still working on that task?\n}
  end
  scenario "Starting the same task after it's been stopped" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'start "some task"'
    stdin << "y\n"
    output.must end_with(%{Started clock for "some task".\n})
  end
  
  scenario "Stopping the last task" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    output.must =~ %r{Stopped clock for "some task", at \dm\.\n}
  end
  scenario "Stopping the last task without switching to a project first" do
    tt 'stop'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Stopping the last task without starting a task first" do
    tt 'switch "some project"'
    tt 'stop'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Stopping the last task when all the tasks I've started have been stopped since" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'stop'
    output.must == %{It doesn't look like you're working on anything at the moment.\n}
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
  scenario "Stopping a task by name that doesn't exist" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop "another task"'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Stopping a task by name that's already been stopped" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop "some task"'
    tt 'stop "some task"'
    output.must == %{I think you've stopped that task already.\n}
  end
  scenario "Stopping a task by task number without switching to a project first" do
    tt 'stop 1'
    output.must == %{Try switching to a project first.\n}
  end
  scenario "Stopping a task by task number without starting a task first" do
    tt 'switch "some project"'
    tt 'stop 1'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Stopping a task by task number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop 1'
    output.must =~ %r{Stopped clock for "some task", at \dm\.\n}
  end
  scenario "Stopping a task by task number that doesn't exist" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop 2'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Stopping a task by task number that's already been stopped" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop 1'
    tt 'stop 1'
    output.must == %{I think you've stopped that task already.\n}
  end
  
  scenario "Resuming a task without specifying a name" do
    tt 'resume'
    output.must == "Yes, but which task do you want to resume? (I'll accept a number or a name.)\n"
  end
  scenario "Resuming a task without switching to a project first" do
    tt 'resume "some task"'
    output.must == "Try switching to a project first.\n"
  end
  
  scenario "Resuming a paused task by name" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.must =~ %r{Resumed clock for "some task"\.}
  end
  scenario "Resuming a paused task by name when no tasks exist at all" do
    tt 'switch "some project"'
    tt 'resume "some task"'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Resuming a paused task by name that doesn't exist" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'resume "yet another task"'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Resuming a paused task by name that may exist in other projects but not here" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'switch "another project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'switch "a different project"'
    tt 'resume "some task"'
    output.must == %{That task doesn't exist here. Perhaps you meant to switch to "some project" or "another project"?\n}
  end
  scenario "Resuming a running task by name" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.must == %{Aren't you working on that task already?\n}
  end
  
  scenario "Resuming a paused task by number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'resume 1'
    output.must =~ %r{Resumed clock for "some task".}
  end
  scenario "Resuming a paused task by number when no tasks exist" do
    tt 'switch "some project"'
    tt 'resume 1'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Resuming a running task by number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'resume 1'
    output.must == %{Aren't you working on that task already?\n}
  end
  
  scenario "Resuming a stopped task by name" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'resume "some task"'
    output.must == %{Resumed clock for "some task".\n}
  end
  scenario "Resuming a stopped task by name when no tasks exist at all" do
    tt 'switch "some project"'
    tt 'resume "some task"'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Resuming a stopped task by name that doesn't exist" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'resume "another task"'
    output.must == %{I don't think that task exists.\n}
  end
  scenario "Resuming a stopped task by name that may exist in other projects but not here" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'switch "another project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'switch "a different project"'
    tt 'resume "some task"'
    output.must == %{That task doesn't exist here. Perhaps you meant to switch to "some project" or "another project"?\n}
  end
  scenario "Resuming a running task by name" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'resume "some task"'
    output.must == %{Aren't you working on that task already?\n}
  end
  
  scenario "Resuming a stopped task by number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'resume 1'
    output.must == %{Resumed clock for "some task".\n}
  end
  scenario "Resuming a stopped task by number when no tasks exist" do
    tt 'switch "some project"'
    tt 'resume 1'
    output.must == %{It doesn't look like you've started any tasks yet.\n}
  end
  scenario "Resuming a running task by number" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'resume 1'
    output.must == %{Aren't you working on that task already?\n}
  end
  
  scenario "Resuming a task by number that doesn't exist" do
    tt 'switch "some project"'
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'resume 2'
    output.must == %{I don't think that task exists.\n}
  end
end