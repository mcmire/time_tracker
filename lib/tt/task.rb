module TimeTracker
  class Task
    include MongoMapper::Document
    key :project_id, ObjectId
    key :name, String
    belongs_to :project, :class_name => "TimeTracker::Project"
  end
end