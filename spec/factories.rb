Factory.define :project, :class => TimeTracker::Project do |f|
  f.name "some project"
end

Factory.define :task, :class => TimeTracker::Task do |f|
  f.association :project
  f.name "some task"
end

Factory.define :time_period, :class => TimeTracker::TimePeriod do |f|
  f.started_at Time.zone.local(2010)
  f.ended_at Time.zone.local(2010)
end