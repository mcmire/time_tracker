#require 'mongo_mapper'

module DatabaseCleaner
  def self.clean
    # Remove all collections
    MongoMapper.database.collections.each do |collection|
      collection.remove unless collection.name == "system.indexes"
    end
  end
end

Spec::Runner.configuration.before(:each) do
  DatabaseCleaner.clean
end