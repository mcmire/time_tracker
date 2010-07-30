# This is in MongoMapper, but as of 0.8.2 updated_at is always overwritten.
module TimeTracker
  module Timestamps
    module ClassMethods
      def timestamps!
        key :created_at, Time
        key :updated_at, Time
        class_eval { before_save :update_timestamps }
      end
    end

    module InstanceMethods
      def update_timestamps
        now = Time.now.utc
        self[:created_at] = now if new? && !created_at?
        self[:updated_at] = now if !new? || !updated_at?
      end
    end
  end
end