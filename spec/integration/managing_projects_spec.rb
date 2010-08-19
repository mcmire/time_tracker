require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Managing projects" do
  story <<-EOT
    I want to be able to file tasks under projects,
    so that I can keep my life organized.
  EOT
  
  scenario "Adding a project" do
    tt 'add project "some project"'
    output.must == %{Project "some project" created.\n}
  end
  scenario "Adding a project without giving a name" do
    tt 'add project'
    output.must == %{Right, but what do you want to call the new project?\n}
  end
  scenario "Adding a project that already exists" do
    tt 'add project "some project"'
    tt 'add project "some project"'
    output.must == %{It looks like this project already exists.\n}
  end
  
  scenario "Switching to a project for the first time and accepting prompt to create it" do
    tt 'switch "some project"'
    stdout.readpartial(1024).must == %{I can't find this project. Did you want to create it? (y/n) }
    stdin << "y\n"
    stdout.readpartial(1024).must =~ %r{Switched to project "some project"\.\n?}
  end
  scenario "Switching to a project for the first time and denying prompt to create it" do
    tt 'switch "some project"'
    stdout.readpartial(1024).must == %{I can't find this project. Did you want to create it? (y/n) }
    stdin << "n\n"
    stdout.readpartial(1024).must == %{Okay, never mind then.\n}
  end
  scenario "Switching to a project without giving a name" do
    tt 'switch'
    output.must == %{Right, but which project do you want to switch to?\n}
  end
end