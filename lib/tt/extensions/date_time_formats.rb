
require 'tt/core/time'

Date::DATE_FORMATS[:relative_date] = lambda do |date|
  case date - Time.zone.now.to_date
    when  0 then 'Today'
    when -1 then 'Yesterday'
    else         date.to_s(:mdy)
  end
end
Date::DATE_FORMATS[:mdy] = lambda do |date|
  date.strftime("#{date.month}/#{date.day}/%Y")
end

Time::DATE_FORMATS[:relative_date] = lambda do |time|
  time.to_date.to_s(:relative_date)
end
Time::DATE_FORMATS[:mdy] = lambda do |time|
  time.to_date.to_s(:mdy)
end
Time::DATE_FORMATS[:hms] = lambda do |time|
  hour = time.hour
  hour -= 12 if hour > 12
  hour = 12  if hour == 0
  ampm = time.hour >= 12 ? 'pm' : 'am'
  time.strftime("#{hour}:%M#{ampm}")
end
