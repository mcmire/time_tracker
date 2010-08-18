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

#class IO
#  # This is an alternative for #read and is most helpful in the case
#  # where we've used IO.pipe to split stdout and stdin into two sets
#  # of reader/writer streams, and we've forked a child process such that:
#  #
#  # - the reader side of stdout is open in the parent process
#  # - the writer side of stdout is open in the child process
#  # - the writer side of stdin is open in the parent process
#  # - the reader side of stdin is open in the child process.
#  #
#  # In this setup, imagine that in the parent process we want to 
#  # verify that the child process has just written something to stdout.
#  # We could use stdout.read in the parent, but the problem is that
#  # we don't know *when exactly* the child will write to stdout.
#  # If we read stdout first (which may very well happen in a fork or
#  # thread type of situation), that read is going to hang forever,
#  # since it's waiting for an EOF marker (which will never happen with
#  # a stream, as opposed to a filehandle).
#  #
#  # Now, if we make the assumption that it will take a very short
#  # amount of time for stdout to be written to, it's a lot easier to
#  # just issue a non-blocking read, sleep for a bit, and keep doing
#  # that until we have some input. So that's what we do.
#  #
#  def read_stream(bytes=1024)
#    str = ""
#    time = Time.now
#    begin
#      sleep 0.3
#      str << read_nonblock(bytes)
#    end while str.empty? && (Time.now - time) < 2
#    str
#  end
#end

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