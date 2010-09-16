require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Starting tasks" do
  story <<-EOT
    I want to be able to start a task
    so that I can see how long it takes to finish later.
  EOT
  
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
    stdin << "y\n"
    tt 'start "some task"'
    stdout.readpartial(1024).must == %{I can't find this task. Did you want to create it? (y/n) }
    stdin << "y\n"
    stdout.readpartial(1024).must == %{Started clock for "some task".\n}
  end
  
  scenario "Starting a task without creating it first and denying prompt" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdout.readpartial(1024).must == %{I can't find this task. Did you want to create it? (y/n) }
    stdin << "n\n"
    stdout.readpartial(1024).must =~ /^Okay, never mind then./
  end
  
  scenario "Starting a task without creating it first and trying to get around prompt" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdout.readpartial(1024).must == %{I can't find this task. Did you want to create it? (y/n) }
    stdin << "q\n"
    stderr.readpartial(1024).must == %{I'm sorry, I didn't understand you. Try that again: }
    stdin << "q\n"
    stderr.readpartial(1024).must == %{I'm not sure what you mean. Try again: }
    stdin << "n\n"
    stdout.readpartial(1024).must == %{Okay, never mind then.\n}
  end
  
  scenario "Starting a task after creating it" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt 'start "some task"'
    output.must == %{Started clock for "some task".\n}
  end
  
  scenario "Starting an already started task" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "some task"'
    output.must == %{Aren't you already working on that task?\n}
  end
  
  scenario "Starting a paused task" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'start "another task"'
    stdin << "y\n"
    tt 'start "some task"'
    output.must == %{Aren't you still working on that task?\n}
  end
  
  scenario "Starting a finished task" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'start "some task"'
    stdin << "y\n"
    tt 'finish'
    tt 'start "some task"'
    stdin << "y\n"
    output.must end_with(%{Started clock for "some task".\n})
  end
end