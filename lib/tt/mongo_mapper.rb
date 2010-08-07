require 'mongo_mapper'

log_dir = File.expand_path('../../../log', __FILE__)
FileUtils.mkdir_p(log_dir)
logger = Logger.new(log_dir + "/#{$USE_TEST_DB ? 'mongo.test.log' : 'mongo.log'}")
MongoMapper.connection = Mongo::Connection.new('127.0.0.1', 27017, :logger => logger)
MongoMapper.database = $USE_TEST_DB ? "tt_test" : "tt"

Time.zone = "Central Time (US & Canada)"

require 'tt/extensions/mongo_mapper'