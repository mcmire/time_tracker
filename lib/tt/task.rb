require 'tt/mongo_mapper'

module TimeTracker
  class Task
    include MongoMapper::Document
    
    key :number, Integer
    key :project_id, ObjectId
    key :name, String
    key :stopped_at, Time
    key :paused, Boolean
    timestamps!
    
    belongs_to :project, :class_name => "TimeTracker::Project"
    
    before_create :set_number, :unless => :number?
    
    scope :running, where(:stopped_at => nil)
    scope :stopped, where(:stopped_at.ne => nil)
    scope :paused, where(:paused => true) # should :stopped_at.ne => nil too?
    
    def self.last
      sort(:created_at.desc).first
    end
    
    def running?
      !new_record? && !stopped?
    end
    
    def stopped?
      !new_record? && !!stopped_at
    end
    
    def stop!
      self.stopped_at = Time.now
      save!
    end
    
    def pause!
      self.stopped_at = Time.now
      self.paused = true
      save!
    end
    
    def resume!
      self.stopped_at = nil
      self.paused = false
      save!
    end
    
    def running_time
      Time.formatted_diff(stopped_at, created_at)
    end
    
    def set_number
      last = self.class.last
      self.number = last ? last.number + 1 : 1
    end
  end
end