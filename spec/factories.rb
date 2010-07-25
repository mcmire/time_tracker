Factory.define :task, :class => TimeTracker::Task do |f|
  f.name "some task"
end

Factory.define :project, :class => TimeTracker::Project do |f|
  f.name "some project"
end