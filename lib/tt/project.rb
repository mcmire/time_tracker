#require 'tt/mongo_mapper'

require 'tt/task'

module TimeTracker
  class Project
    include ::MongoMapper::Document
    plugin ::MongoMapper::Plugins::IdentityMap
    
    set_collection_name "projects"
    
    key :name, String
    timestamps!
    
    has_many :tasks, :class_name => "TimeTracker::Task", :foreign_key => :project_id, :extend => ::TimeTracker::Task::TaskExtensions
  end
end