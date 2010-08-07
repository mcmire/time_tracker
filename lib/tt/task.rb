#require 'micromachine'

module TimeTracker
  class Task
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
    #before_save :transition_to_stopped, :if => :stopping?
    #before_save :copy_next_state_to_state, :if => :next_state?
    
    #scope :running, where(:stopped_at => nil)
    #scope :stopped, where(:stopped_at.ne => nil)
    #scope :paused, where(:paused => true) # should :stopped_at.ne => nil too?
    
    state_machine :initial => :running do
      event :stop do
        sets_state :stopped
        transitions_from :running
        runs_callback :after_save do |task|
          #raise "last_started_at: #{task.last_started_at.inspect}"
          #puts "adding a time period"
          #puts "Task is: #{task}"
          task.time_periods.create!(:started_at => task.last_started_at, :ended_at => Time.now)
        end
      end
      event :pause do
        sets_state :paused
        transitions_from :running
        runs_callback :after_save do |task|
          #raise "last_started_at: #{task.last_started_at.inspect}"
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
    
    #def create!(*args)
    #  puts "Calling Task#create!"
    #  super
    #end
    
    #pp :before_create_callbacks => before_create_callback_chain.map(&:method),
    #   :before_update_callbacks => before_update_callback_chain.map(&:method),
    #   :before_save_callbacks => before_save_callback_chain.map(&:method)
    
    #attr_accessor :next_state
    #def next_state?; !!@next_state; end
    
    def self.last
      sort(:created_at.desc).first
    end
    
    #def self.all_time_periods_ended_today
    #  today = Date.today
    #  start_of_today = Time.zone.local(today.year, today.month, today.day, 0, 0, 0)
    #  map = <<-EOT
    #    function() {
    #      var id = this._id;
    #      var start_of_today = new Date(#{start_of_today.to_i * 1000});
    #      this.time_periods.forEach(function(period) {
    #        if (period.ended_at > start_of_today) emit(id, {'period': period});
    #      })
    #    }
    #  EOT
    #  reduce = <<-EOT
    #    function(task_id, periods) {
    #      return {'periods': periods};
    #    }
    #  EOT
    #  results = TimeTracker::Task.collection.map_reduce(map, reduce).find().to_a
    #  pp results
    #  results.sum {|result| result["value"]["periods"].map {|p| TimeTracker::TimePeriod.new(p) } }
    #end
    
    #def running?
    #  !!created_at && !stopped_at
    #end
    
    #def stopped?
    #  #!!created_at && !!stopped_at
    #  state == "stopped"
    #end
    
    #def stop!
    #  self.next_state = "stopped"
    #  save!
    #end
    
    #def pause!
    #  self.stopped_at = Time.now
    #  self.paused = true
    #  save!
    #end
    
    #def resume!
    #  self.stopped_at = nil
    #  self.paused = false
    #  save!
    #end
    
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
    #def state_machine
    #  @state_machine ||= MicroMachine.new(state).tap do |sm|
    #    sm.transitions_for[:stop]   = { "running" => "stopped" }
    #    sm.transitions_for[:start]  = { "stopped" => "running", "paused" => "running" }
    #    sm.transitions_for[:pause]  = { "running" => "paused" }
    #    sm.transitions_for[:resume] = { "paused" => "running" }
    #    sm.on(:any) { self.next_state = sm.state }
    #  end
    #end
  
    def set_number
      last = self.class.sort(:number.desc).first
      self.number = last ? last.number + 1 : 1
    end
    
    def copy_created_at_to_last_started_at
      #if created_at
      #  puts "setting last_started_at to #{created_at}"
      #else
      #  raise "created_at is not set"
      #end
      self.last_started_at = created_at
    end
    
    #def copy_next_state_to_state
    #  self.state = @next_state
    #end
    #
    #def transition_to_stopped
    #  self.time_periods << TimePeriod.new(:started_at => last_started_at, :stopped_at => Time.now)
    #end
  end
end