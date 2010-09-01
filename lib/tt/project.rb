#require 'tt/mongo_mapper'

require 'tt/task'

module TimeTracker
  class Project
    include ::MongoMapper::Document
    plugin ::MongoMapper::Plugins::IdentityMap
    
    set_collection_name "projects"
    
    key :name, String
    key :external_id, Integer
    timestamps!
    
    has_many :tasks, :class_name => "TimeTracker::Task", :foreign_key => :project_id, :extend => ::TimeTracker::Task::TaskExtensions
    
    before_create :call_external_service, :if => Proc.new { TimeTracker.external_service }
    
  private
    def call_external_service
      external_task = TimeTracker.external_service.add_project(self.name)
      self.external_id = external_task.id
    end
  end
end