
require 'logging'

include Logging.globally

config = TimeTracker.config
log_config = config.log

Logging.format_as(:inspect)
layout = Logging.layouts.pattern(:pattern => '[%d] %-5l %c : %m\n')

if log_config.destinations.include?('stdout')
  Logging.appenders.stdout('stdout',
    :auto_flushing => true,
    :layout => layout
  )
end

if log_config.destinations.include?('logfile')
  Logging.appenders.rolling_file('logfile',
    :filename => File.join(log_config.path, "#{config.app_name}.#{config.environment}.log"),
    :keep => 7,
    :age => 'daily',
    :truncate => false,
    :auto_flushing => log_config.auto_flushing,
    :layout => layout
  )
end
