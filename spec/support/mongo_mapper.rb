require 'mongo_mapper'

Spec::Runner.configuration.before(:each) do
  # Remove all collections
  MongoMapper.database.collections.each do |collection|
    collection.remove unless collection.name == "system.indexes"
  end
end