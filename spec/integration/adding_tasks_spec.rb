require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Adding tasks" do
  story <<-EOT
    I want to be able to add tasks
    so that I can keep track of what I'm doing every day.
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
end