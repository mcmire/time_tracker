require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Upvoting tasks" do
  story <<-EOT
    I want to be able to "upvote" a task
    so that I can keep track of how many times a task has been requested,
    and so that I have a better sense of what its priority is.
  EOT
  
  # Not sure if there's any way to test this
  #scenario "Upvoting a task without switching to a project first"
  
  scenario "Upvoting a task without giving a name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'upvote'
    output.must == %{Yes, but which task do you want to upvote? (I'll accept a number or a name.)\n}
  end
  
  scenario "Upvoting a task by name" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'upvote "some task"'
    output.must == %{This task now has 2 votes.\n}
  end
  
  scenario "Upvoting a task by name, again" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'upvote "some task"'
    tt 'upvote "some task"'
    output.lines.last.must == %{This task now has 3 votes.}
  end
  
  scenario "Upvoting a task by name that doesn't exist" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'upvote "another task"'
    output.must == %{I don't think that task exists.\n}
  end
  
  scenario "Upvoting a task by name that's already started" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'upvote "some task"'
    output.must == %{There isn't any point in upvoting a task you're already working on.\n}
  end
  
  scenario "Upvoting a task by name that's stopped" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'upvote "some task"'
    output.must == %{There isn't any point in upvoting a task you've already completed.\n}
  end
  
  scenario "Upvoting a task by name that's paused" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'upvote "some task"'
    output.must == %{There isn't any point in upvoting a task you're already working on.\n}
  end
  
  scenario "Upvoting a task by number" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'upvote 1'
    output.must == %{This task now has 2 votes.\n}
  end
  
  scenario "Upvoting a task by number, again" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'upvote "some task"'
    tt 'upvote 1'
    output.lines.last.must == %{This task now has 3 votes.}
  end
  
  scenario "Upvoting a task by number that doesn't exist" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'upvote 2'
    output.must == %{I don't think that task exists.\n}
  end
  
  scenario "Upvoting a task by number that's already started" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'upvote 1'
    output.must == %{There isn't any point in upvoting a task you're already working on.\n}
  end
  
  scenario "Upvoting a task by number that's stopped" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'stop'
    tt 'upvote 1'
    output.must == %{There isn't any point in upvoting a task you've already completed.\n}
  end
  
  scenario "Upvoting a task by number that's paused" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'upvote 1'
    output.must == %{There isn't any point in upvoting a task you're already working on.\n}
  end
end