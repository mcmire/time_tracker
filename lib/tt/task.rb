require 'tt/mongo_mapper'

module TimeTracker
  class Task
    include MongoMapper::Document
    plugin MongoMapper::Plugins::IdentityMap
    plugin Timestamps
    
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
    scope :updated_today, lambda {
      today = Date.today
      start_of_today = Time.local(today.year, today.month, today.day, 0, 0, 0)
      where(:updated_at.gte => start_of_today)
    }
    scope :updated_this_week, lambda {
      today = Date.today
      sunday = today - today.wday
      start_of_today = Time.local(sunday.year, sunday.month, sunday.day, 0, 0, 0)
      where(:updated_at.gte => start_of_today)
    }
    
    def self.last
      sort(:created_at.desc).first
    end
    
    def running?
      !!created_at && !stopped_at
    end
    
    def stopped?
      !!created_at && !!stopped_at
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
    
    def info
      str = ""
      str << "##{number}. #{name} [#{project.name}]"
      if stopped?
        str << " (#{paused? ? 'paused' : 'stopped'} at #{running_time})"
      end
      str
    end
    
    def set_number
      last = self.class.sort(:number.desc).first
      self.number = last ? last.number + 1 : 1
    end
  end
end