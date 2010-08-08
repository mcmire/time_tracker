module TimeTracker
  class TimePeriod
    include ::MongoMapper::Document
    
    set_collection_name "time_periods"
    
    key :task_id, ObjectId
    key :started_at, Time
    key :ended_at, Time
    
    belongs_to :task, :class_name => "TimeTracker::Task"
    
    scope :ended_today, lambda {
      today = Date.today
      start_of_today = Time.zone.local(today.year, today.month, today.day, 0, 0, 0)
      where(:ended_at.gte => start_of_today)
    }
    
    scope :ended_this_week, lambda {
      today = Date.today
      sunday = today - today.wday
      start_of_sunday = Time.zone.local(sunday.year, sunday.month, sunday.day, 0, 0, 0)
      where(:ended_at.gte => start_of_sunday)
    }
    
    #def create!(*args)
    #  puts "Calling TimePeriod#create!"
    #  super
    #end
    
    def info(options={})
      info = []
      if options[:include_date] || started_at.to_date != ended_at.to_date
        info << started_at.to_s(:relative_date) << ", "
      end
      info << started_at.to_s(:hms)
      info << " - "
      if started_at.to_date != ended_at.to_date
        info << ended_at.to_s(:relative_date) << ", " 
      elsif options[:include_date]
        info << "" << ""
      end
      info << ended_at.to_s(:hms)
      info << " "
      info << task.name
      info << " "
      info << "[##{task.number}] (in #{task.project.name})"
      info
    end
    
    def duration
      (ended_at - started_at).to_i
    end
    
    def format_time(time, options={})
      fmtstr = []
      fmtstr << "$month/$day/$year" if options[:include_date]
      fmtstr << "$hour:$minutes$ampm"
      fmtstr = fmtstr.join(", ")
      fmtstr.gsub(/\$(\w+)/) do
        case $1
          when "month"   then options[:right_align] ? "% 2d" % time.month : time.month
          when "day"     then options[:right_align] ? "% 2d" % time.day : time.day
          when "year"    then time.year
          when "hour"
            hour = time.hour
            hour -= 12 if hour > 12
            hour = 12  if hour == 0
            options[:right_align] ? "%2d" % hour : hour
          when "minutes" then "%02d" % time.min
          when "ampm"    then time.hour >= 12 ? "pm" : "am"
        end
      end
    end
  end
end