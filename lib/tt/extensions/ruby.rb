class Time
  def self.human_time_duration(difference)
    # 0..59 = less than a minute
    # 60..3599 = more than a minute, less than an hour
    # 3600..86399 = more than an hour, less than a day
    # 86400..* = more than a day
    
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

# Do we need this since MongoMapper requires ActiveSupport?
class Array
  # Copied from ActiveSupport 3
  # <http://apidock.com/rails/Array/to_sentence>
  def to_sentence(options={})
    default_words_connector     = ", "
    default_two_words_connector = " and "
    default_last_word_connector = ", and "
    
    options.reverse_merge!(
      :words_connector => default_words_connector,
      :two_words_connector => default_two_words_connector,
      :last_word_connector => default_last_word_connector
    )
    
    case length
    when 0
      ""
    when 1
      self[0].to_s
    when 2
      "#{self[0]}#{options[:two_words_connector]}#{self[1]}"
    else
      "#{self[0..-2].join(options[:words_connector])}#{options[:last_word_connector]}#{self[-1]}"
    end
  end
end

class String
  def lines
    split(/(\n)/).reject {|x| x == "\n" }
  end
end

class StringIO
  # Writes to io without affecting byte position.
  def sneak(msg)
    seek(-write(msg), IO::SEEK_END)
  end
end

module Kernel
  # Returns the object's singleton class.
  def singleton_class
    class << self
      self
    end
  end unless respond_to?(:singleton_class) # exists in 1.9.2
end

Date::DATE_FORMATS[:relative_date] = lambda do |date|
  case date - Date.today
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