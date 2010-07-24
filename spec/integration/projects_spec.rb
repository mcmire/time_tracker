require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

feature "Projects" do
  story <<-EOT
    As a programmer,
    I want to be able to file tasks under projects,
    so that I can keep my life organized.
  EOT
  
  scenario "Switching to a project for the first time" do
    tt 'switch "some project"'
    stdout.must =~ /Switched to project "some project"/
    stderr.must == ""
  end
  scenario "Running 'tt switch' without giving a project name" do
    tt 'switch'
    stdout.must == ""
    stderr.must =~ /I'm sorry, \*which\* project did you want to switch to\?/
  end
end