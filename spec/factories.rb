
FactoryGirl.define do
  factory :project, :class => 'TimeTracker::Models::Project' do |f|
    f.name "some project"
  end

  factory :task, :class => 'TimeTracker::Models::Task' do |f|
    # TODO: I do not like associations
    f.association :project
    f.name "some task"
  end

  factory :time_period, :class => 'TimeTracker::Models::TimePeriod' do |f|
    f.started_at { Time.zone.local(2010) }
    f.ended_at { Time.zone.local(2010) }
  end
end
