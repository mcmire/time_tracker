require 'tt/mongo_mapper'

module TimeTracker
  class Task
    include MongoMapper::Document
    key :number, Integer
    key :project_id, ObjectId
    key :name, String
    key :started_at, Time
    key :stopped_at, Time
    
    belongs_to :project, :class_name => "TimeTracker::Project"
    
    before_create :set_number
    
    def started?
      !!started_at
    end
    
    def stopped?
      # assume that started_at is set
      !!stopped_at
    end
    
    def running_time
      Time.formatted_diff(stopped_at, started_at)
    end
    
    def set_number
      last = self.class.last
      self.number = last ? last.number + 1 : 1
    end
  end
end