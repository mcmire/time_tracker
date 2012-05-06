
require 'tt/mongo_mapper'

module TimeTracker
  module Models
    # Since the world collection will only ever have one document in it,
    # just make a little class that lets us retrieve and save that document
    class World
      class << self
        def collection
          @collection ||= ::MongoMapper.database.collection("world")
        end

        def instance
          @instance || reload
        end

        def reload
          @instance = find
        end

        def find
          new(collection.find_one || {})
        end
      end

      attr_reader :doc

      def initialize(doc)
        @doc = doc
      end

      def save
        self.class.collection.save(@doc)
        @doc["_id"] = @doc.delete(:_id)
      end

      def [](key)
        @doc[key]
      end

      def []=(key, value)
        @doc[key] = value
      end

      def update_one(key, value)
        self[key] = value
        save
      end
      alias :update :update_one

      def update_many(attrs)
        attrs.each do |key, value|
          self[key] = value
        end
        save
      end

      def reload
        self.class.reload
      end
    end
  end
end
