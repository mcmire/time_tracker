
FactoryGirl.define do
  factory :project, :class => 'TimeTracker::Models::Project' do |f|
    f.name "some project"
  end

  factory :task, :class => 'TimeTracker::Models::Task' do |f|
    f.name "some task"
  end

  factory :task_with_project, :parent => :task do |f|
    f.association :project
  end

  factory :time_period, :class => 'TimeTracker::Models::TimePeriod' do |f|
    f.started_at { Time.zone.local(2010) }
    f.ended_at { Time.zone.local(2010) }
  end
end
