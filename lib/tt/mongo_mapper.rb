
require 'mongo_mapper'
require 'bson'

config = TimeTracker.config
mongo_config = config.mongo

log_file = File.join(config.log.path, "mongo.#{config.environment}.log")

FileUtils.mkdir_p File.dirname(log_file)

logger = Logging.logger['Mongo']
logger.add_appenders Logging.appenders.file(log_file)

MongoMapper.connection = Mongo::Connection.new('127.0.0.1', 27017, :logger => logger)
MongoMapper.database = mongo_config.database

Time.zone = "Central Time (US & Canada)"

require 'tt/extensions/mongo_mapper'
