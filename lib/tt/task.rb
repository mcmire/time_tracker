require 'tt/mongo_mapper'

module TimeTracker
  class Task
    include MongoMapper::Document
    key :project_id, ObjectId
    key :name, String
    key :started_at, Time
    key :stopped_at, Time
    
    belongs_to :project, :class_name => "TimeTracker::Project"
    
    def started?
      !!started_at
    end
  end
end