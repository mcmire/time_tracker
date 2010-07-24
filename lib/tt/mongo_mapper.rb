require 'mongo_mapper'
MongoMapper.database = $USE_TEST_DB ? "tt_test" : "tt"