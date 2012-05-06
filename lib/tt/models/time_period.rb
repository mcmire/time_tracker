require 'enumerator'

module TimeTracker
  module Models
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
        lines = []
        if started_at.to_date == ended_at.to_date || options[:include_day]
          line = generate_info_line(started_at, ended_at, options)
          if options[:include_day]
            return line
          else
            lines << [ended_at.to_date, line]
          end
        else
          # Fill in the times in between started_at and ended_at
          # For instance, if we have something like 1/1/2010 3:33am - 1/3/2010 11:11am
          # that time period will be divided into the following:
          # * 1/1/2010  3:33am - 1/1/2010 11:59pm
          # * 1/2/2010 12:00am - 1/2/2010 11:59pm
          # * 1/3/2010 12:00am - 1/3/2010 11:11am
          times = []
          times << started_at
          time = (started_at.to_date + 1).to_time
          while time < ended_at
            times << time-1
            times << time
            time = (time.to_date + 1).to_time
          end
          times << ended_at
          times = times.select {|time| options[:where_date].call(time.to_date) } if options[:where_date]
          times_in_groups = times.enum_slice(2).to_a
          times_in_groups = times_in_groups.reverse if options[:reverse]
          times_in_groups.each_with_index do |(time1, time2), i|
            parenthesize = case i
              when 0
                options[:reverse] ? :first : :second
              when times_in_groups.size-1
                options[:reverse] ? :second : :first
              else
                :both
            end
            line = generate_info_line(time1, time2, options.merge(:parenthesize => parenthesize))
            lines << [time2.to_date, line]
          end
        end
        lines
      end
      def generate_info_line(time1, time2, options)
        line = []
        pfirst = (options[:parenthesize] == :first || options[:parenthesize] == :both)
        psecond = (options[:parenthesize] == :second || options[:parenthesize] == :both)
        if options[:include_day]
          line << time1.to_s(:relative_date) << ', '
        else
          line << (pfirst ? '(' : '')
        end
        line << time1.to_s(:hms)
        if !options[:include_day]
          line << (pfirst ? ')' : '')
        end
        line << ' - '
        if options[:include_day]
          line << time2.to_s(:relative_date) << ', '
        else
          line << (psecond ? '(' : '')
        end
        line << time2.to_s(:hms)
        if !options[:include_day]
          line << (psecond ? ')' : '')
        end
        line << " "
        line << '[' << "##{task.number}" << ']'
        line << " "
        line << [task.project.name, task.name].join(' / ')
        line
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
end
