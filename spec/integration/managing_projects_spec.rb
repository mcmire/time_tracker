require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Managing projects" do
  story <<-EOT
    As a programmer,
    I want to be able to file tasks under projects,
    so that I can keep my life organized.
  EOT
  
  scenario "Switching to a project for the first time" do
    tt 'switch "some project"'
    output.must == %{Switched to project "some project".}
  end
  scenario "Running 'tt switch' without giving a project name" do
    tt 'switch'
    output.must == %{Right, but which project do you want to switch to?}
  end
end