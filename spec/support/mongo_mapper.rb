require 'mongo_mapper'

log_dir = File.expand_path('../../../log', __FILE__)
FileUtils.mkdir_p(log_dir)
logger = Logger.new(log_dir + '/test.log')
MongoMapper.connection = Mongo::Connection.new('127.0.0.1', 27017, :logger => logger)
MongoMapper.database = "tt_test"

# Remove all collections
MongoMapper.database.collections.each do |collection|
  collection.remove unless collection.name == "system.indexes"
end