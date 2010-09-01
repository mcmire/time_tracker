require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Configuring TimeTracker" do
  
  scenario "Enabling Pivotal Tracker integration" do
    stub_request(:head, "www.pivotaltracker.com/services/v3/activities?limit=1").
      with(:headers => {"X-TrackerToken" => "xxxx"})
    tt "configure"
    stdout.readpartial(1024).must == %{Do you want to sync projects and tasks with Pivotal Tracker? (y/n) }
    stdin << "y\n"
    stdout.readpartial(1024).must == %{What's your API key? }
    stdin << "xxxx\n"
    stdout.readpartial(1024).must start_with(%{Great, you're all set up to use tt with Pivotal Tracker now!})
  end
  
  scenario "Enabling Pivotal Tracker integration with wrong credentials" do
    stub_request(:head, "www.pivotaltracker.com/services/v3/activities?limit=1").
      with(:headers => {"X-TrackerToken" => "xxxx"}).
      to_return(:status => 401)
      
    stub_request(:head, "www.pivotaltracker.com/services/v3/activities?limit=1").
      with(:headers => {"X-TrackerToken" => "yyyy"}).
      to_return(:status => 200)
      
    tt "configure"
    stdout.readpartial(1024).must == %{Do you want to sync projects and tasks with Pivotal Tracker? (y/n) }
    stdin << "y\n"
    stdout.readpartial(1024).must == %{What's your API key? }
    stdin << "xxxx\n"
    stderr.readpartial(1024).must == %{Hmm, I'm not able to connect using that key. Try that again: }
    stdin << "yyyy\n"
  end
  
  scenario "Enabling Pivotal Tracker integration when I've already created some projects" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt "configure"
    stdout.readpartial(1024).must == %{Do you want to sync projects and tasks with Pivotal Tracker? (y/n) }
    stdin << "y\n"
    stderr.readpartial(1024).must start_with(%{Actually -- you can't do that if you've already created a project or task. Sorry.})
  end
  
  scenario "Enabling Pivotal Tracker integration when I've already created some tasks" do
    tt 'switch "some project"'
    stdin << "y\n"
    tt 'add task "some task"'
    tt "configure"
    stdout.readpartial(1024).must == %{Do you want to sync projects and tasks with Pivotal Tracker? (y/n) }
    stdin << "y\n"
    stderr.readpartial(1024).must start_with(%{Actually -- you can't do that if you've already created a project or task. Sorry.})
  end
  
end