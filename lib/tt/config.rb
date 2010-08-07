#require 'tt/mongo_mapper'

module TimeTracker
  # Since the config collection will only ever have one document in it,
  # just make a little class that lets us retrieve and save that document
  class Config
    class << self
      def collection
        @collection ||= ::MongoMapper.database.collection("time_tracker.config")
      end
    
      def find
        new(collection.find_one() || {})
      end
    end
    
    attr_reader :doc
    
    def initialize(doc)
      @doc = doc
    end
    
    def save
      id = self.class.collection.save(@doc)
      @doc["_id"] = id # just in case this doesn't happen
    end
    
    def [](key)
      @doc[key]
    end
    
    def []=(key, value)
      @doc[key] = value
    end
    
    def update(key, value)
      self[key] = value
      save
    end
  end
end