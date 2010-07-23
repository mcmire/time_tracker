module TimeTracker
  class Project
    include MongoMapper::Document
    key :name, String
    has_many :tasks, :class_name => "TimeTracker::Task"
  end
end