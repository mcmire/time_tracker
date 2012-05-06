
require 'tt/mongo_mapper'

module DatabaseCleaner
  def self.clean
    # Remove all collections
    MongoMapper.database.collections.each do |collection|
      collection.remove unless collection.name == "system.indexes"
    end
  end
end

RSpec.configure do |c|
  c.before(:each) { DatabaseCleaner.clean }
  c.backtrace_clean_patterns << %r{gems/mongo_mapper-.+?/lib/mongo_mapper}
end
