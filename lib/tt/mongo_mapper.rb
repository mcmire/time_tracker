require 'mongo_mapper'

log_dir = File.expand_path('../../../log', __FILE__)
FileUtils.mkdir_p(log_dir)
logger = Logger.new(log_dir + "/#{$USE_TEST_DB ? 'mongo.test.log' : 'mongo.log'}")
MongoMapper.connection = Mongo::Connection.new('127.0.0.1', 27017, :logger => logger)
MongoMapper.database = $USE_TEST_DB ? "tt_test" : "tt"

# MongoMapper extensions

module MongoMapper
  module Extensions
    module PrettyPrint
      def pretty_print(q)
        #attrs = self.class.column_names.inject([]) {|arr, name|
        #  if has_attribute?(name) || new_record?
        #    arr << [name, read_attribute(name)]
        #  end
        #  arr
        #}
        #our_attributes = self.attributes
        #attrs = self.keys.map {|key| [key.name, our_attributes[key.name]] }
        q.group(0, "#<#{self.class}", "}>") {
          q.breakable " "
          q.group(1) {
            q.seplist(self.attributes) {|pair|
              q.pp pair[0]
              q.text ": "
              q.pp pair[1]
            }
          }
        }
      end
    end
  end
end
MongoMapper::Document.class_eval { include MongoMapper::Extensions::PrettyPrint }
MongoMapper::EmbeddedDocument.class_eval { include MongoMapper::Extensions::PrettyPrint }