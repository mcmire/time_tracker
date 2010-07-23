require 'mongo'
require 'thor'

MongoMapper.database = "tt"

module TimeTracker; end

Dir[File.dirname(__FILE__) + '/tt/**/*.rb'].each {|f| require f }