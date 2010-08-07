require 'tt/mongo_mapper'

module DatabaseCleaner
  def self.clean
    # Remove all collections
    MongoMapper.database.collections.each do |collection|
      collection.remove unless collection.name == "system.indexes"
    end
  end
end

Spec::Runner.configuration.ignore_backtrace_patterns %r{gems/mongo_mapper-.+?/lib/mongo_mapper}
Spec::Runner.configuration.before(:each) do
  DatabaseCleaner.clean
end