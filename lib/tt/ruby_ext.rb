class Time
  def self.formatted_diff(time2, time1)
    total_seconds = (time2 - time1).to_i

    days = total_seconds / 86400
    hours = (total_seconds / 3600) - (days * 24)
    minutes = (total_seconds / 60) - (hours * 60) - (days * 1440)
    seconds = total_seconds % 60

    display = ''
    display_concat = ''
    if days > 0
      display = display + display_concat + "#{days}d"
      display_concat = ' '
    end
    if hours > 0 || days > 0
      display = display + display_concat + "#{hours}h"
      display_concat = ' '
    end
    if days == 0 && (minutes > 0 || hours > 0)
      display = display + display_concat + "#{minutes}m"
      display_concat = ' '
    end
    if hours == 0 && days == 0 && minutes < 3
      display = display + display_concat + "#{seconds}s"
    end
    display
  end
  
  def self.formatted_diff(time2, time1)
    # 0..59 = less than a minute
    # 60..3599 = more than a minute, less than an hour
    # 3600..86399 = more than an hour, less than a day
    # 86400..* = more than a day
    
    difference = time2 - time1
    seconds    =  difference % 60
    difference = (difference - seconds) / 60
    minutes    =  difference % 60
    difference = (difference - minutes) / 60
    hours      =  difference % 24
    difference = (difference - hours)   / 24
    days       =  difference % 7
    if days > 0
      if minutes > 0
        "%dd, %dh:%0dm" % [days, hours, minutes]
      elsif hours > 0
        "%dd, %dh" % [days, hours]
      else
        "%dd" % days
      end
    elsif hours > 0
      if minutes > 0
        "%dh:%0dm" % [hours, minutes]
      else
        "%dh" % hours
      end
    elsif minutes > 0
      "%dm" % minutes
    else
      "%0ds" % seconds
    end
  end
end