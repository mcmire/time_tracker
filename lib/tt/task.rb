module TimeTracker
  class Task
    module TaskExtensions
      # Put this in state machine?
      [:running, :stopped, :paused].each do |state|
        class_eval <<-EOT, __FILE__, __LINE__
          def last_#{state}
            last(:state => "#{state}", :order => :updated_at)
          end
        EOT
      end
    end
    extend TaskExtensions
    
    include ::MongoMapper::Document
    plugin ::MongoMapper::Plugins::IdentityMap
    plugin TimeTracker::Extensions::MongoMapper::StateMachine
    
    set_collection_name "tasks"
    
    key :number, Integer
    key :project_id, ObjectId
    key :name, String
    key :state, String, :default => "running"
    timestamps!
    key :last_started_at, Time
    
    belongs_to :project, :class_name => "TimeTracker::Project"
    has_many :time_periods, :class_name => "TimeTracker::TimePeriod", :foreign_key => :task_id
    
    before_create :set_number, :unless => :number?
    before_create :copy_created_at_to_last_started_at, :unless => :last_started_at?
    
    state_machine :initial => :running do
      event :stop do
        sets_state :stopped
        transitions_from :running
        runs_callback :after_save do |task|
          task.time_periods.create!(:started_at => task.last_started_at, :ended_at => Time.now)
        end
      end
      event :pause do
        sets_state :paused
        transitions_from :running
        runs_callback :after_save do |task|
          task.time_periods.create!(:started_at => task.last_started_at, :ended_at => Time.now)
        end
      end
      event :resume do
        sets_state :running
        transitions_from :paused, :stopped
        runs_callback :before_save do |task|
          task.last_started_at = Time.now
        end
      end
    end
    
    def total_running_time
      Time.human_time_duration(time_periods.sum(&:duration))
    end
    
    def info(options={})
      info = []
      if options[:include_date]
        info << created_at.to_s(:relative_date) << ", "
      end
      info << created_at.to_s(:hms)
      info << " - "
      if options[:include_date]
        info << "" << ""
      end
      info << ""
      info << " "
      info << "#{name} [##{number}] (in #{project.name}) <=="
      info
    end
    
  private
    def set_number
      last = self.class.sort(:number.desc).first
      self.number = last ? last.number + 1 : 1
    end
    
    def copy_created_at_to_last_started_at
      self.last_started_at = created_at
    end
  end
end