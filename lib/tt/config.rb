
require 'loquacious'

module TimeTracker
  # Returns a help object that can be used to show the current TimeTracker
  # configuration and descriptions for the various configuration attributes.
  #
  def self.help
    Loquacious.help_for('TimeTracker', :colorize => config.colorize, :nesting_nodes => false)
  end

  # Returns the TimeTracker configuration object. If a block is given, then it will
  # be evaluated in the context of the configuration object.
  #
  def self.config(&block)
    Loquacious.configuration_for('TimeTracker', &block)
  end

  # Set the default properties for the TimeTracker configuration. A `block` must
  # be provided to this method.
  #
  def self.defaults(&block)
    Loquacious.remove :gem, :main, :timeout, :delay
    Loquacious.defaults_for('TimeTracker', &block)
  end

  # Returns the configuration path for TimeTracker.
  #
  def self.config_path(*args)
    dir = File.expand_path('../../../config', __FILE__)
    File.join(dir, *args)
  end
end

TimeTracker.defaults {
  desc <<-__
    The name of the program. Used to generate the name of the log file.
  __
  app_name 'tt'

  desc <<-__
    The current runtime environment, as read from ENV['TT_ENV'] (default:
    "development").
  __
  environment(ENV['TT_ENV'] || 'development')

  log {
    desc %<Path where log files will be written.>
    path 'log'

    desc %<The default logging level for the system.>
    level :info

    desc %<An array of logging destinations.>
    destinations %w[logfile]

    desc <<-__
      Determines where the logging destinations will buffer messages or
      flush after every log message.
    __
    auto_flushing true
  }

  mongo {
    desc %<The MongoDB database to connect to.>
    database nil
  }
}
