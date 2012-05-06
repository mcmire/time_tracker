module TimeTracker
  module Models
    class Task
      module TaskExtensions
        # Put this in state machine?
        [:running, :paused].each do |state|
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

      key :external_id, Integer
      key :number, Integer
      key :project_id, ObjectId
      key :name, String
      key :state, String, :default => "unstarted"
      key :num_votes, Integer, :default => 1
      key :tags, Array
      key :created_by, String
      key :owned_by, String
      timestamps!
      key :last_started_at, Time

      belongs_to :project, :class_name => "TimeTracker::Project"
      has_many :time_periods, :class_name => "TimeTracker::TimePeriod", :foreign_key => :task_id

      before_create :set_number, :unless => :number?
      before_create :copy_created_at_to_last_started_at, :unless => :last_started_at?
      before_create :add_to_external_service, :if => Proc.new { TimeTracker.external_service }
      before_update :push_to_external_service, :if => Proc.new { TimeTracker.external_service }

      state_machine do
        initial_state :unstarted
        event :start do
          sets_state :running
          transitions do
            allows :unstarted#, :finished ?
            disallows \
              :running => "Aren't you already working on that task?",
              :paused => "Aren't you still working on that task?"
          end
          runs_callback :before_save do |task|
            task.last_started_at = Time.zone.now
          end
        end
        event :pause do
          sets_state :paused
          transitions do
            allows :running
            disallows \
              :unstarted => "You can't pause a task you haven't started yet!",
              :paused => "It looks like you've already paused this task.",
              :finished => "It looks like you've already finished this task."
          end
          runs_callback :after_save do |task|
            task.time_periods.create!(:started_at => task.last_started_at, :ended_at => Time.zone.now)
          end
        end
        event :resume do
          sets_state :running
          transitions do
            allows :paused
            disallows \
              :unstarted => "You can't resume a task you haven't started yet!",
              :running => "Aren't you working on that task already?"
          end
          runs_callback :before_save do |task|
            task.last_started_at = Time.zone.now
          end
        end
        event :finish do
          sets_state :finished
          transitions do
            allows :running, :paused
            disallows \
              :unstarted => "You can't finish a task you haven't started yet!",
              :finished => "It looks like you've already finished this task."
          end
          runs_callback :after_save do |task|
            if task.state_was == "running"
              task.time_periods.create!(:started_at => task.last_started_at, :ended_at => Time.zone.now)
            end
          end
        end
      end

      def upvote!
        update_attributes!(:num_votes => num_votes+1)
      end

      def total_running_time
        Time.human_time_duration(time_periods.sum(&:duration))
      end

      def info(options={})
        info = []
        if options[:include_day]
          info << last_started_at.to_s(:relative_date) << ", "
        else
          info << ""
        end
        info << last_started_at.to_s(:hms)
        unless options[:include_day]
          info << ""
        end
        info << " - "
        if options[:include_day]
          info << "" << "  "
        else
          info << ""
        end
        info << ""
        unless options[:include_day]
          info << ""
        end
        info << " "
        info << '[' << "##{number}" << ']'
        info << " "
        info << [project.name, "#{name} (*)"].join(" / ")

        if options[:include_day]
          info
        else
          [[last_started_at.to_date, info]]
        end
      end

      def info_for_search
        [
          "[", "##{number}", "]",
          " ",
          "#{project.name}",
          " / ",
          "#{name}#{' (*)' if running?}",
          " ",
          "(last active: ",
          "#{last_started_at.to_s(:mdy)})"
        ]
      end

    private
      def set_number
        last = self.class.sort(:number.desc).first
        self.number = last ? last.number + 1 : 1
      end

      def copy_created_at_to_last_started_at
        self.last_started_at = created_at
      end

      def add_to_external_service
        external_task = TimeTracker.external_service.add_task!(self.project, self.name)
        self.external_id = external_task.id
      end

      def push_to_external_service
        TimeTracker.external_service.push_task!(self)
      end
    end
  end
end
