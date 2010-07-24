require 'tt/mongo_mapper'

module TimeTracker
  class Project
    include MongoMapper::Document
    key :name, String
    has_many :tasks, :class_name => "TimeTracker::Task", :foreign_key => :project_id
  end
end